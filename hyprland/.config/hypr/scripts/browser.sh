#!/bin/bash
# SUPER+B: open the browser (each press opens a new window, as before), but
# ignore a repeat within 2 seconds so one press can never start two.
cmd="${1:?usage: browser.sh <browser-command>}"
lock="${XDG_RUNTIME_DIR:-/tmp}/orrery-browser.lock"
exec 9>"$lock"
flock -n 9 || exit 0
now=$(date +%s.%N)
last=$(cat "$lock.t" 2>/dev/null || echo 0)
if [ "$(echo "$now - $last < 2" | bc -l)" = 1 ]; then exit 0; fi
echo "$now" > "$lock.t"
setsid "$cmd" >/dev/null 2>&1 &
