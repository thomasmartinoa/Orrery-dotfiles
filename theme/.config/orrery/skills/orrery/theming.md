# Theming — themes, colours, wallpapers, apps that must follow

## How it works

`orrery-theme set <id>` reads `themes/<id>/colors.toml`, renders every
`templates/*.tpl` into `~/.config/orrery/current/`, installs the files apps
cannot import from there (GTK settings.ini, kdeglobals, qt5ct/qt6ct, btop
theme, VS Code extension), pokes running apps (hyprctl reload, kitty SIGUSR1,
nvim remote, btop SIGUSR2, `qs ipc call theme reload`), ensures a wallpaper
from the theme's `backgrounds/`, and syncs `/root` + SDDM through the sudoers
helper. The shell reads `current/colors.json` live (`Commons/Theme.qml`).

```
themes/<id>/
├── colors.toml     name, mode (dark|light), bar (pill|floating|minimal), [colors] [terminal] [git] [apps]
└── backgrounds/    1-*.png|jpg … first one is the default wallpaper
templates/<app>.tpl → current/<app>
```

Template tags (`render.py` header has the full list):
`{{ bg0 }}`, `{{ bg0 | rgba 0.6 }}`, `{{ bg0 | hypr }}`, `{{ bg0 | argb 0.1 }}`,
`{{ mix bg0 fg 20% }}`, `{{ dark "1" "0" }}`, `{{ mode }}`, `{{ name }}`, `{{ home }}`,
plus any key from `[terminal]`, `[git]`, `[apps]`.

## Make a new theme

**Ask about the layout before you start** (one short message, all three at
once, with what is on screen now as the default answer; skip any the user
already answered):

1. **Bar** — keep the bar as it is now (say which style that is:
   `qs ipc call bar style` / Menu › Appearance › Bar › Style) or give this theme
   another: Minimal (flat strip), Floating (inset, rounded) or Legacy (pills)?
2. **Dock** — shown or hidden for this theme, and where (bottom, left, right, top)?
3. **Corners** — rounded (how much: 4 px is the rice's default, 8–12 px soft) or square?

The answers go into the theme's `colors.toml` (`bar`, `dock`, `radius`, step 2).
They are the theme's *suggestions*: a choice the user made in the menu
(`shell.json` `bar.skin`, `dock.enabled`/`dock.position`, `look.radius` from
`orrery-border`) still wins. If they want this theme to look a certain way
whatever they picked before, clear those keys (`orrery-border reset`;
Menu › Appearance › Bar/Dock, or `jq` on `shell.json`) and say so.

A theme from a wallpaper ("extract the palette from this image and make a
theme"): sample it first, don't eyeball. Cluster the pixels (k-means over a
192x108 downscale, 8 clusters) and average named regions (the subject, its
lit edge, the sky, any glow). Surfaces come from the darkest large cluster,
tinted slightly toward the image's dominant hue so the bar and cards sit in
the picture; the accent is the brightest distinctive colour (the "light" of
the image); a warm/cool second colour and the hue keys come from the other
regions, brightened until they pass the contrast targets below. Write the
reasoning in the colors.toml header comment.

1. `cp -r themes/eclipse themes/<id>` (or `zenith` for a light one).
   `<id>` is lowercase-with-dashes; `name` in colors.toml is the display name.
2. Edit `colors.toml`:
   - `mode` drives GTK (`adw-gtk3` / `adw-gtk3-dark`), Qt (Qt's built-in `Fusion` style drawn in the theme's colours; `qt_style` in `[apps]`),
     icons (Papirus-Light / Papirus-Dark), nvim `background`, the shell's `Theme.light`.
   - **The ramp**: `bg0 < bg1 < bg2 < bg3 < bg4` backgrounds (bg0 = bar/cards), then
     `accent_dim < accent_mid < accent_light < accent_bright` and `fg` for text.
     Dark: bg0 ≈ #0a0a0a, fg ≈ #e8e8e8. Light: bg0 ≈ #f4f4f4, fg ≈ #141414.
     A tinted theme keeps the same *luminance* steps, only the hue changes.
   - **Contrast targets** (WCAG-ish): `fg` on `bg0` ≥ 12:1, `accent_mid` on `bg0` ≥ 4.5:1
     (it is used for secondary text everywhere), `accent_dim` on `bg0` ≥ 3:1 (inactive).
     Light themes fail here first — the previous light theme needed its greys darkened.
   - `[terminal]` 16 colours are a grey ramp too; keep `background` = bg0-ish and
     `foreground` readable through kitty's translucency (light: darker than you think).
   - `[git]` keeps real hues. `[apps]` names the GTK/Qt/icon/cursor themes and `nvim_colorscheme`
     (any installed scheme works — LazyVim already ships `catppuccin-*` and `tokyonight-*`;
     `eclipse` is the generated grey one; check `ls ~/.local/share/nvim/lazy/` before naming another).
   - Layout the theme suggests (top-level keys, next to `mode`; all optional):
     `bar = "minimal"|"floating"|"pill"` (pill is shown as "Legacy"; default minimal),
     `dock = "bottom"|"left"|"right"|"top"|"off"` (default: shown at the bottom),
     `radius = 0..24` corner px for windows and the shell (default 4; 0 = square).
     The four shipped themes all use `bar = "minimal"` and no dock/radius keys.
   - **Hued theme** — the default for any new theme unless the user asks for monochrome:
     `hued = true` at the top, the ramp uses the
     palette's own surface/text steps (Mocha: crust→mantle→base→surface0→surface1, text/subtext/
     overlay), `accent_bright`/`active` = the palette's accent (Mocha: lavender), and the hue keys
     `red orange yellow green aqua blue purple` + `warning critical` carry the *real* colours
     (in mono themes they are greys). `[terminal]` is the palette's official 16-colour set.
     Copy `themes/catppuccin-mocha/` as the starting point instead of eclipse.
     Official palettes are usually already on disk: `~/.local/share/nvim/lazy/<scheme>/extras/kitty/*.conf`
     (tokyonight, catppuccin) is the exact 16-colour set and `lua/<scheme>/colors/*.lua` the ramp — read
     those instead of guessing hex values from memory.
3. Wallpaper: put one or more images in `backgrounds/` named `1-<slug>.png`, `2-…`.
   Match the mood (dark theme → dark image, light → bright). Prefer ≥ 2560 px wide,
   non-busy, so lock/login text stays readable over the blur. If downloading, use a
   source that allows reuse (Unsplash / Pexels / Wikimedia) and note the URL in a
   `backgrounds/SOURCES` file.
4. `orrery-theme set <id>` — it appears in the carousel (`SUPER+CTRL+SHIFT+SPACE`) automatically.
   **Then take its picker preview: `orrery-theme-preview <id>`** (and again after
   the last rating round, so the picture shows the final colours). It lays out
   fastfetch (small logo, no user/host), btop (preset 2: no process list) and
   Thunar (its own D-Bus session and config, a demo folder: no bookmarks,
   username or home folders) on an unused workspace, screenshots it into
   `themes/<id>/preview.jpg`, and restores the user's theme, workspace and dock.
   The picker shows that picture; a theme without one gets the drawn mock.
   It turns on the shell's shot mode (`qs ipc call shot on|off`: the bar
   hides now-playing) and matches its kitty windows by title, so the dock
   shows kitty's icon, not blank gears. Look at the result: nothing personal
   on screen (no track title, no real paths), nothing wrapped or "too small",
   the wallpaper visible around the windows.
   **A shipped theme** (one of the four in README) also has README shots:
   copy its preview to `Screenshots/<id>.jpg`, retake `menu-<id>.jpg` (menu's
   Appearance page, `qs ipc call menu open appearance`, on an empty workspace,
   cropped to the card) and `launcher-<id>.jpg` whenever something on them
   changes, then run `python3 Screenshots/make-cover.py`: it rebuilds the
   cover, the 1280x640 social preview (uploaded by hand in the repo's
   settings) and `themes.webp`, the README's crossfading theme tour. A new
   shipped theme needs an entry in its `SHOTS` and `BLURB`, and a
   `<details>` block in README's Themes section.
   Check `themes.webp` frame by frame, not only its first frame (the Read
   tool shows just that one): decode it with Pillow and compare each still
   to its preview. Encoded by ffmpeg, the WebP stored frames as lossy patches
   over earlier ones, and after three fades the dark Cassini wallpaper was
   blocky with Catppuccin's blues; the script now encodes with Pillow, every
   frame a keyframe (needs `python-pillow`).
5. **Verify in every surface** (verify.md). For btop use `orrery-float btop`
   (a tiled kitty next to other windows is < 80×24 and btop only prints "Terminal size too
   small"). `orrery-wall next` cycles to the theme's other backgrounds. Verify: bar (every skin: `qs ipc call bar toggle` cycles them),
   launcher `SUPER+D`, clipboard, notification (`qs ipc call notifications test`),
   panels (audio/network/power/agents), picker, power menu, lock screen (careful —
   see SKILL rule 5; the SDDM Main.qml uses the same geometry, so a screenshot of
   the lock screen stands in), kitty + fastfetch, btop, nvim, Thunar (GTK3, restart it),
   a Qt app (qt6ct-aware, restart it), VS Code, Spotify if installed. Fix any
   unreadable text by adjusting the ramp, not one app.
   - **Thunar's folders:** pick the Papirus folder colour closest to the
     accent (see *Folder colour* below) and set `icon_theme`; the stock blue
     folders clash with any non-blue theme. Look at Thunar with a folder
     *selected* too (click one), not just the grid.
5b. **Rate it, then iterate — at least 3 rounds, aiming for 9+/10.** After
   each round take the full set of screenshots (desktop with bar, dock,
   fastfetch + btop; launcher; menu; a panel; a notification; Thunar), then
   score 1–10 on four things and write the table down:
   | | Contrast | Fits the wallpaper | Harmony | Accent use | Overall |
   Contrast = run the contrast check (fg/bg0 ≥ 12, accent_mid ≥ 4.5,
   accent_dim ≥ 3, each hue ≥ 4.5 on bg0); fits = do the surfaces and accent
   read as part of the image or as grey on top of it; harmony = do the hues
   belong together; accent use = is the accent where the eye should go
   (active items, titles, progress) and nowhere else. Change what scored
   lowest, re-render, re-shoot, re-score. Stop at 3 rounds only when Overall
   is ≥ 9; otherwise keep going. Report each round's scores and what changed,
   and say what keeps it from a 10 (often something shell-wide, not the
   theme). Typical round-2/3 fixes: surfaces too neutral → tint them toward
   the image; borders grey → tint `accent_light` toward the accent (borders
   take it at 24%); a hue too loud → soften it toward the image.
6. The theme is the user's (its preview.jpg too): `themes/<id>/` is gitignored, so it stays on
   this machine. Don't commit it or `git add -f` it (MAINTAINER.md decides
   what ships). To share it, the user copies the folder.

**Folder colour (Thunar, file pickers).** `icon_theme = "Papirus-Dark-<colour>"`
(or `Papirus-Light-<colour>` for a light theme) gives folders in one of
Papirus' colours; `orrery-theme` builds that variant in `~/.local/share/icons`
without root (`ensure_folder_icons`: links to the `folder-<colour>*` /
`user-<colour>*` icons, including names that reach a blue icon through a chain
of links, like `folder-publicshare`). Choose by rendering a row of candidates
on the theme's bg2 and looking at it:
`rsvg-convert -w 64 /usr/share/icons/Papirus/64x64/places/folder-<c>.svg`,
colours: blue teal cyan darkcyan bluegrey grey black palebrown paleorange
deeporange brown red carmine magenta pink violet indigo green yellow orange
white. Mono themes use the default. After changing it, restart Thunar
(`pkill -x thunar`), open a folder and check every folder is recoloured —
one still blue means a missed link.

Thunar selection: Thunar paints the selection box itself, solid in
`theme_selected_bg_color`, and the label comes from `.cell:selected`;
gtk/.config/gtk-3.0/gtk.css sets that to `theme_selected_fg_color`. If a theme
makes selected labels hard to read, fix those two colours, not Thunar.

## Claude Code (and other TUIs with their own palette)

Claude Code doesn't read the terminal's colours; with no theme set it draws its
dark palette, which washes out on a light theme (white bullets, pale code). Its
`auto` theme queries the terminal background (OSC 11, kitty answers) and
follows light/dark live: tell the user to pick `/theme` → "Auto (match
terminal)". Don't edit `~/.claude.json` from inside a running session.

## Spotify

Spotify follows the theme through Spicetify: `templates/spicetify-color.ini.tpl`
maps the palette onto Spicetify's slots (main/sidebar/player = the bg ramp,
button/play-button/playback-bar = accent_bright, subtext = accent_mid) and
`spicetify/user.css` adds the 4px corners. `apply_spotify` in `orrery-theme`
installs them as the "orrery" theme on every switch — nothing to write per
theme. It runs only when `spicetify` (on PATH or `~/.spicetify/spicetify`)
is configured with a `spotify_path`.

- Setup, once: `spicetify config spotify_path <dir>` (spotify-launcher:
  `~/.local/share/spotify-launcher/install/usr/share/spotify`; the pacman
  `spotify` package in /opt needs write access for the user first), then
  `orrery-theme reload`; the first run does `spicetify backup apply`.
- Spotify reads the colours only at start: `apply_spotify` restarts it when
  playerctl says it isn't playing, and otherwise only notifies. Never stop
  someone's music to show a theme.
- Read spicetify config from the file, never with `spicetify config`:
  `grep -E '^(current_theme|color_scheme)' "$(spicetify -c)"`. Two words
  after `config` *set* the first to the second: `config current_theme
  color_scheme` wrote "color_scheme" into current_theme, and it happened
  twice. If it does: `spicetify config current_theme orrery color_scheme
  orrery && spicetify apply`.
- Spotify sets its window class late, so a window rule matching `^Spotify$`
  doesn't catch the first map; to screenshot it, move the window with its
  address after it appears (`hl.dsp.window.move({ window = "address:…",
  workspace = "9 silent" })`).
- After a Spotify update the patch is gone: `spicetify backup apply`.
- Verify: a screenshot of Spotify in every shipped theme; the playing-view
  accents (play button, progress bar) should be the theme's accent.

## Hued vs monochrome in templates

`{{ hued <a> <b> }}` renders `a` when the theme has `hued = true`, else `b`; only the chosen
side is resolved. Use it wherever a stock upstream theme would put a colour — one hue per
btop box, green→yellow→red temperature gradients, lock `fail_color` red, `check_color`
green — with the grey the mono themes had before as `b`. Check with a render diff that the
mono themes did not move:

```bash
cd ~/.config/orrery; for t in eclipse zenith; do
  python3 render.py themes/$t templates /tmp/$t-after >/dev/null; done   # vs a copy made before
```
The shell reads `hued` and `colors.good/warning/critical` from `colors.json`
(`Theme.hued`, `Theme.c.*`). Hued today: battery (charging green, ≤30 % yellow, ≤15 % red),
SysMon > 85 % yellow, critical notification border red. When adding a widget with a state,
follow that pattern — `Theme.hued ? Theme.c.critical : Theme.c.accentDim`.

## Firefox

`templates/firefox-userChrome.css.tpl` (browser chrome), `firefox-userContent.css.tpl`
(about: pages, new tab, reader) and `firefox-user.js.tpl` (prefs). `apply_firefox` in
`orrery-theme` installs them into every profile from `profiles.ini` — Firefox 156+ keeps
profiles under `~/.config/mozilla/firefox`, older builds under `~/.mozilla/firefox`. Facts
that cost time once:
- Both user sheets are *user-origin*: every declaration needs `!important` or the page's
  own tokens win (the settings page kept its cyan accent until then).
- Firefox ≥ 130 chrome is built on design-system tokens (`--background-color-canvas`,
  `--toolbar-background-color`, `--color-accent-primary`, `--panel-*`, `--tab-*`,
  `--urlbar-*`); override those, not element selectors. Pull current names from the build:
  `unzip -o /usr/lib/firefox/omni.ja 'chrome/toolkit/skin/classic/global/design-system/*.css'`.
- New tab uses its own `--newtab-*` vars (in browser/omni.ja, builtin-addons/newtab).
- Nothing reloads live: `pkill -x firefox` and relaunch; screenshot with
  `grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"`.
- A never-launched Firefox has no profile; `timeout 15 firefox --headless about:blank`
  creates one without a window.

## Change one app for every theme

Edit its template in `templates/`, `orrery-theme reload`, verify in dark and light.
If the app needs a file at a fixed path, add an `install_file` line in
`orrery-theme`'s `apply()` and, if it can be reloaded live, the reload there too
(see the kitty/btop/nvim lines). If it ships with the rice, add the app to README's live-vs-restart table.

## Make an app follow the theme (new template)

1. Find what the app reads (a config file, a theme dir, env vars, gsettings) and
   whether it reloads live (signal, IPC, file watch) — check its man page/source.
2. Write `templates/<file>.tpl` with the tags above; colour it the app's stock way and branch with `{{ hued … }}` so the mono themes stay grey.
3. Wire `apply()` in `theme/.local/bin/orrery-theme` (install + reload); an editor or
   browser goes in `apply_apps` (also run at login, for apps installed later). The script
   runs under `set -e` and the wallpaper and login-screen steps come last: call the new
   step as `apply_x || true`, and make every `x="$(…)"` that may find nothing end in
   `|| true` (a missing optional tool once stopped every fresh install before the
   wallpaper). Test it on a home folder **without** the app, as well as with it.
4. If it ships with the rice and the app is worth having on a fresh machine, add it to `PKGS_REPO` in install.sh.
5. Verify dark + light with screenshots (+ a README row if it ships).

## Font, text size, scale

These are the user's, not a theme's: `orrery-font set <family>` (families from
`orrery-font list`), `orrery-text-size <9-20>` and `orrery-scale <n>`. They write
`shell.json` (`font.family`, `font.size`) and render
`~/.config/orrery/ui/{kitty.conf,alacritty.toml}` plus a fontconfig rule;
a theme must never set them. In QML, sizes go through `Theme.fs(px)` and the
family through `Theme.font`.

## Wallpapers

`orrery-wall set <path>` / `next` — the shell draws it (`Wallpaper` service, crossfade),
the lock screen blurs it, SDDM gets a copy via root-sync. Any theme's
`backgrounds/` are offered in the picker (`SUPER+SHIFT+W`), current theme first, then the
user's wallpapers folder.

## Colours from wallpaper (the "Wallpaper" theme)

`orrery-wall-theme` (matugen, Material You) turns a picture into an ordinary theme,
`themes/wallpaper/colors.toml` (`GENERATED by orrery-wall-theme`, rewritten every time, and
gitignored like any user theme), then runs `orrery-theme set wallpaper`, so every template
follows it. "On" simply means the current theme is `wallpaper`; `off` returns to the theme
before (`~/.local/state/orrery/wallpaper-theme.json` remembers it and the settings).

- Its `backgrounds/` is a link to the wallpapers folder (`xdg-user-dir PICTURES`/Wallpapers):
  the picker lists it, `orrery-wall next` cycles it, and `orrery-wall set` on this theme calls
  back into `orrery-wall-theme apply` (guarded by `ORRERY_WALL_THEME=1`). A picture from
  anywhere else is **copied** into the folder (`import`/`use`), never moved; a shipped
  theme's background is used in place.
- `--mode auto` decides by brightness (ffmpeg YAVG ≥ 150 light, ≤ 110 dark, else the mode on
  screen); `--style soft|faithful|vivid` = matugen `scheme-tonal-spot|content|vibrant`;
  `--accent N` picks among the picture's main colours (`preview` lists the accent each
  gives). A grey picture (matugen `scheme-smart` gives a grey primary) becomes a mono theme,
  `hued = false`, with Eclipse's hues.
- Mapping: dark `bg0..bg4` = surface_container_lowest, surface, container, high, highest
  (light: surface, low, container, high, highest); `fg` on_surface; `accent_bright` primary;
  `accent_light` on_surface_variant; `accent_mid` outline (light: neutral_variant 40, as
  outline is only 4.3:1 there); `accent_dim` neutral_variant 50. The seven hues are fixed
  colours that matugen harmonises towards the picture (`custom_colors`, `blend = true`).
  Material's tone system keeps every result at the contrast targets; `tests/check.py
  --theme <dir>` checks a generated theme the same way as the shipped ones.
- matugen runs on a cached 256 px copy (`~/.cache/orrery/wallpaper-theme/`): ~0.1–0.5 s a
  picture; the theme switch after it is the usual ~3 s.
- The picker (`Picker/WallOptions.qml`, `Services/WallTheme.qml`): the switch, Auto/Dark/Light,
  Soft/Faithful/Vivid, the accent swatches and a palette chip for the selected picture;
  Ctrl+T/M/S/1–4/O; dropping an image file adds it. Thunar: right-click a picture >
  "Set as wallpaper" (`orrery-wall-theme use`, installed into `uca.xml` by install.sh).

## Aether (the Omarchy theming app) as a palette source

`aether --generate <image> --no-apply --output <dir>` renders Aether's own templates
(colors.toml in Omarchy names, btop, neovim.lua for aether.nvim, vscode extension, chromium
"r,g,b", …) into `<dir>` without touching the system — the safe way to see its extraction or
its per-app mapping. **`--import-colors-toml` / `--import-base16` / `--apply-blueprint` apply
immediately** (they write `~/.config/aether/theme/`, a VS Code extension
`local.theme-aether-*` and `~/.config/zed/themes/aether.json`); do not use them to inspect.
The GUI's swatches can be read off a screenshot by sampling pixels (ffmpeg → rgb24 → python).
The rice mirrors Aether's app mappings as `templates/*-aether*.tpl` + `nvim_colorscheme =
"aether"` so a palette can be compared both ways on the same theme.
