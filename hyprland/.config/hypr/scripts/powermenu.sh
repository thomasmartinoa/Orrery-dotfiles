#!/usr/bin/env bash
# powermenu.sh [toggle|open|close] — the shell's power menu (SUPER+M toggles,
# the laptop power key opens it); starts the shell first if it is not running.
exec "$HOME/.config/hypr/scripts/shell.sh" call powermenu "${1:-toggle}" >/dev/null 2>&1
