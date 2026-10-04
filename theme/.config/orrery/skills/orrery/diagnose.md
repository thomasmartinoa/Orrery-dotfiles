# Diagnose — "something is wrong with my PC / the rice"

Work from evidence. Establish facts, then rule out the boring causes, then
correlate on the timeline. Do not narrate a plausible story you have not
checked. Say what you found, what you ruled out, and what you could not tell.

## 1. Collect

```bash
orrery-doctor --print         # everything below in one bundle, no sudo, no prompts
```
When the user wants to post it in a GitHub issue, give them
`orrery-doctor --share` instead: the same report with their user, host, home
path, network names and IP/MAC addresses replaced.
It reports: versions (hyprland, quickshell, kernel, driver), GPU + which one
renders, monitors/scale, `hyprctl configerrors`, shell log warnings/errors,
failed systemd units (system + user), journal errors since boot, recent
crashes (`coredumpctl list`), CPU/mem/disk/thermal/battery health, power
profile, network state, pacman log (last upgrades), stow/link health
(`~/.config/hypr` etc. pointing into the repo), theme state, and the
processes that should be running (qs, polkit agent, cliphist watch).

Ask the user for the symptom in one line if it is vague: what, since when,
what changed (update? new package? new cable?).

## 2. Rule out the boring causes first

- Resource exhaustion: `free -h`, `df -h ~ /`, OOM kills in the journal
  (`journalctl -k -b | grep -i oom`). A process killed by the OOM killer is
  not a bug in that process.
- Thermal throttling: `sensors`, `cat /sys/class/thermal/thermal_zone*/temp`,
  power profile (`powerprofilesctl get`), caffeine/inhibitors (`systemd-inhibit --list`).
- The obvious: cable, muted sink (`wpctl status`), wifi radio off (`nmcli radio`),
  monitor scale after a mode change, a stale shell (`qs log` errors → `shell.sh restart`).

## 3. Correlate against the timeline

- **When did it start?** `journalctl -b -p warning --since "<time>"`, the pacman log
  (`/var/log/pacman.log`) for an upgrade right before, file mtimes in `~/.config`
  landing on the same minute (a config change is the usual suspect on a rice).
- **Is it a pattern?** `coredumpctl list` — one crash vs the same program dying repeatedly
  vs several programs dying together point in different directions.
- **Is it us?** Undo the rice's part to bisect: `hyprctl reload` with a module
  commented, `shell.sh restart`, switch theme (`orrery-theme set eclipse`), run the app
  from a terminal to see its stderr, `git log --since=… --stat` for what changed here.

## 4. Crashes (adapted from Omarchy's diagnose-crash)

`coredumpctl info <pid|name>`: beyond the backtrace, note the **command line**
the process started with — it often names what it was working on. Check other
threads' stacks for what was in flight (thumbnailers, GPU queues, plugins).
Third-party code in the address space (extensions, out-of-tree drivers) is a
common cause — flag it, but do not blame it without evidence. Symbolize with
debuginfod (Arch runs one): `DEBUGINFOD_URLS=https://debuginfod.archlinux.org
coredumpctl debug <pid> --debugger-arguments="-batch -ex 'thread apply all bt'"`.
If it is a Hyprland or Quickshell bug, gather version + steps + log and offer
to file it upstream; do not "fix" it by disabling half the rice.

## 5. Common rice-specific causes (check these before anything exotic)

| Symptom | Look at |
|---|---|
| bar/launcher/lock missing, widgets blank | `qs log`; `pgrep -x qs`; `shell.sh restart`; a QML error in the last edited file |
| theme half applied (GTK app dark in light) | GTK3/Qt read theme at start → restart the app; `orrery-theme reload`; root apps need root-sync (`sudo orrery-root-sync`) |
| icons are boxes | font: `fc-list | grep -i "JetBrainsMono Nerd Font Propo"` |
| keybind does nothing | `hyprctl configerrors`; `hyprctl binds -j | grep`; the script has `+x` and is on PATH (`~/.local/bin` is added in env.lua) |
| lock screen wrong size / tiny box | monitor scale: fractional scale rounding — see plugins.md pitfalls |
| screen shows for ~2 s after waking, then goes black; keys don't help, lid close/open does | a DPMS command that toggles instead of setting: with the Lua config, `hl.dsp.dpms("on")` ignores the string and toggles, and old-style `dispatch dpms on` is a Lua syntax error. `git grep -n dpms` in the repo, then use `hyprctl dispatch 'hl.dsp.dpms({action = "on"})'` / `{action = "off"}` everywhere (hypridle.conf, hypridle-classic.conf, Services/Idle.qml). Check: dispatch `{action = "on"}` twice and `hyprctl monitors -j | jq '.[0].dpmsStatus'` stays `true` |
| no sleep / lock | caffeine on (`qs ipc call caffeine status`), `systemd-inhibit --list`, hypridle running twice |
| `~/.local` or `~/.config/x` is a symlink into the repo (stow folded) | install.sh pre-flight; `stow -D` the package, recreate the dir, `stow -R` |
| Thunar "Open Terminal Here": *Failed to launch preferred application for category "TerminalEmulator"* | Xfce 4.20's `exo-open --launch TerminalEmulator` needs `xfce4-mime-helper` (xfce4-settings, not installed). `~/.config/Thunar/uca.xml` should run `~/.local/bin/orrery-terminal %f` (install.sh swaps it in); reopen Thunar after editing it (`thunar -q`) |
| wired earphones play but the mic is the laptop's (headset mic "not available" in `wpctl status`/pavucontrol) | `orrery-fix-mic status`. Jack `off` with the plug in = the codec stopped sensing the mic, typically after suspend on Realtek-behind-SOF laptops; restarting PipeWire does **not** help, re-probing the card does: `orrery-fix-mic` (sudo). Recurs after sleep → `orrery-fix-mic enable`, and add the model's `sys_vendor product_name` to `KNOWN` in the script so install.sh enables it for others. Also check `wpctl status` → *Default Configured Devices*: a pinned built-in mic beats the headset even when detected; `wpctl clear-default` lets priority pick. Record a few seconds from each source (`parecord -d <node>`) and compare levels to prove which one hears |
| OBS / browser screen share black or its *Open Selector* dialog empty, often after a wake or an audio fix | Something restarted PipeWire (`journalctl --user -b | grep -i 'Stopping PipeWire'`): PipeWire carries screen capture too, so a restart kills every running screencast and wedges `xdg-desktop-portal-hyprland` (`Failed to close session implementation: Timeout`). Recover with `systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal`, then restart the app. **Never restart PipeWire as a fix** in a script or hook; after a card re-probe WirePlumber re-adds the card by itself |
| After install or a theme switch: no wallpaper (bar fine), stock Firefox/VS Code/Chromium, login screen on its default picture | `orrery-theme set <id>; echo $?`: non-zero means it stopped part-way; `bash -x ~/.local/bin/orrery-theme set <id> 2>&1 \| tail` shows the step. The wallpaper, app and login-screen steps run last. `qs log \| grep wallpaper` says "cannot load" when `current/background` is missing (`orrery-wall ensure` makes it) |
| Chromium (or a Chromium web app) goes see-through or glitches while video plays; Firefox is fine | Hybrid laptop: the screen is on the Intel/AMD GPU but `LIBVA_DRIVER_NAME=nvidia` sends video decoding to NVIDIA. modules/env.lua only sets it when NVIDIA drives a connected display; after changing it, log out and in (running apps keep the old value). Test: `env -u LIBVA_DRIVER_NAME chromium` plays fine |
| an app quits at start with a vague *Failed to create …* / *Permission denied* and nothing else (e.g. DaVinci Resolve from the AUR: *Failed to create application support directories*) | Don't guess which directory: `strace -f -e trace=%file -o /tmp/app.trace <app>` (install `strace` if missing), then `grep -e EACCES -e EPERM -e EROFS /tmp/app.trace`. The failing `mkdir`/`open` names the exact path. Resolve under `/opt/resolve` is root-owned because pacman skips Blackmagic's `scripts/post_install.sh`, which creates the folders Resolve writes to. Create the path the trace shows (Resolve 21: `/opt/resolve/Immersive/Canon/STMap`) and `chown` it to the user; read `post_install.sh` for the rest (`/var/BlackmagicDesign/DaVinci Resolve` 0777, `Apple Immersive` a+w). The user runs the sudo steps. Ignore the `ActCCMessage`/`log4cxx` lines Resolve always prints |
| high battery drain | `powerprofilesctl`, `powertop --html` (asks sudo — user runs it), GPU on (`cat /sys/class/drm/card*/device/power_state`), a runaway process in `orrery-doctor` top list |

## 6. Report

Findings first (facts with the command that proves each), then the cause if
established, the fix applied (and how to undo it), and what remains unknown.
Never "fix" by deleting user data or resetting configs without asking.
