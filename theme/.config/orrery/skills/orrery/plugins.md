# The shell — bar, widgets, panels, overlays, plugins

One Quickshell process (`~/.config/hypr/scripts/shell.sh start|restart`),
config at `~/.config/quickshell` = repo `quickshell/.config/quickshell`.

```
shell.qml                 mounts everything: WallpaperWindow Bar OsdWindow NotificationPopups
                          LockScreen PowerMenu ImagePicker Launcher Clipboard MenuWindow DockWindow
Commons/Theme.qml         colours from current/colors.json: Theme.c.bg0..bg4, fg, accentBright,
                          accentLight, accentMid, accentDim, border, borderStrong;
                          Theme.radius (4, or the user's orrery-border choice), radiusSm, font, fontSize, light, barStyle, alpha(col, a)
Commons/Config.qml        shell.json: Config.position/vertical/transparent, layoutFor(), moduleDef(),
                          set("a.b", v) — writes the file, everything rebinds
Services/*.qml            singletons (pragma Singleton) with IpcHandler: Notifs, Panels, Themes,
                          Wallpaper, Lock, Idle, Caffeine, Osd, Apps, Clip, Agents, Menu, Dock
Bar/Bar.qml               per-screen PanelWindow, gestures (drag to edge, double-click transparent)
Bar/Pill.qml              the module container: pill skin (bordered) / floating + minimal (flat)
Bar/WidgetLoader.qml      id → widget map (add new built-in widgets here)
Bar/<Widget>.qml          Clock Workspaces Tray Audio Network Bluetooth Battery Caffeine Bell
                          ActiveWindow Media SysMon NetSpeed KeyboardLayout Agents NightLight CommandWidget Label
Panels/Panel.qml          a drawer that slides out of the bar under its widget (Motion in/out);
                          PanelHeader (title, detail, `actions: [IconButton…]`, switch)
                          PanelSection PanelDivider PanelRow (icon chip, `strength` bars, check)
                          PanelButton IconButton Segmented Slider Toggle EmptyState
                          VolumeLine DeviceList (current + "N more")
Commons/Motion.qml        the one motion language: inMs/outMs/moveMs/fadeMs + bezier curves;
                          Hyprland's layer animations use the same (orreryIn / orreryOut)
Panels/<X>Panel.qml       Audio Network Bluetooth Power Calendar Agents Media · TrayMenu
Dock/DockWindow.qml       the dock: Services/Dock.qml holds shell.json › dock, pins and the items
                          (pinned, then running via ToplevelManager); intellihide reads window
                          geometry from Hyprland.toplevels (lastIpcObject after refreshToplevels())
Launcher/ Clipboard/ Picker/ Lock/ Power/ Notifications/ Osd/ Wallpaper/   overlays
```

## Bar layout — no code

`~/.config/orrery/shell.json` → `bar.layout.<pill|minimal>.<left|center|right>` (floating uses minimal's) are
lists of widget ids; hot-reloads. Built-ins: `clock workspaces tray audio network
bluetooth battery caffeine bell activewindow media sysmon keyboard agents spacer`.
Anything else is looked up in `bar.modules`:

```json
"modules": {
  "vpn":   { "exec": "~/bin/vpn-status", "interval": 5, "onClick": "nm-connection-editor" },
  "moon":  { "qml": "~/.config/orrery/plugins/moon.qml" }
}
```

`exec` prints text or waybar JSON `{"text":"󰌆","class":"active","tooltip":"…"}` —
old waybar scripts work unchanged. `qml` is any Item; the file is loaded from
outside the repo (user plugin dir `theme/.config/orrery/plugins/`, stowed).

## Write a widget (plugin file or built-in)

Minimal plugin, `~/.config/orrery/plugins/hello.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons        // Theme, Config, Icon
import qs.Bar            // Pill, Label
import qs.Services       // Panels, Notifs, …
import qs.Panels         // Panel, PanelHeader, PanelRow, PanelButton

Pill {
    id: w
    property string value: ""
    Process { id: p; command: ["sh", "-c", "cat /sys/class/power_supply/BAT1/power_now"]
              running: true
              stdout: StdioCollector { onStreamFinished: w.value = (parseInt(text) / 1e6).toFixed(1) + " W" } }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: p.running = true }
    onClicked: Panels.toggle("hello", w)          // a panel, or Quickshell.execDetached([...])
    Icon { icon: "bolt"; color: Theme.c.accentLight }
    Label { visible: w.pillMode && !w.vertical; text: w.value; color: Theme.c.fg }
    Panel { name: "hello"; anchorItem: w
            PanelHeader { title: "Power draw" }
            PanelRow { icon: "bolt"; title: w.value; subtitle: "battery discharge" } }
}
```

Rules of the house:
- **Icons are Material Symbols Rounded, by name**: `Icon { icon: "wifi"; color: … }`
  (Commons/Icon.qml; `size`, default 15 = the bar's text height). They are
  Google's SVGs (filled, weight 600), not a font: `Commons/icons/build.py`
  fetches every name in `Commons/icons/names.txt` into `Commons/IconPaths.js`.
  A new icon = add its name there (check it on fonts.google.com/icons),
  run build.py, restart the shell; an unknown name logs a warning and draws
  nothing. Look at a new icon at bar size (15px) before using it — detailed
  ones (memory, smart_toy) turn to mush; prefer simple silhouettes (speed,
  sd_card, auto_awesome). A few old SVGs have no viewBox (0..20 coordinates);
  build.py stores each icon's box, so never assume 0 -960 960 960. Every `icon:` field (PanelRow, PanelButton, menu.jsonc rows) takes
  a name too. Material has no brand logos: those (agents) stay Nerd Font
  glyphs, which `Icon` draws as text. Show state with colour, not outline.
  In the minimal skin widgets are 4px padded; pair an icon with its number in
  a `Row { spacing: 3 }` and let the pill's `gap` part the pairs.
- **Pill**: put `Label`s (or small Items) inside; it handles padding, every skin,
  vertical bars, hover, `clicked/rightClicked/middleClicked/scrolled`. Hide text
  in the minimal/vertical bar with `visible: pillMode && !vertical` like the
  built-ins. Never hardcode colours — `Theme.c.*`; sizes come from the skin.
- **Sizes**: every font size goes through `Theme.fs(px)`, which scales the 12px
  design baseline by the user's `orrery-text-size`. Never write a bare
  `font.pixelSize: 13` outside Lock/ (hyprlock's geometry) and the theme
  preview (a picture of a theme, not UI).
- **Glyphs** are Nerd Font (JetBrainsMono Nerd Font Propo). Private-use glyphs
  vanish in shell heredocs: write them as `"\u{f0a7a}"` escapes in QML, or edit
  with the Edit tool.
- **Panels** open via `Panels.toggle(name, anchor)`; one open at a time; they
  register for `qs ipc call panels open <name>`.
- **Services** (state, IPC, timers, processes) belong in `Services/<Name>.qml`
  (`pragma Singleton`, add `singleton Name 1.0 Name.qml` to `Services/qmldir`).
  A singleton only comes alive when something references it, and so does its
  IpcHandler: one that must answer IPC from the start gets a `void Name.x` in
  the Scope at the top of `shell.qml`. `qs ipc call` prints "Target not found."
  and still exits 0, so check its output, not its status.
  Built-in widgets go in `Bar/` + `Bar/qmldir` + a `case` in `WidgetLoader.qml`
  + the default layouts in `Commons/Config.qml` (and README's widget list if it ships).
- **Overlays** (fullscreen things like launcher/picker) are a `Variants { model:
  Quickshell.screens; PanelWindow { WlrLayershell.layer: Overlay; keyboardFocus:
  Exclusive when open; namespace: "orrery-<name>" } }`; give the namespace a
  blur `hl.layer_rule` in `modules/windowrules.lua` like the others.
  An overlay that is hidden and shown again must not rebuild its content on
  open: assign a Repeater's model only when the data really changed (a fresh
  `JSON.parse` of the same text is a new array, and every delegate is torn
  down), and don't key a `Loader` to state that resets when it closes (the
  picker kept its mode in `Themes.lastMode` for this). A rebuild shows the
  cards blank or half-drawn for a frame or two: the picker "flashed" its old
  look on every open. Images in such cards: `cache: true` (a `?v=<mtime>` on
  the URL when the file can change) and nothing drawn beneath that could
  show while they load. Test by capturing ~12 frames 30 ms apart after `qs
  ipc call …` and reading them as a strip.
- **Config**: read `Config.data.<yours>`; defaults in `Config.defaults`; write with
  `Config.set("path", value)`. Never write shell.json from a script while the
  shell also writes it, except with `jq` on the whole file (orrery-agent does).

Panel motion: a panel grows out of the bar (Motion.growMs 500 ms, Material 3
Expressive "default spatial", a slight overshoot then settle; drawn at depth
`drawD` with its corners kept) and shrinks back (M3 emphasized accelerate); a click on
another bar widget hands over (Panels.swapping: the old one goes at once,
the new one grows from 45%). Hyprland's own popup fade must stay off for
closing (`fadePopupsOut` disabled in decorations.lua), or the old panel
ghosts over the new one for ~300 ms. A panel with a `backdrop` fades it into
the bar colour at the join. Test motion by grabbing ~16 frames 15 ms apart.

Overlays share the look: the launcher, menu and clipboard mark the selected
row with a 3 px accent bar (no key-hint lines: the maintainer doesn't want
them); the power menu labels every action (keys as in wlogout, not shown).
Overlay motion: Hyprland only fades the full-screen layer (`animation =
"fade"`; its popin scaled the dimmed backdrop and blur too, a wobble), and
the card itself arrives with `Arrive { target: card; when: win.visible }`
(Commons/Arrive.qml: 96% → 100% on the Expressive curve, plus a fade). The
menu's pages slide in from the side you go. Sleep is `systemctl suspend`
(this laptop's "deep" S3, slow to wake, easily taken for hibernation);
Hibernate is its own action, shown only with a disk sleep state and swap. A QML property must not start
with `on` + a capital (`onToday`): QML reads it as a signal handler and the
value is never set.

Panels, the way they are built now: a new panel is a `Panel { name; anchorItem;
panelWidth }` of those parts, never its own card or animation. Spacing is
16 px padding, 10 px between parts, rows 40 px (48 with a subtitle). A list
that can grow shows the current item and folds the rest ("3 more devices").
Every panel has an empty state (EmptyState), a header action instead of a
footer button where one icon says it, and a Legacy (pill) bar turns the
clicked pill into the drawer's tab (Pill.qml `attached`). Check new panel
work in the floating and pill skins, dark and light.

Web apps (theme/.local/bin/orrery-webapp): launchers marked
`X-Orrery-WebApp=true` in ~/.local/share/applications, Exec `orrery-webapp
launch <url> <id>`: Firefox `--new-instance --profile
~/.local/share/orrery/webapps/<id> --name <id>` (the profile's user.js and
chrome/*.css hide tabs, toolbars, scrollbars and the link-preview
#statuspanel; rewritten on every launch), StartupWMClass = <id>, so the dock
(Services/Dock.qml matches startupClass) shows the site's icon. An open app is
focused, not started twice. Each app has its own browser, chosen when it is added
(`add --chromium`, Menu › Web apps › Add › In Chromium) and kept in its
launcher (`X-Orrery-WebApp-Browser`, and the 3rd Exec argument): Chromium
uses `--app --hide-scrollbars`, class `chrome-<host>__<path, / as _>-Default`. Chromium can't hide its link-preview bubble. Menu › Web apps uses the
`webapps` / `webapps.remove` providers in orrery-menu-data. No sound from one app (Chromium, say) while
others play: WirePlumber remembers volume and mute per application name
(~/.local/state/wireplumber/stream-properties, `Output/Audio:application.name:Chromium`),
so one mute silences every later stream of that app. `pactl list sink-inputs`
shows `Mute: yes`; unmute that stream (`pactl set-sink-input-mute <id> 0`) and the saved
state follows. The Sound panel's app rows toggle mute on their icon.
Media from a web app:
MPRIS only says "Mozilla firefox"; Services/MediaApps.qml traces each
player's `dbusName` → process (busctl) → window (hyprctl clients pid) →
launcher (startupClass) for the app's own name and icon; use
`MediaApps.name(player)` / `.icon(player)`, never `identity` directly. To
test, serve a page with a −50 dB tone on localhost as a temporary web app
(Firefox registers no player for silent audio). In bash, never
validate inside `$( )`: `die` there only leaves the subshell (an invalid URL
once wrote an empty launcher).

QML pitfalls learned here (don't relearn them):
A component whose root has a `default property alias x: inner.data` also
sends its OWN declared children into `inner` (PanelHeader did: "Row will not
function"); make such slots explicit (`actions: [ … ]`). Pipewire: a playback
stream (an app's audio) is `isStream && isSink`, and a node's properties and
volume are only filled once a PwObjectTracker holds it. Material Symbols
`network_wifi_*_bar` in the filled style all draw a full fan: draw signal
strength yourself (PanelRow `strength`).
`id` is reserved (use `widgetId`); `var` arrays come back as copies — update by
id and reassign; `Theme.c.x` are strings, use `Theme.alpha()` for translucency;
`Grid` pads implicit size for declared rows/columns; flipping `anchors` at
runtime overrides size bindings — position with x/y; `Loader` pins the first
size; `Screen.devicePixelRatio` rounds fractional scale — use
`Hyprland.monitorFor(screen).scale`; `Hyprland.activeToplevel` is null until a
focus event; "Cannot override FINAL property" after an edit is stale hot-reload
cache → `shell.sh restart`.
Pill's own MouseArea sits at `z: -1`, so a child MouseArea (tray icon, button)
wins its clicks — keep it that way or the tray goes dead. Tray menus are
drawn by `Panels/TrayMenu.qml` (a Panel over `QsMenuOpener`, submenus drill
down) — don't go back to `QsMenuAnchor.open()`: those are unthemed Qt widget
menus and need `//@ pragma UseQApplication`. `Panel` takes `pad`, `spacing`
and a `backdrop` (items clipped under the content, e.g. a blurred cover).
Inside a gradient, `GradientStop`s can't see the gradient's own properties
unqualified — give it an id.
QML `Canvas` here is unreliable for image work: `putImageData` silently
writes nothing, `loadImage` can't read `itemgrabber:` urls (draw a hidden
`Image` with that source instead) and a file-loaded icon can be stale after
the icon theme flips (Papirus ↔ Papirus-Dark follow light/dark). Use Canvas
only to *measure*; do pixel effects with a `ShaderEffect` + a compiled
shader in `Shaders/` (`/usr/lib/qt6/bin/qsb --qt6 -o x.frag.qsb x.frag`;
keep both: the `.qsb` is what loads). `Bar/Tray.qml` snapshots each icon as displayed
(`grabToImage`), and inverts colourless ones that match the bar's lightness
with `Shaders/invert.frag`; it re-measures after a light/dark switch. `WifiNetwork.signalStrength` is **0..1**, not a percentage. MPRIS
`position` only updates when you call `player.positionChanged()` (poll on a
Timer while visible); VLC registers twice on the bus — dedupe players.
To test media UI with no player running: build a silent mp3 with cover art
(`ffmpeg -f lavfi -i anullsrc -i cover.jpg -map 0 -map 1 -t 240 -c:v mjpeg
-disposition:v attached_pic …`; put `-t` *after* the inputs) and play it with
`cvlc --no-video --control dbus`; `pkill -x vlc` after.

Layer-surface and input traps, each cost an evening:
- A `PanelWindow`'s `margins` set before it first maps can stick in the
  compositor while its size updates fine — the bar came up at 6,5 on a flush
  skin. Map once settings are read (`visible: … && Config.ready && Theme.ready`)
  and check real geometry with `hyprctl layers`, not the QML values.
- Over an empty workspace Hyprland drops a drag the moment the pointer leaves
  the pressed layer surface (Qt reads the leave as a release): it keeps a held
  button's pointer focus only while *some* surface has keyboard focus
  (InputManager.cpp). Over a window the window has it. The bar therefore sets
  `keyboardFocus: OnDemand` only while its workspace has no windows. Don't
  resize a surface to catch the pointer instead: Hyprland shows the old buffer
  stretched for a frame, a flash over the whole screen. Always test drags on
  an empty workspace too.
- `GridView` fits `floor(height / cellHeight)` rows per column — size it in
  whole cells or rows spill into the next column and arrow keys land wrong.
- A `PopupWindow` hanging off a layer surface that sets a `mask` (the dock)
  gets no pointer input from Hyprland, even while the mask covers the whole
  window: draw such menus inside the window and grow it while open (the
  dock's right-click menu). The bar's panels work because the bar sets no mask.
- Two surfaces that both reserve the same edge: Hyprland hands out edges
  layer by layer from Background up, then in map order. The dock is on
  Overlay so the bar (Top) always gets the edge; it is created right after
  the bar so later overlays (launcher, menu) still draw over it.
- A ListView whose model is a JS array resets to the top whenever the array
  is replaced (every toggle re-reads the rows): the menu uses the row count
  as the model and reads `rows[index]` in the delegate.
- Read /proc and sysfs with a `FileView` + `reload()` on a Timer, not a
  Process per poll (sysmon, netspeed). `TextMetrics` is not an Item: refer
  to its owner by id, not `parent`.
- `HyprlandWorkspace.hasFullscreen` is also true for a *maximized* window;
  check `toplevel.wayland.fullscreen` when only real fullscreen should count.
- Numbers in the bar keep a fixed width (Bar/FixedLabel.qml / Reading.qml, `widest`), or every
  1 → 2 digit change pushes the widgets beside them.
- An edge preview (or any layer) that re-anchors between edges passes through
  a full-screen size for a frame; keep one fixed window per edge instead.
- Pickers select by keyboard and launch by click; don't select on hover
  (`onEntered`): opening one under a resting mouse moves the selection.

## Apply and verify

Save → hot-reload; check `qs log` for `WARN`/`ERROR` mentioning your file.
New files, qmldir edits or persistent weirdness → `shell.sh restart` (wait ~3 s).
Then screenshot the bar in **all three skins** (`qs ipc call bar toggle` cycles them) and both
themes, on an empty workspace as well as one with a window, and the panel open (`qs ipc call panels open <name>`) — verify.md.

## The menu (SUPER+SPACE)

`~/.config/orrery/menu.jsonc` defines the tree (the header documents every
field); `menu.local.jsonc` next to it overlays by id and is hot-reloaded, so a
new entry for something you built is one line:

```jsonc
{ "toggle.vpn": {"icon":"󰌆","label":"VPN","checked":"vpn","action":"~/bin/vpn toggle","keep":true} }
```

`checked`/`value`/`when` read state keys from the shell (`theme light bar.*
caffeine dnd laptop widget.<id>`) or from `orrery-menu-data` (`state()` in
`theme/.local/bin/orrery-menu-data`; add a key there for a new toggle). Dynamic
row lists are `provider`s in the same script. `qs ipc call menu run <id>`
runs an entry from a keybind; `menu open <id>` opens a section. Rendering is
`Services/Menu.qml` + `Menu/MenuWindow.qml`.

A panel registers its anchor in `Panels.registry` when it is created, and the
bar rebuilds its widgets whenever the layout changes — so the registry always
takes the newest instance, or `qs ipc call panels open <name>` opens a panel
attached to a destroyed item and nothing appears. Panels open away from the
bar's edge (`Panel.awayFromBar`), so a bottom or side bar still shows them. Long-running or interactive
actions go through `orrery-float <cmd>` (floating terminal); config edits through
`orrery-edit <file>` (validates Hyprland Lua on close).

**Agents panel** (`Panels/AgentsPanel.qml`, data from `agents/usage.py` via
`orrery-agent usage-update`). One tab per agent whose command is on PATH, so
installing or removing one adds or drops its tab within a minute. Tabs only
change the view; the star sets `agents.default` (the bar's number, right-click
launch). Two looks, `agents.style` = `detailed | minimal`, switched in the
panel, in Menu › Agents › Usage panel look, or with `orrery-agent style`.
Rules that kept it from jumping: every section has a reserved height (the
tallest of any agent), the seven day-bars always exist (their height animates),
and the bar pill is constant width. A new agent is a token reader (use `Tally`)
plus a block in `main()`; an agent with no reader still gets a tab.
