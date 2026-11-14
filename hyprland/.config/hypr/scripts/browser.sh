#!/bin/bash
# SUPER+B: open the browser (each press opens a new window, as before), but
# ignore a repeat within 2 seconds so one press can never start two.
cmd="${1:?usage: browser.sh <browser-command>}"
lock="${XDG_RUNTIME_DIR:-/tmp}/orrery-browser.lock"
exec 9>"$lock"
flock -n 9 || exit 0
now=$(date +%s%3N)
last=$(cat "$lock.t" 2>/dev/null || echo 0)
[[ $last =~ ^[0-9]+$ ]] || last=0
if (( now - last < 2000 )); then exit 0; fi
echo "$now" > "$lock.t"
# "Starting <browser>…" in the shell's OSD box until its window opens (orrery-launch)
qs ipc call launching command "$cmd" >/dev/null 2>&1 9>&- &
# 9>&- : the browser must not inherit the lock fd, or it holds the lock for
# as long as it runs and every later press is ignored.
setsid "$cmd" >/dev/null 2>&1 9>&- &
