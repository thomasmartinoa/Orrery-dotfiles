# Hyprland — keybindings, rules, monitors, look, autostart, idle

Hyprland is configured in **Lua** (`hyprland.lua` requires `modules/*`, then
the theme's generated `current/hyprland.lua` last — borders/shadow colours
live there, never in the modules). Classic `.conf` syntax is rejected.

```
modules/env.lua          hl.env(...), PATH prepend ~/.local/bin, Qt/GTK env
modules/autostart.lua    hl.exec_cmd(...) at login: shell.sh start, polkit agent, cliphist watch
modules/binds.lua        hl.bind("SUPER + N", hl.dsp.exec_cmd("cmd")) — one line per key, comment says what
modules/monitors.lua     hl.monitor({...})
modules/decorations.lua  hl.config({ general = {...}, decoration = {...}, animations = {...}, input = {...} })
modules/windowrules.lua  hl.window_rule({ match = {...}, ... }), hl.layer_rule({ match = { namespace = "^orrery-x$" }, blur = true, ignore_alpha = 0.5 })
```

There is no `hyprctl keyword` with the Lua parser ("keyword can't work with
non-legacy parsers"): a live, temporary change is `hyprctl eval 'hl.config({
general = { gaps_in = 0 } })'` and `hyprctl reload` restores the config
(`orrery-toggle gaps|opacity` does exactly this).

After **every** change: `hyprctl reload && hyprctl configerrors` — it must
print nothing. A Lua error leaves Hyprland on the previous config, so the
change silently does not apply; `configerrors` is the only way to know.

## Keybindings

`hyprctl binds -j` shows what is bound now (exec binds show the command in
`arg` only for string commands). Before adding a key, grep `binds.lua` and
tell the user if it replaces something. Form:

```lua
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("notify-send hi"))   -- what it does
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
```

Dispatchers are `hl.dsp.*` (Lua form) — the shell also uses them through
`Hyprland.dispatch("hl.dsp.focus({ workspace = 2 })")` when `Hyprland.usingLua`.
For exotic ones check the Hyprland Lua docs at wiki.hypr.land (syntax changes
between versions — fetch, don't recall). A keybind that ships with the rice goes in the README keybind table too.

## Window / layer rules

`hl.window_rule({ match = { class = "^thunar$" }, float = true, size = { 1000, 700 } })`
— field names follow the current wiki (Window-Rules page); fetch it first.
Layer rules blur the shell's overlays by namespace; a new overlay gets one
(see windowrules.lua for the alpha values that match the old tools).

Traps: `size`/`move` take numbers or *expressions*
(`{ "monitor_w * 0.78", "monitor_h * 0.82" }`); `"60%"` is accepted without
a config error and silently does nothing. The wiki source is
github.com/hyprwm/hyprland-wiki `content/configuring/core/rules/` when the
site's page comes back truncated. kitty then resizes itself to the size it
remembers (`remember_window_size`, on by default): `orrery-float` passes
`-o remember_window_size=no`. kitty.conf sets `remember_window_size no` for
  the same reason: after a maximized kitty closed, every new one asked to start
  maximized ("new windows go fullscreen" — test with a probe `kitty --class
  probe`, kill it by pid, never `pkill -f` a pattern in your own command). Check a size rule a few seconds after the
window maps, not at once. A layer surface that resizes itself needs
`no_anim = true`, or Hyprland animates the size; even without the animation
the old buffer shows stretched for a frame, so avoid resizing on input.

## Monitors and scale

`modules/monitors.lua` (in the repo) is generic: every output at its
preferred mode, auto scale. This machine's own rules live in
`modules/monitors.local.lua` (gitignored, loaded after it); `orrery-scale`
writes there. Put a user's exact mode/scale/position in the local file, never
in monitors.lua. NVIDIA env vars in env.lua apply only when
/proc/driver/nvidia exists.

`hl.monitor({ output = "eDP-1", mode = "2560x1440@165", position = "0x0", scale = 1.6 })`
— `hyprctl monitors all` lists outputs/modes. Fractional scale is why the shell
uses `Hyprland.monitorFor(screen).scale` instead of `devicePixelRatio`.

## Look

`decorations.lua`: gaps 5/7, border 1, rounding 4, active/inactive opacity
0.9/0.7, shadow, blur, animations. Colours are NOT here (theme). 4px rounding
and a 1px border are the rice's defaults across every surface; the user
changes both with `orrery-border radius|width <px>` (Menu › Appearance ›
Corners & borders). It writes `modules/look.local.lua` (gitignored, loaded
at the end of decorations.lua, so reloads keep it) plus `look` in
shell.json for the shell, and applies with `hyprctl eval`. Don't edit the
defaults in decorations.lua for a user's taste; use the command.

A user's own settings (keyboard layout, touchpad, any `hl.config`) go in
`~/.config/hypr/hyprland.local.lua`: gitignored, loaded at the very end of
hyprland.lua, so it overrides everything and `git pull` never conflicts.
Don't edit the repo's hyprland.lua for one person's taste.

Startup: `misc` turns off Hyprland's stock wallpaper, logo and splash, and
the theme sets `misc.background_color` to its `bg0` (current/hyprland.lua).
Until the shell's wallpaper layer fades in, a second or two after login, the
screen is that colour, never the anime default. To see that moment without
logging out: `shell.sh stop`, screenshot, `shell.sh start`.

## Autostart, idle, lock

The shell starts from `autostart.lua` (`scripts/shell.sh start`), which also
runs `orrery-theme apps` so editors and browsers installed since the last
theme switch get the theme. The keybind scripts (`launcher.sh`, `clipboard.sh`,
`powermenu.sh`, `orrery-theme-menu`) go through `shell.sh call <target> <fn>`,
which starts the shell first if it isn't running. Idle
timers live in `Services/Idle.qml` (dim/lock/dpms/suspend seconds); caffeine
pauses them (`caffeine.sh toggle`, `qs ipc call caffeine toggle`). Lock is
the shell's `WlSessionLock` (PAM "hyprlock"); `hypridle.conf` only bridges
logind (`loginctl lock-session`, before-sleep) to `lock.sh`. Do not add a
second locker or idle daemon.
