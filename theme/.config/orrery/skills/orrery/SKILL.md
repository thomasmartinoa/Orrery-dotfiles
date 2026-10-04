---
name: orrery
description: >
  REQUIRED for anything about this Hyprland rice (~/Orrery-dotfiles): themes and
  colours, wallpapers, the Quickshell bar/panels/launcher/lock/picker and their
  plugins, keybindings, window/layer rules, monitors, Hyprland Lua config,
  terminals, nvim/btop/GTK/Qt theming, install.sh/stow, diagnosing the PC
  (crashes, logs, performance, battery, display), and checking that the rice
  looks right. Triggers: theme, rice, bar, widget, plugin, panel, launcher,
  lock screen, wallpaper, keybind, hyprland, quickshell, shell.json, colors.toml,
  orrery-theme, orrery-wall, orrery-agent, diagnose, doctor, crash, "why is X broken",
  screenshot check. One skill: read the request, pick the matching section.
---

# /orrery — this rice, one skill

Request: $ARGUMENTS

You are working on **Orrery, a Hyprland rice, on the user's own
machine**. The user installed it and now wants to make themes, customise
the bar and shell, change keybindings or fix something. Everything lives in
the git clone `~/Orrery-dotfiles` and is *symlinked* into `~` with GNU stow
(one package per app: `hyprland quickshell theme kittyterminal alacritty
nvim zsh starship gtk`, plus the `sddm` login theme install.sh copies; the
Quickshell shell is the whole desktop: there is no Waybar/Rofi/swaync/wlogout
any more). **Edit files in the repo**
— `~/.config/hypr` *is* `~/Orrery-dotfiles/hyprland/.config/hypr`.

**Changes stay on this machine.** Do not commit, push or open a PR unless
the user asks for it; `git diff` shows what you changed and `git stash` /
`git checkout -- <file>` undo it. Themes the user makes are theirs:
`themes/` tracks only the four shipped ones (`eclipse`, `zenith`,
`catppuccin-mocha`, `cassini`) and `.gitignore` keeps every other theme folder out —
never force-add one.

**If `MAINTAINER.md` exists next to this file, read it now**: you are then
working with the rice's maintainer, and its rules (committing, pushing,
what ships) override this paragraph. It is not part of the published rice.

## 1. Decide what the request is, then read the matching guide

| The request is about… | Guide | Typical words |
|---|---|---|
| a new theme, colours, dark/light, wallpaper, an app not following the theme (Thunar, Spotify…) | [`theming.md`](theming.md) | theme, palette, colors.toml, wallpaper, folder colour, Spotify, spicetify, "make X follow the theme" |
| the bar, a widget, a panel, launcher/clipboard/picker/lock/power/notifications, IPC, shell.json | [`plugins.md`](plugins.md) | bar, widget, plugin, module, panel, popup, quickshell, qml |
| keybindings, window/layer rules, monitors, gaps/borders/animations, autostart, idle | [`hyprland.md`](hyprland.md) | bind, key, rule, monitor, scale, gaps, blur, opacity, autostart |
| something broken, slow, crashing, hot, draining, not showing; "diagnose my PC" | [`diagnose.md`](diagnose.md) | crash, error, log, freeze, lag, battery, wifi, sound, gpu, "why" |
| "check the rice", "does it look right", screenshots, before/after comparison | [`verify.md`](verify.md) | check, verify, screenshot, identical, readable |
| install.sh, stow, a fresh machine, packages | §5 below + `install.sh` header | install, stow, fresh, package |

A request can span guides ("make a theme and a widget for it") — read both.
When the wording is ambiguous, ask one short question **before** changing
anything; otherwise just do it.

## 2. The map

```
~/Orrery-dotfiles/
├── install.sh                       fresh-machine installer (packages, migration, stow, theme, SDDM, sudoers)
├── hyprland/.config/hypr/
│   ├── hyprland.lua                 requires modules/*, then the theme's current/hyprland.lua
│   ├── modules/{env,autostart,binds,monitors,decorations,windowrules}.lua
│   ├── hypridle.conf  hyprlock.conf (fallbacks; the shell owns idle + lock)
│   └── scripts/  shell.sh lock.sh launcher.sh clipboard.sh powermenu.sh caffeine.sh brightness.sh
├── quickshell/.config/quickshell/   THE SHELL (Quickshell 0.3, QML) — see plugins.md
│   ├── shell.qml  Commons/{Theme,Config}.qml  Services/*.qml (singletons + IPC)
│   ├── Bar/ Dock/ Panels/ Launcher/ Clipboard/ Picker/ Lock/ Power/ Notifications/ Osd/ Wallpaper/
├── theme/.config/orrery/        THE THEME ENGINE — see theming.md
│   ├── themes/<id>/colors.toml + backgrounds/      one folder = one theme (picker auto-discovers)
│   ├── templates/*.tpl              one per app, rendered by render.py
│   ├── current/  → GENERATED. never edit; re-render with `orrery-theme reload`
│   ├── shell.json                   shell settings (bar position/skin layouts, modules, agents.default)
│   ├── menu.jsonc (+ menu.local.jsonc)   the SUPER+SPACE menu tree — see plugins.md
│   ├── agents/usage.py  skills/orrery/  plugins/  root-sync.sh
├── theme/.local/bin/  orrery-theme  orrery-wall  orrery-theme-menu  orrery-agent  orrery-doctor
├── sddm/  gtk/  nvim/  kittyterminal/  alacritty/  zsh/  starship/
└── README.md                        read its "Theming" and "Bar" sections when unsure
```

Commands you will use (all `--help`/header-documented — read the script if unsure):

| Command | Does |
|---|---|
| `orrery-theme list / current / set <id> / toggle / next / reload / apps / json` | apply a theme everywhere (renders templates → current/, installs GTK/Qt/KDE/btop files, reloads kitty/hyprland/nvim/shell, root+SDDM sync) |
| `orrery-wall set <path> / next / current / ensure` | wallpaper (shell layer; also lock + SDDM) |
| `orrery-theme-preview [<id>]` | real screenshot for the theme picker → `themes/<id>/preview.jpg`; restores everything after |
| `orrery-theme-menu theme|wallpaper` | open the carousel picker |
| `qs ipc call <target> <fn> [args]` | talk to the running shell. Targets: `bar dock theme wallpaper picker launcher clipboard notifications panels powermenu lock caffeine osd agents menu` (`qs ipc show` lists functions) |
| `qs log` | the shell's log (QML errors show here) |
| `~/.config/hypr/scripts/shell.sh restart` | restart the shell (needed after new files/qmldir changes; hot-reload can serve stale code) |
| `hyprctl reload && hyprctl configerrors` | after ANY Hyprland change; must print nothing |
| `orrery-agent list / default / launch / usage / skills install` | coding agents |
| `orrery-doctor [--print\|--share]` | diagnostics bundle (see diagnose.md); `--share` is redacted for a public issue |
| `orrery-fix-mic [status\|enable\|disable]` | re-detect a wired headset mic that stopped working (after sleep); `enable` = do it on every resume |
| `orrery-font set <family>` · `orrery-text-size <px>` · `orrery-scale <n>` | desktop font, apparent text size (shell + GTK + terminals) and monitor scale |
| `orrery-webapp add [--firefox\|--chromium] [name] <url> [icon]` · `remove <name>` · `list` | web apps: a site in a bare Firefox window (own profile) with its own launcher and dock icon (Menu › Web apps) |
| `orrery-terminal [path]` | open the default terminal (`orrery-default terminal`), in that folder; Thunar's "Open Terminal Here" uses it |
| `orrery-border radius <px>` · `width <px>` · `reset` | corners (windows + shell; 0 = square) and window border thickness |
| `qs ipc call menu open|run|search <id>` · `orrery-float <cmd>` · `orrery-edit <file>` · `orrery-toggle gaps|opacity` · `orrery-nightlight` · `orrery-remind` · `orrery-default` · `orrery-pkg` | menu actions, usable from anywhere |

## 3. Rules that keep the rice intact

1. **Never edit generated or foreign files**: `~/.config/orrery/current/*`,
   `~/.config/gtk-3.0/settings.ini`, `~/.config/kdeglobals`, `~/.config/qt5ct|qt6ct`,
   `~/.config/btop/themes/orrery-theme.theme`, `/usr/share/**`, `/etc/**`
   (except through install.sh). They are rendered from `templates/*.tpl` —
   change the template (all themes) or `colors.toml` (one theme).
2. **Colour is the default; monochrome only when the user asks for it.** Eclipse and
   Zenith are the greys-only look (plus `[git]` hues) and stay
   that way. Every other theme is **hued**: `hued = true` in colors.toml, the
   palette's official colours, and each app coloured the way its stock
   upstream theme does — btop one hue per box + real gradients, nvim's own
   scheme, bar battery green/yellow/red, critical notification red, lock fail
   red. Templates branch with `{{ hued <colour> <grey> }}` and QML with
   `Theme.hued ? Theme.c.good|warning|critical : <shade>`, so the mono themes
   stay pixel-identical (diff `render.py` output). Grey in a hued theme where
   a stock theme has colour is a bug, not restraint. Corners come from
   `Theme.radius` / `Theme.radiusSm` (4px by default; `orrery-border` changes
   them for windows and shell alike), never a literal, so a surface follows
   the user's choice; 1px border (`Theme.c.border`) everywhere, in every theme.
3. **Both modes, always.** Anything visual is checked on `eclipse` (dark)
   and `zenith` — `orrery-theme set <id>` swaps live; put the user's
   theme back when done (`orrery-theme current` first). A template change is
   also checked on one hued theme (`catppuccin-mocha`). When the request *was*
   "make me theme X", leave X applied at the end.
4. **Look at it, and rate it.** Every visual change ends with a screenshot you
   actually read (verify.md). "It should work" is not done. For a new theme or
   a visual redesign, score it out of 10 and iterate at least 3 rounds until it
   reaches 9+ (theming.md step 5b); show the user the scores per round.
5. **Do not break the session.** Never `pkill -f qs|quickshell|hypr` (matches
   your own shell); use `pkill -x`. Never run `hyprctl dispatch exit`,
   `loginctl terminate-*`, or a lock test you cannot unlock (`Lock.lock()`
   locks the real session — if you must, keep a terminal with
   `hyprctl eval 'hl.clear_crashed_lockscreen()'` ready). No `sudo` prompts
   in a non-interactive run: use `orrery-doctor` (no-sudo) or ask the user to
   run the privileged step.
6. **Never clobber the user's uncommitted work.** Check `git status` before
   editing; a file with their changes gets your edit applied on top of what
   is on disk (read it fully *before* opening it for writing: Python's
   `open(f, "w").write(fix(open(f).read()))` truncates first and reads an
   empty file). Commit only your own hunks, never `git add -A` over theirs.
7. **Backups are git.** Work on the current branch; `git stash`/`git checkout
   -- <file>` undoes a bad change. Before deleting or overwriting anything
   outside the repo, look at it.
8. **Fresh install must still work.** A change meant to ship with the rice
   (MAINTAINER.md) that adds a package, a file the theme installs, a stow
   package or a sudo step also updates `install.sh` and README. For a change
   that is only for this machine, tell the user what to install instead.

## 4. How a change is applied (live vs restart)

| You changed | Apply with |
|---|---|
| `themes/*/colors.toml`, `templates/*.tpl` | `orrery-theme reload` (or `set`) |
| `quickshell/**.qml` existing file | hot-reloads on save; if errors persist or a `qmldir` / new file is involved → `shell.sh restart` |
| `shell.json` | hot-reloads (Config watches it) |
| `hyprland/**.lua` | `hyprctl reload && hyprctl configerrors` |
| kitty.conf | `pkill -SIGUSR1 -x kitty` |
| GTK3 apps, Qt apps, Kdenlive, Alacritty | need an app restart (documented; not a bug) |
| `theme/.local/bin/*`, new stow files | `cd ~/Orrery-dotfiles && stow -R theme` (a new *file* in an already-linked dir needs nothing; a new *dir* needs restow) |

## 5. Fresh machine / install.sh

`install.sh` is the source of truth for packages (`PKGS_REPO`, official repos only — no AUR),
stow packages (`PACKAGES`), migration of pre-existing configs, pre-flight
guards against stow "folding" `~/.local`, Qt env, theme apply, SDDM theme and
the root-sync sudoers rule. It is idempotent; `--dry-run` exists. When you
add anything a fresh user needs, add it there and bump `STEP_TOTAL` if you
add a step. Test with a fake HOME only if you can fully stub the tools
(`hyprctl`, `qs`, `chromium`, `gsettings`, `sudo`, and `pgrep` returning 1) —
an earlier run leaked into the live session. Don't stub optional apps the user
may not have (spicetify, code): a fresh machine lacks them, and that is the
path to test. install.sh runs under `set -e`: a step that may "fail" harmlessly
(`pkill` of nothing, `systemctl stop` of a stopped unit) ends in `|| true`, or
the rest of the install silently never runs. The real test is a VM: `install.sh --stow-only --skip-root`
over SSH covers everything but the sudo steps.

## 6. Finish

- Screenshot-verified in dark and light (verify.md), `hyprctl configerrors`
  clean, `qs log` free of new warnings.
- No commit or push unless the user asked (or MAINTAINER.md says so).
- Tell the user in a few lines what changed and how to use it; include the
  keybinding or command, and how to undo it if it is a big change.
