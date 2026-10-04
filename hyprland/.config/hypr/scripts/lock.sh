#!/usr/bin/env bash
# lock.sh — lock the session: the shell's lock screen, or hyprlock if the
# shell is not running (crashed, or stopped): an idle lock must always lock.
if command -v qs >/dev/null 2>&1 && pgrep -x qs >/dev/null 2>&1; then
    qs ipc call lock lock >/dev/null 2>&1 && exit 0
fi
pidof hyprlock >/dev/null || exec hyprlock
