#!/usr/bin/env python3
"""A narrow, privacy-preserving gateway between LessOfALoser and Ollama."""

from __future__ import annotations

import argparse
import hmac
import json
import math
import os
import sys
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Mapping


API_VERSION = 1
MAX_REQUEST_BYTES = 16 * 1024
MAX_RESPONSE_BYTES = 64 * 1024
FIXED_CAUTION = "General wellness information only; not medical advice."

SYSTEM_PROMPT = """
You select a short daily wellness brief using only the supplied aggregate JSON facts.
Never diagnose, predict disease, claim causation, recommend medication or supplements,
or advise changing treatment. Missing values are unknown, not negative. Select exactly one
actionCategory that is supported by a present metric and matches the first supplied
observation. Return no other fields.
""".strip()

HEADLINE_TEXT = {
    "sleepRoutine": "A steadier sleep routine",
    "shortWalk": "A little movement today",
    "screenBreak": "A screen-free wind-down",
    "maintainRoutine": "Keep building on your routine",
}

ACTION_TEXT = {
    "sleepRoutine": "Consider protecting a consistent bedtime tonight.",
    "shortWalk": "If it feels comfortable, consider a short walk today.",
    "screenBreak": "Consider a short screen-free wind-down before bed.",
    "maintainRoutine": "Keep following the routine that feels sustainable for you.",
}

MODEL_RESPONSE_KEYS = frozenset({"actionCategory"})

SUMMARY_KEYS = {
    "date",
    "sleep",
    "steps",
    "screenTime",
    "observations",
    "dataCoverage",
    "baselineDayCount",
}
TREND_KEYS = {"current", "baselineAverage", "percentChange"}


class GatewayError(Exception):
    """An error safe to return to the client."""

    def __init__(self, status: HTTPStatus, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


@dataclass(frozen=True)
class GatewayConfig:
    host: str
    port: int
    ollama_base_url: str
    model: str
    bearer_token: str | None
    allowed_tailscale_users: frozenset[str]
    upstream_timeout_seconds: float

    @classmethod
    def from_environment(cls, host: str, port: int) -> "GatewayConfig":
        allowed_users = frozenset(
            value.strip().lower()
            for value in os.environ.get(
                "LESSOFALOSER_ALLOWED_TAILSCALE_USERS", ""
            ).split(",")
            if value.strip()
        )
        return cls(
            host=host,
            port=port,
            ollama_base_url=os.environ.get(
                "LESSOFALOSER_OLLAMA_URL", "http://127.0.0.1:11434"
            ).rstrip("/"),
            model=os.environ.get(
                "LESSOFALOSER_OLLAMA_MODEL", "qwen2.5:7b-instruct"
            ),
            bearer_token=os.environ.get("LESSOFALOSER_GATEWAY_TOKEN") or None,
            allowed_tailscale_users=allowed_users,
            upstream_timeout_seconds=float(
                os.environ.get("LESSOFALOSER_OLLAMA_TIMEOUT", "180")
            ),
        )


def _number(value: Any, path: str, minimum: float, maximum: float) -> None:
    if value is None:
        return
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise GatewayError(
            HTTPStatus.BAD_REQUEST, "invalid_summary", f"{path} must be numeric or null"
        )
    if not math.isfinite(float(value)) or not minimum <= float(value) <= maximum:
        raise GatewayError(
            HTTPStatus.BAD_REQUEST,
            "invalid_summary",
            f"{path} is outside the accepted aggregate range",
        )


def _validate_trend(value: Any, name: str, maximum: float) -> None:
    if not isinstance(value, dict) or not set(value).issubset(TREND_KEYS):
        raise GatewayError(
            HTTPStatus.BAD_REQUEST,
            "invalid_summary",
            f"{name} may contain only current, baselineAverage, and percentChange",
        )
    _number(value.get("current"), f"{name}.current", 0, maximum)
    _number(value.get("baselineAverage"), f"{name}.baselineAverage", 0, maximum)
    _number(value.get("percentChange"), f"{name}.percentChange", -100, 5000)
    for key in TREND_KEYS:
        value.setdefault(key, None)


def _swift_rounded(value: float) -> str:
    """Match Swift's default rounding for the non-negative values rendered here."""
    return str(math.floor(value + 0.5))


def canonical_observations(summary: Mapping[str, Any]) -> list[str]:
    observations: list[str] = []
    for key, name, unit in (
        ("sleep", "Sleep", "minutes"),
        ("steps", "Steps", "steps"),
        ("screenTime", "Screen time", "minutes"),
    ):
        trend = summary[key]
        current = trend["current"]
        baseline = trend["baselineAverage"]
        change = trend["percentChange"]
        if current is None or baseline is None or change is None:
            continue
        direction = "above" if change >= 0 else "below"
        observations.append(
            f"{name} was {_swift_rounded(float(current))} {unit}, "
            f"{_swift_rounded(abs(float(change)))}% {direction} the recent average of "
            f"{_swift_rounded(float(baseline))} {unit}."
        )
    return observations or ["Not enough comparable data is available yet."]


def primary_observation_metric(summary: Mapping[str, Any]) -> str | None:
    observation = summary["observations"][0] if summary["observations"] else ""
    return next(
        (
            metric
            for keyword, metric in {
                "sleep": "sleep",
                "step": "steps",
                "screen": "screenTime",
            }.items()
            if keyword in observation.lower()
        ),
        None,
    )


def brief_schema(summary: Mapping[str, Any]) -> dict[str, Any]:
    category = {
        "sleep": "sleepRoutine",
        "steps": "shortWalk",
        "screenTime": "screenBreak",
    }.get(primary_observation_metric(summary))
    allowed_categories = [category, "maintainRoutine"] if category else ["maintainRoutine"]
    return {
        "type": "object",
        "properties": {
            "actionCategory": {"type": "string", "enum": allowed_categories},
        },
        "required": ["actionCategory"],
        "additionalProperties": False,
    }


def validate_summary(summary: Any) -> dict[str, Any]:
    if not isinstance(summary, dict) or set(summary) != SUMMARY_KEYS:
        raise GatewayError(
            HTTPStatus.BAD_REQUEST,
            "invalid_summary",
            "summary contains missing or unapproved fields",
        )

    if not isinstance(summary["date"], str):
        raise GatewayError(HTTPStatus.BAD_REQUEST, "invalid_summary", "date must be ISO-8601")
    try:
        datetime.fromisoformat(summary["date"].replace("Z", "+00:00"))
    except ValueError as error:
        raise GatewayError(
            HTTPStatus.BAD_REQUEST, "invalid_summary", "date must be ISO-8601"
        ) from error

    _validate_trend(summary["sleep"], "sleep", 1440)
    _validate_trend(summary["steps"], "steps", 500_000)
    _validate_trend(summary["screenTime"], "screenTime", 1440)

    observations = summary["observations"]
    if (
        not isinstance(observations, list)
        or any(not isinstance(item, str) for item in observations)
        or observations != canonical_observations(summary)
    ):
        raise GatewayError(
            HTTPStatus.BAD_REQUEST,
            "invalid_summary",
            "observations must match the canonical aggregate trends",
        )

    _number(summary["dataCoverage"], "dataCoverage", 0, 1)
    baseline_days = summary["baselineDayCount"]
    if isinstance(baseline_days, bool) or not isinstance(baseline_days, int):
        raise GatewayError(
            HTTPStatus.BAD_REQUEST, "invalid_summary", "baselineDayCount must be an integer"
        )
    if not 0 <= baseline_days <= 365:
        raise GatewayError(
            HTTPStatus.BAD_REQUEST,
            "invalid_summary",
            "baselineDayCount is outside the accepted range",
        )
    return summary


def validate_brief(value: Any, summary: dict[str, Any]) -> dict[str, str]:
    if not isinstance(value, dict) or set(value) != MODEL_RESPONSE_KEYS:
        raise GatewayError(
            HTTPStatus.BAD_GATEWAY,
            "invalid_model_response",
            "model returned an unexpected response shape",
        )

    category = value.get("actionCategory")
    if not isinstance(category, str) or category not in ACTION_TEXT:
        raise GatewayError(
            HTTPStatus.UNPROCESSABLE_ENTITY,
            "unsupported_action",
            "model selected an unsupported action",
        )
    required_metric = {
        "sleepRoutine": "sleep",
        "shortWalk": "steps",
        "screenBreak": "screenTime",
    }.get(category)
    if required_metric and summary[required_metric]["current"] is None:
        raise GatewayError(
            HTTPStatus.UNPROCESSABLE_ENTITY,
            "unsupported_action",
            "model selected an action unsupported by the available summary",
        )

    supplied_observation = summary["observations"][0] if summary["observations"] else ""
    observation_metric = primary_observation_metric(summary)
    if required_metric and observation_metric and required_metric != observation_metric:
        raise GatewayError(
            HTTPStatus.UNPROCESSABLE_ENTITY,
            "unsupported_action",
            "model selected an action that does not match the verified observation",
        )

    return {
        "headline": HEADLINE_TEXT[category],
        "observation": supplied_observation,
        "suggestedAction": ACTION_TEXT[category],
        "caution": FIXED_CAUTION,
    }


def is_authorized(headers: Mapping[str, str], config: GatewayConfig) -> bool:
    tailscale_user = headers.get("Tailscale-User-Login", "").strip().lower()
    if tailscale_user:
        return (
            not config.allowed_tailscale_users
            or tailscale_user in config.allowed_tailscale_users
        )

    authorization = headers.get("Authorization", "")
    prefix = "Bearer "
    if config.bearer_token and authorization.startswith(prefix):
        return hmac.compare_digest(authorization[len(prefix) :], config.bearer_token)
    return False


def build_ollama_payload(summary: dict[str, Any], model: str) -> dict[str, Any]:
    compact_summary = json.dumps(summary, separators=(",", ":"), sort_keys=True)
    return {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": "Create today's brief from this verified aggregate JSON:\n"
                + compact_summary,
            },
        ],
        "stream": False,
        "think": False,
        "format": brief_schema(summary),
        "keep_alive": "10m",
        "options": {"temperature": 0, "num_ctx": 4096},
    }


def call_ollama(summary: dict[str, Any], config: GatewayConfig) -> dict[str, str]:
    body = json.dumps(build_ollama_payload(summary, config.model)).encode("utf-8")
    request = urllib.request.Request(
        f"{config.ollama_base_url}/api/chat",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(
            request, timeout=config.upstream_timeout_seconds
        ) as response:
            raw = response.read(MAX_RESPONSE_BYTES + 1)
    except (urllib.error.URLError, TimeoutError) as error:
        raise GatewayError(
            HTTPStatus.SERVICE_UNAVAILABLE,
            "model_unavailable",
            "the private computer model is unavailable",
        ) from error

    if len(raw) > MAX_RESPONSE_BYTES:
        raise GatewayError(
            HTTPStatus.BAD_GATEWAY,
            "model_response_too_large",
            "model response exceeded the safety limit",
        )
    try:
        outer = json.loads(raw)
        content = outer["message"]["content"]
        generated = json.loads(content)
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        raise GatewayError(
            HTTPStatus.BAD_GATEWAY,
            "invalid_model_response",
            "model did not return structured JSON",
        ) from error
    return validate_brief(generated, summary)


def ollama_is_available(config: GatewayConfig) -> bool:
    try:
        with urllib.request.urlopen(
            f"{config.ollama_base_url}/api/version", timeout=3
        ) as response:
            return response.status == HTTPStatus.OK
    except (urllib.error.URLError, TimeoutError):
        return False


class CoachRequestHandler(BaseHTTPRequestHandler):
    server_version = "LessOfALoserGateway/1"
    config: GatewayConfig

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.rstrip("/")
        if path not in {"/v1/health", "/v1/ready"}:
            self._send_error(HTTPStatus.NOT_FOUND, "not_found", "endpoint not found")
            return
        if path == "/v1/ready" and not is_authorized(self.headers, self.config):
            self._send_error(
                HTTPStatus.UNAUTHORIZED,
                "unauthorized",
                "connect through the configured Tailscale Serve endpoint",
            )
            return
        available = ollama_is_available(self.config)
        self._send_json(
            HTTPStatus.OK if available else HTTPStatus.SERVICE_UNAVAILABLE,
            {
                "ok": available,
                "service": "LessOfALoser Computer Coach",
                "apiVersion": API_VERSION,
                "model": self.config.model,
                "provider": "ollama",
            },
        )

    def do_POST(self) -> None:  # noqa: N802
        request_id = str(uuid.uuid4())
        try:
            if self.path.rstrip("/") != "/v1/coach":
                raise GatewayError(HTTPStatus.NOT_FOUND, "not_found", "endpoint not found")
            if not is_authorized(self.headers, self.config):
                raise GatewayError(
                    HTTPStatus.UNAUTHORIZED,
                    "unauthorized",
                    "connect through the configured Tailscale Serve endpoint",
                )

            length_value = self.headers.get("Content-Length")
            if not length_value or not length_value.isdigit():
                raise GatewayError(
                    HTTPStatus.LENGTH_REQUIRED, "length_required", "Content-Length is required"
                )
            length = int(length_value)
            if length <= 0 or length > MAX_REQUEST_BYTES:
                raise GatewayError(
                    HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                    "request_too_large",
                    "request exceeded the aggregate-only size limit",
                )

            try:
                payload = json.loads(self.rfile.read(length))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise GatewayError(
                    HTTPStatus.BAD_REQUEST, "invalid_json", "request must be valid JSON"
                ) from error
            if not isinstance(payload, dict) or set(payload) != {"schemaVersion", "summary"}:
                raise GatewayError(
                    HTTPStatus.BAD_REQUEST,
                    "invalid_request",
                    "request contains missing or unapproved fields",
                )
            if payload["schemaVersion"] != API_VERSION:
                raise GatewayError(
                    HTTPStatus.BAD_REQUEST,
                    "unsupported_schema",
                    "request schema version is unsupported",
                )

            summary = validate_summary(payload["summary"])
            brief = call_ollama(summary, self.config)
            self._send_json(
                HTTPStatus.OK,
                {
                    "schemaVersion": API_VERSION,
                    "requestID": request_id,
                    "model": self.config.model,
                    "brief": brief,
                },
            )
        except GatewayError as error:
            self._send_error(error.status, error.code, error.message, request_id)

    def _send_error(
        self,
        status: HTTPStatus,
        code: str,
        message: str,
        request_id: str | None = None,
    ) -> None:
        self._send_json(
            status,
            {"ok": False, "code": code, "message": message, "requestID": request_id},
        )

    def _send_json(self, status: HTTPStatus, value: dict[str, Any]) -> None:
        body = json.dumps(value, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format_string: str, *args: Any) -> None:
        timestamp = datetime.now(timezone.utc).isoformat()
        sys.stderr.write(f"{timestamp} {self.client_address[0]} {format_string % args}\n")


def make_server(config: GatewayConfig) -> ThreadingHTTPServer:
    handler = type("ConfiguredCoachRequestHandler", (CoachRequestHandler,), {"config": config})
    server = ThreadingHTTPServer((config.host, config.port), handler)
    server.daemon_threads = True
    return server


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    config = GatewayConfig.from_environment(args.host, args.port)

    if config.host not in {"127.0.0.1", "::1", "localhost"}:
        parser.error("the gateway must bind to localhost; use Tailscale Serve for access")
    if not config.bearer_token and not config.allowed_tailscale_users:
        print(
            "warning: no bearer token or allowed Tailscale users configured; "
            "only requests carrying a Tailscale identity header will be accepted",
            file=sys.stderr,
        )

    server = make_server(config)
    print(
        f"LessOfALoser gateway listening on http://{config.host}:{config.port}; "
        f"Ollama={config.ollama_base_url}; model={config.model}",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
