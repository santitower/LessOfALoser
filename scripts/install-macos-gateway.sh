#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname -- "$SCRIPT_DIR")
LABEL=com.santitower.lessofaloser-gateway
USER_ID=$(id -u)
USER_DIRECTORY=$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory | awk '{print $2}')
LAUNCH_AGENTS_DIRECTORY="$USER_DIRECTORY/Library/LaunchAgents"
LOG_DIRECTORY="$USER_DIRECTORY/Library/Logs/LessOfALoser"
RUNTIME_DIRECTORY="$USER_DIRECTORY/Library/Application Support/LessOfALoser/gateway"
RUN_SCRIPT="$RUNTIME_DIRECTORY/scripts/run-desktop-gateway.sh"
PLIST_PATH="$LAUNCH_AGENTS_DIRECTORY/$LABEL.plist"
TAILSCALE_BIN=${TAILSCALE_BIN:-$(command -v tailscale || true)}
PYTHON_BIN=${PYTHON_BIN:-$(command -v python3 || true)}
OLLAMA_URL=${LESSOFALOSER_OLLAMA_URL:-http://thetower-1:11434}
OLLAMA_MODEL=${LESSOFALOSER_OLLAMA_MODEL:-qwen2.5:7b-instruct}
OLLAMA_TIMEOUT=${LESSOFALOSER_OLLAMA_TIMEOUT:-180}
ALLOWED_TAILSCALE_USERS=${LESSOFALOSER_ALLOWED_TAILSCALE_USERS:-}

if [ -z "$TAILSCALE_BIN" ] || [ -z "$PYTHON_BIN" ]; then
  echo "Install and sign in to Tailscale, and install Python 3, before continuing." >&2
  exit 69
fi

mkdir -p \
  "$LAUNCH_AGENTS_DIRECTORY" \
  "$LOG_DIRECTORY" \
  "$RUNTIME_DIRECTORY/desktop_gateway" \
  "$RUNTIME_DIRECTORY/scripts"
cp "$PROJECT_DIR/desktop_gateway/__init__.py" "$RUNTIME_DIRECTORY/desktop_gateway/__init__.py"
cp "$PROJECT_DIR/desktop_gateway/server.py" "$RUNTIME_DIRECTORY/desktop_gateway/server.py"
cp "$SCRIPT_DIR/run-desktop-gateway.sh" "$RUN_SCRIPT"
chmod 700 "$RUN_SCRIPT"

if [ -f "$PLIST_PATH" ]; then
  cp "$PLIST_PATH" "$PLIST_PATH.backup"
  launchctl bootout "gui/$USER_ID" "$PLIST_PATH" 2>/dev/null || true
fi

plutil -create xml1 "$PLIST_PATH"
plutil -insert Label -string "$LABEL" "$PLIST_PATH"
plutil -insert ProgramArguments -json '[]' "$PLIST_PATH"
plutil -insert ProgramArguments.0 -string "$RUN_SCRIPT" "$PLIST_PATH"
plutil -insert WorkingDirectory -string "$RUNTIME_DIRECTORY" "$PLIST_PATH"
plutil -insert EnvironmentVariables -json '{}' "$PLIST_PATH"
plutil -insert EnvironmentVariables.PATH -string "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin" "$PLIST_PATH"
plutil -insert EnvironmentVariables.TAILSCALE_BIN -string "$TAILSCALE_BIN" "$PLIST_PATH"
plutil -insert EnvironmentVariables.PYTHON_BIN -string "$PYTHON_BIN" "$PLIST_PATH"
plutil -insert EnvironmentVariables.LESSOFALOSER_OLLAMA_URL -string "$OLLAMA_URL" "$PLIST_PATH"
plutil -insert EnvironmentVariables.LESSOFALOSER_OLLAMA_MODEL -string "$OLLAMA_MODEL" "$PLIST_PATH"
plutil -insert EnvironmentVariables.LESSOFALOSER_OLLAMA_TIMEOUT -string "$OLLAMA_TIMEOUT" "$PLIST_PATH"
if [ -n "$ALLOWED_TAILSCALE_USERS" ]; then
  plutil -insert EnvironmentVariables.LESSOFALOSER_ALLOWED_TAILSCALE_USERS \
    -string "$ALLOWED_TAILSCALE_USERS" "$PLIST_PATH"
fi
plutil -insert RunAtLoad -bool true "$PLIST_PATH"
plutil -insert KeepAlive -bool true "$PLIST_PATH"
plutil -insert ThrottleInterval -integer 30 "$PLIST_PATH"
plutil -insert ProcessType -string Background "$PLIST_PATH"
plutil -insert StandardOutPath -string "$LOG_DIRECTORY/gateway.log" "$PLIST_PATH"
plutil -insert StandardErrorPath -string "$LOG_DIRECTORY/gateway-error.log" "$PLIST_PATH"
plutil -lint "$PLIST_PATH"

launchctl bootstrap "gui/$USER_ID" "$PLIST_PATH"
launchctl enable "gui/$USER_ID/$LABEL"

ATTEMPT=0
while ! curl -s -o /dev/null --max-time 2 http://127.0.0.1:8787/v1/health; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ "$ATTEMPT" -ge 30 ]; then
    echo "The gateway did not start. Check $LOG_DIRECTORY/gateway-error.log." >&2
    exit 70
  fi
  sleep 1
done

"$TAILSCALE_BIN" serve --bg --yes 8787

TAILSCALE_JSON=$("$TAILSCALE_BIN" status --json)
SELF_DNS=$(printf '%s' "$TAILSCALE_JSON" | "$PYTHON_BIN" -c '
import json, sys
print(json.load(sys.stdin).get("Self", {}).get("DNSName", "").rstrip("."))
')

echo "Installed $LABEL."
echo "Computer Coach URL: https://$SELF_DNS"
echo "Logs: $LOG_DIRECTORY"
