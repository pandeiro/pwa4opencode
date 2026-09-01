#!/bin/bash
# stop.sh — stop and unload the launchd agent.

PLIST_NAME="io.github.pandeiro.pwa4opencode"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"

if launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl unload "$PLIST_PATH" 2>/dev/null; then
    echo "Daemon stopped."
else
    echo "Daemon not loaded (nothing to stop)." >&2
    exit 1
fi
