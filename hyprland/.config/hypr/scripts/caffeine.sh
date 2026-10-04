#!/usr/bin/env bash
# caffeine.sh — keep the machine awake until you say otherwise.
#
# Usage: caffeine.sh [toggle|on|off|status]
#
# With the shell running, the state lives there (Services/Caffeine): its idle
# timers pause and it holds a logind sleep inhibitor. Without it (the shell
# stopped) this script holds the inhibitor itself, which hypridle honours.
# `status` prints JSON, for a bar module of your own.

WHO="caffeine"

shell_up() { command -v qs >/dev/null 2>&1 && pgrep -x qs >/dev/null 2>&1; }

inhibit_pid() { pgrep -f -- "^systemd-inhibit .*--who=$WHO( |$)" | head -n1; }
is_on() {
    if shell_up; then [[ "$(qs ipc call caffeine status 2>/dev/null)" == "on" ]]
    else [[ -n "$(inhibit_pid)" ]]; fi
}

turn_on() {
    if shell_up; then qs ipc call caffeine on >/dev/null 2>&1; return; fi
    is_on && return
    setsid -f systemd-inhibit --what=idle:sleep --who="$WHO" --why="User asked to stay awake" --mode=block sleep infinity >/dev/null 2>&1
    notify-send -a caffeine "Caffeine on" "Idle lock and suspend paused" 2>/dev/null
}
turn_off() {
    if shell_up; then qs ipc call caffeine off >/dev/null 2>&1; return; fi
    local pid; pid="$(inhibit_pid)"; [[ -n "$pid" ]] || return
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    notify-send -a caffeine "Caffeine off" "Idle lock and suspend back to normal" 2>/dev/null
}
status() {
    if is_on; then printf '{"text":"󰅶","class":"on","tooltip":"Caffeine: ON — idle lock & suspend paused\\nclick to allow idle"}\n'
    else printf '{"text":"󰾪","class":"off","tooltip":"Caffeine: off — idling normally\\nclick to stay awake"}\n'; fi
}

case "${1:-toggle}" in
    toggle) if is_on; then turn_off; else turn_on; fi ;;
    on)     turn_on ;;
    off)    turn_off ;;
    status) status ;;
    *) echo "usage: $0 [toggle|on|off|status]" >&2; exit 1 ;;
esac
