#!/usr/bin/env bash
# clipboard.sh — the shell's clipboard history (SUPER+V); starts the shell first if it is not running.
exec "$HOME/.config/hypr/scripts/shell.sh" call clipboard toggle >/dev/null 2>&1
