#!/usr/bin/env bash
# launcher.sh — the shell's app launcher (SUPER+D); starts the shell first if it is not running.
exec "$HOME/.config/hypr/scripts/shell.sh" call launcher toggle >/dev/null 2>&1
