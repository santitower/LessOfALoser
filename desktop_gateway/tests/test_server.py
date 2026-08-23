import unittest

from desktop_gateway.server import (
    FIXED_CAUTION,
    GatewayConfig,
    GatewayError,
    build_ollama_payload,
    is_authorized,
    validate_brief,
    validate_summary,
)


def valid_summary():
    return {
        "date": "2026-08-23T00:00:00Z",
        "sleep": {"current": 430, "baselineAverage": 450, "percentChange": -4.4},
        "steps": {"current": 8500, "baselineAverage": 8000, "percentChange": 6.25},
        "screenTime": {"current": 190, "baselineAverage": 170, "percentChange": 11.8},
        "observations": ["Steps were above the recent average."],
        "dataCoverage": 1.0,
        "baselineDayCount": 28,
    }


class GatewayValidationTests(unittest.TestCase):
    def setUp(self):
        self.config = GatewayConfig(
            host="127.0.0.1",
            port=8787,
            ollama_base_url="http://127.0.0.1:11434",
            model="test-model",
            bearer_token="secret-token",
            allowed_tailscale_users=frozenset({"person@example.com"}),
            upstream_timeout_seconds=10,
        )

    def test_accepts_only_aggregate_summary_shape(self):
        self.assertEqual(validate_summary(valid_summary()), valid_summary())
        raw = valid_summary()
        raw["rawSamples"] = [{"value": 1}]
        with self.assertRaises(GatewayError):
            validate_summary(raw)

    def test_rejects_out_of_range_metrics(self):
        summary = valid_summary()
        summary["sleep"]["current"] = 2000
        with self.assertRaises(GatewayError):
            validate_summary(summary)

    def test_accepts_omitted_optional_trend_values_from_swift_codable(self):
        summary = valid_summary()
        summary["sleep"] = {}
        validated = validate_summary(summary)
        self.assertEqual(
            validated["sleep"],
            {"current": None, "baselineAverage": None, "percentChange": None},
        )

    def test_accepts_tailscale_identity_or_bearer_token(self):
        self.assertTrue(
            is_authorized({"Tailscale-User-Login": "person@example.com"}, self.config)
        )
        self.assertTrue(is_authorized({"Authorization": "Bearer secret-token"}, self.config))
        self.assertFalse(
            is_authorized({"Tailscale-User-Login": "other@example.com"}, self.config)
        )

    def test_forces_fixed_caution(self):
        brief = validate_brief(
            {
                "headline": "A steady day",
                "actionCategory": "shortWalk",
            },
            valid_summary(),
        )
        self.assertEqual(brief["caution"], FIXED_CAUTION)
        self.assertEqual(
            brief["suggestedAction"],
            "If it feels comfortable, consider a short walk today.",
        )
        self.assertEqual(brief["observation"], valid_summary()["observations"][0])

    def test_rejects_unsafe_model_claim(self):
        with self.assertRaises(GatewayError):
            validate_brief(
                {
                    "headline": "Your medication dose needs attention",
                    "actionCategory": "sleepRoutine",
                },
                valid_summary(),
            )

    def test_rejects_action_when_metric_is_missing(self):
        summary = valid_summary()
        summary["steps"] = {
            "current": None,
            "baselineAverage": None,
            "percentChange": None,
        }
        with self.assertRaises(GatewayError):
            validate_brief(
                {
                    "headline": "A steady day",
                    "actionCategory": "shortWalk",
                },
                summary,
            )

    def test_rejects_action_that_does_not_match_verified_observation(self):
        with self.assertRaises(GatewayError):
            validate_brief(
                {
                    "headline": "A steady day",
                    "actionCategory": "sleepRoutine",
                },
                valid_summary(),
            )

    def test_ollama_payload_disables_tools_and_streaming(self):
        payload = build_ollama_payload(valid_summary(), "test-model")
        self.assertEqual(payload["model"], "test-model")
        self.assertFalse(payload["stream"])
        self.assertFalse(payload["think"])
        self.assertNotIn("tools", payload)
        self.assertEqual(payload["format"]["additionalProperties"], False)


if __name__ == "__main__":
    unittest.main()
