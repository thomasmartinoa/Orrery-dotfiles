#!/usr/bin/env bash
# powermenu.sh — the shell's power menu (SUPER+M); starts the shell first if it is not running.
exec "$HOME/.config/hypr/scripts/shell.sh" call powermenu toggle >/dev/null 2>&1
