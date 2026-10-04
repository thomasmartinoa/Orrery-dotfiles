#!/usr/bin/env bash
# shell.sh — start, restart or talk to the desktop shell (Quickshell: bar,
# dock, launcher, notifications, wallpaper, lock screen).
#
#   shell.sh start                 at session start (autostart.lua)
#   shell.sh restart               SUPER+CTRL+R and Menu > Settings > Restart shell:
#                                  the way back when the shell hangs or its bar is gone
#   shell.sh call <target> <fn>…   qs ipc call, starting the shell first if it
#                                  isn't running (the keybind scripts use this)
set -u

# Quickshell runs as "qs" or, started by its full name, "quickshell": stop
# both, and wait until they are gone, or the new one starts beside the old
# and every screen gets two bars.
shell_pids() { pgrep -x qs; pgrep -x quickshell; }
stop() {
    pkill -x hypridle 2>/dev/null
    pkill -x qs 2>/dev/null
    pkill -x quickshell 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -z "$(shell_pids)" ]] && break; sleep 0.2; done
    [[ -n "$(shell_pids)" ]] && { pkill -9 -x qs; pkill -9 -x quickshell; } 2>/dev/null
    pkill -f '^/usr/bin/wl-paste --watch echo' 2>/dev/null   # the shell's clipboard watcher (Services/Clip)
}

start() {
    pkill -x hypridle 2>/dev/null
    setsid -f hypridle >/dev/null 2>&1    # logind bridge only (hypridle.conf)
    [[ -z "$(shell_pids)" ]] && setsid -f qs >/dev/null 2>&1   # never a second one
}

call() {
    if [[ -z "$(shell_pids)" ]]; then
        start
        # wait (up to ~5 s) until it answers IPC
        for _ in $(seq 25); do qs ipc show >/dev/null 2>&1 && break; sleep 0.2; done
    fi
    qs ipc call "$@"
}

case "${1:-start}" in
    start)   start ;;
    restart) stop; start ;;
    stop)    stop ;;
    call)    shift; call "$@" ;;
    *) echo "usage: $0 start|restart|stop|call <target> <function> [args]" >&2; exit 1 ;;
esac
