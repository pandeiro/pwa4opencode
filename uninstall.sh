#!/bin/bash
# uninstall.sh — remove the launchd agent, generated files, and (optionally)
# the Tailscale Serve configuration.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/pwa4opencode.env"
PLIST_NAME="io.github.pandeiro.pwa4opencode"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

TAILSCALE_BIN=""
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ENV_FILE"
fi
if [ -z "${TAILSCALE_BIN:-}" ]; then
    TAILSCALE_BIN="$(command -v tailscale 2>/dev/null || true)"
fi

"$SCRIPT_DIR/stop.sh" || true

rm -f "$PLIST_PATH"
rm -f "$ENV_FILE"
echo "Removed launchd agent and generated env file."

if [ -n "$TAILSCALE_BIN" ]; then
    printf "Reset Tailscale Serve? This removes ALL serve rules on this machine. [y/N] "
    read -r ANSWER
    case "$ANSWER" in
        y|Y)
            "$TAILSCALE_BIN" serve reset && echo "Tailscale Serve reset."
            ;;
        *)
            echo "Leaving Tailscale Serve as-is. To reset later, run: $TAILSCALE_BIN serve reset"
            ;;
    esac
else
    echo "tailscale not found; if you configured Serve, reset it manually: tailscale serve reset"
fi
