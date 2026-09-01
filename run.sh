#!/bin/bash
# run.sh — start opencode's headless web server.
# Invoked by launchd (installed via setup.sh); can also be run in a terminal.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/pwa4opencode.env"

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ENV_FILE"
fi

OPENCODE_PORT="${OPENCODE_PORT:-4096}"

if [ -z "${OPENCODE_BIN:-}" ]; then
    echo "error: OPENCODE_BIN is not set. Run ./setup.sh first." >&2
    exit 1
fi

if ! [ -x "$OPENCODE_BIN" ]; then
    echo "error: OPENCODE_BIN ($OPENCODE_BIN) is not executable. Rerun ./setup.sh." >&2
    exit 1
fi

if lsof -nP -iTCP:"$OPENCODE_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "error: port $OPENCODE_PORT is already in use (possibly another opencode instance)." >&2
    echo "       Inspect with: lsof -nP -iTCP:$OPENCODE_PORT -sTCP:LISTEN" >&2
    exit 1
fi

"$OPENCODE_BIN" serve --port "$OPENCODE_PORT" --hostname 127.0.0.1 &
OPENCODE_PID=$!

trap 'kill "$OPENCODE_PID" 2>/dev/null; exit 0' INT TERM

wait "$OPENCODE_PID"
STATUS=$?

echo "error: opencode exited unexpectedly (status $STATUS); supervisor will restart." >&2
exit 1
