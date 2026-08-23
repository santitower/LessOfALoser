#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
TAILSCALE_BIN=${TAILSCALE_BIN:-$(command -v tailscale || true)}
PYTHON_BIN=${PYTHON_BIN:-$(command -v python3 || true)}

if [ -z "$TAILSCALE_BIN" ] || [ -z "$PYTHON_BIN" ]; then
  echo "This gateway requires the tailscale and python3 commands." >&2
  exit 69
fi

TAILSCALE_JSON=$("$TAILSCALE_BIN" status --json)
SELF_DNS=$(printf '%s' "$TAILSCALE_JSON" | "$PYTHON_BIN" -c '
import json, sys
print(json.load(sys.stdin).get("Self", {}).get("DNSName", "").rstrip("."))
')

if [ -z "$SELF_DNS" ]; then
  echo "Tailscale is not connected on this computer." >&2
  exit 69
fi

export LESSOFALOSER_OLLAMA_URL=${LESSOFALOSER_OLLAMA_URL:-http://thetower-1:11434}
export LESSOFALOSER_OLLAMA_MODEL=${LESSOFALOSER_OLLAMA_MODEL:-qwen2.5:7b-instruct}

CONNECT_URL=$("$PYTHON_BIN" - "$SELF_DNS" <<'PY'
import sys, urllib.parse
server = "https://" + sys.argv[1]
print("lessofaloser://connect?server=" + urllib.parse.quote(server, safe=""))
PY
)

echo "Computer coach: https://${SELF_DNS}"
echo "One-tap app link: ${CONNECT_URL}"
echo "If needed, expose it with: tailscale serve --bg 8787"

cd "$PROJECT_DIR"
exec "$PYTHON_BIN" -m desktop_gateway.server --host 127.0.0.1 --port 8787
