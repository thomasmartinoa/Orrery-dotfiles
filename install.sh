#!/usr/bin/env bash
#
# Installer for thomasmartinoa/Orrery-dotfiles
# See usage() below, or run ./install.sh --help

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Every top-level directory that is a stow package.
PACKAGES=(alacritty gtk hyprland kittyterminal nvim quickshell starship theme zsh)
# Stow packages of earlier versions, replaced by the Quickshell shell: their
# old links are cleaned up after stowing (see "Symlinks").
RETIRED_PACKAGES=(waybar rofi swaync wlogout)

PKGS_REPO=(
  hyprland hyprlock hypridle quickshell
  xdg-desktop-portal-hyprland polkit-gnome qt5ct qt6ct power-profiles-daemon
  kitty alacritty zsh starship
  neovim fastfetch btop eza
  grim slurp wl-clipboard cliphist playerctl brightnessctl batsignal ffmpeg hyprsunset
  thunar pavucontrol networkmanager nm-connection-editor
  # colours from the wallpaper (orrery-wall-theme) and its file chooser
  matugen zenity
  # what the shell talks to: notifications, volume, bluetooth, battery, links
  libnotify pipewire pipewire-pulse wireplumber alsa-utils bluez bluez-utils blueman upower xdg-utils
  ttf-jetbrains-mono-nerd inter-font papirus-icon-theme adw-gtk-theme stow
  # theme engine: renderer, JSON edits, gsettings schema, portal settings backend
  # (GTK4/Zen follow dark/light through it), login screen
  python jq gsettings-desktop-schemas xdg-desktop-portal-gtk sddm
)

# Everything comes from the official repos: no AUR, nothing to compile. (Qt
# apps use Qt's built-in Fusion style with the theme's colours, which used to
# need adwaita-qt from the AUR.)

# ============================================================================
# Presentation
# ============================================================================
# Colour only when stdout is a terminal, so piping to a file or a pager gives
# clean text instead of escape sequences.
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_DIM=$'\033[2;37m'; C_TXT=$'\033[0;37m';  C_HI=$'\033[1;97m'
  C_OK=$'\033[1;32m';  C_WRN=$'\033[1;33m';  C_ERR=$'\033[1;31m'
  C_ACC=$'\033[1;36m'; C_RST=$'\033[0m'
else
  C_DIM=''; C_TXT=''; C_HI=''; C_OK=''; C_WRN=''; C_ERR=''; C_ACC=''; C_RST=''
fi

STEP_N=0
STEP_TOTAL=11

banner() {
  printf '%s\n' ""
  printf '%s\n' "${C_HI}     ██████╗ ██████╗ ██████╗ ███████╗██████╗ ██╗   ██╗${C_RST}"
  printf '%s\n' "${C_HI}    ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗╚██╗ ██╔╝${C_RST}"
  printf '%s\n' "${C_HI}    ██║   ██║██████╔╝██████╔╝█████╗  ██████╔╝ ╚████╔╝${C_RST}"
  printf '%s\n' "${C_DIM}    ██║   ██║██╔══██╗██╔══██╗██╔══╝  ██╔══██╗  ╚██╔╝${C_RST}"
  printf '%s\n' "${C_DIM}    ╚██████╔╝██║  ██║██║  ██║███████╗██║  ██║   ██║${C_RST}"
  printf '%s\n' "${C_DIM}     ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝${C_RST}"
  printf '%s\n' "${C_ACC}         d o t f i l e s${C_RST}${C_DIM}  ·  ${C_RST}${C_ACC}m a r t i n${C_RST}"
  printf '%s\n' ""
  printf '%s\n' "${C_DIM}    ────────────────────────────────────────────${C_RST}"
  printf '%s\n' "${C_DIM}    repo   ${C_RST}${C_TXT}${DOTFILES_DIR}${C_RST}"
  printf '%s\n' "${C_DIM}    target ${C_RST}${C_TXT}${HOME}${C_RST}"
  printf '%s\n' "${C_DIM}    mode   ${C_RST}${C_TXT}${RUN_MODE}${C_RST}"
  printf '%s\n' "${C_DIM}    ────────────────────────────────────────────${C_RST}"
}

step()  { STEP_N=$((STEP_N+1)); printf '\n%s\n' "${C_ACC}[${STEP_N}/${STEP_TOTAL}]${C_RST} ${C_HI}$*${C_RST}"; }
skip()  { STEP_N=$((STEP_N+1)); printf '\n%s\n' "${C_DIM}[${STEP_N}/${STEP_TOTAL}] $* (skipped)${C_RST}"; }
info()  { printf '  %s %s\n' "${C_ACC}·${C_RST}" "$*"; }
ok()    { printf '  %s %s\n' "${C_OK}✓${C_RST}" "$*"; }
warn()  { printf '  %s %s\n' "${C_WRN}!${C_RST}" "$*" >&2; }
die()   { printf '\n  %s %s\n\n' "${C_ERR}✗${C_RST}" "$*" >&2; exit 1; }
# Indent every line of a multi-line block, not just the first. Trailing blank
# lines are dropped so callers don't have to trim their accumulators.
block() { printf '%s' "$*" | sed -e '/^[[:space:]]*$/d' -e 's/^/      /'; echo; }

# Stow's conflict text is a long sentence naming both the source and the target.
# Only the target matters to the reader, so pull it out:
#   "* cannot stow <src> over existing target <tgt> since neither a link ..."
#   "* existing target is not owned by stow: <tgt>"
conflict_targets() {
  sed -e 's|.*over existing target \([^ ]*\) since.*|~/\1|' \
      -e 's|.*existing target is not owned by stow: *|~/|' <<<"$*" \
    | sed 's/^[[:space:]]*\*[[:space:]]*//' | sort -u
}

usage() {
  cat <<'EOF'
Installer for thomasmartinoa/Orrery-dotfiles

  ./install.sh                install packages, then symlink configs with stow
  ./install.sh --stow-only    skip package installation
  ./install.sh --dry-run      show what stow would do, change nothing
  ./install.sh --migrate      back up blocking files without asking first
  ./install.sh --no-migrate   never move anything; stop instead
  ./install.sh --skip-root    skip root-owned bits (GTK config in /root, SDDM theme)
  ./install.sh --no-reboot    don't offer to reboot at the end
  ./install.sh --help         this text

On a fresh machine, Hyprland writes its own default ~/.config/hypr/hyprland.lua
on first launch, which blocks stow. A normal run notices this, shows you exactly
what is in the way, and offers to back it up — you do not need --migrate for the
common case. Use --migrate to skip that prompt (handy for scripted installs), or
--no-migrate to refuse outright.

Set NO_COLOR=1 to disable colour.
EOF
}

# ============================================================================
# Arguments
# ============================================================================
STOW_ONLY=0; DRY_RUN=0; MIGRATE=0; NO_MIGRATE=0; SKIP_ROOT=0; NO_REBOOT=0
for arg in "$@"; do
  case "$arg" in
    --stow-only)  STOW_ONLY=1 ;;
    --dry-run)    DRY_RUN=1 ;;
    --migrate)    MIGRATE=1 ;;
    --no-migrate) NO_MIGRATE=1 ;;
    --skip-root)  SKIP_ROOT=1 ;;
    --no-reboot|--no-logout)  NO_REBOOT=1 ;;
    --no-aur)     ;;   # nothing comes from the AUR any more; kept so old commands work
    -h|--help)   usage; exit 0 ;;
    *) printf 'unknown option: %s\n\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

RUN_MODE="full install"
[[ $STOW_ONLY -eq 1 ]] && RUN_MODE="stow only"
[[ $DRY_RUN   -eq 1 ]] && RUN_MODE="dry run (nothing will change)"
[[ $MIGRATE   -eq 1 ]] && RUN_MODE="$RUN_MODE + migrate"

banner

[[ $EUID -eq 0 ]] && die "Do not run this as root. It installs into \$HOME and calls sudo only where needed."

# ============================================================================
# 1. Packages
# ============================================================================
if [[ $STOW_ONLY -eq 0 && $DRY_RUN -eq 0 ]]; then
  step "Packages"

  if ! command -v pacman >/dev/null 2>&1; then
    warn "pacman not found — this installer only automates Arch-based systems."
    warn "Install these by hand, then re-run with --stow-only:"
    block "${PKGS_REPO[*]}"
    die "Nothing installed."
  fi

  # Check each package resolves BEFORE calling pacman. A single unknown name
  # makes `pacman -S` refuse the whole transaction, which under `set -e` would
  # abort the installer with a bare pacman error and nothing else done.
  info "Resolving ${#PKGS_REPO[@]} packages..."
  avail=(); missing=()
  for pkg in "${PKGS_REPO[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then avail+=("$pkg"); else missing+=("$pkg"); fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "${#missing[@]} package(s) not found in your configured repos:"
    block "${missing[*]}"
    warn "Continuing with the rest. Install those by hand if you want the full setup."
  fi

  if [[ ${#avail[@]} -gt 0 ]]; then
    info "Installing ${#avail[@]} package(s) — sudo will prompt."
    if ! sudo pacman -S --needed "${avail[@]}"; then
      echo
      warn "pacman could not complete that transaction."
      echo
      # By far the most common cause, and the error text is distinctive:
      #   installing aquamarine (0.15.0-2) breaks dependency
      #   'libaquamarine.so=13-64' required by hyprtoolkit
      info "The usual cause is a ${C_HI}partial upgrade${C_RST}: the package database was"
      info "refreshed with ${C_TXT}pacman -Sy${C_RST} but installed packages were never upgraded,"
      info "so new packages need libraries your system does not have yet."
      info "A \"breaks dependency 'libfoo.so=NN'\" message is the giveaway."
      echo
      info "The fix is a full upgrade. It may pull in a new kernel, in which"
      info "case reboot before carrying on."
      echo

      upgraded=0
      if [[ -t 0 && -t 1 ]]; then
        reply=""
        read -r -p "  $(printf '%s' "${C_ACC}?${C_RST}") Run ${C_TXT}sudo pacman -Syu${C_RST} now? [y/N] " reply </dev/tty || reply="n"
        echo
        case "${reply,,}" in
          y|yes)
            if sudo pacman -Syu; then
              info "Retrying the package install..."
              sudo pacman -S --needed "${avail[@]}" && upgraded=1
            fi
            ;;
        esac
      fi

      if [[ $upgraded -eq 0 ]]; then
        warn "Run this, then start install.sh again:"
        warn "   sudo pacman -Syu"
        die "Stopping here — nothing else has been changed."
      fi
    fi
    ok "Repo packages done."
  fi

else
  skip "Packages"
fi

command -v stow >/dev/null 2>&1 || die "GNU Stow is not installed (pacman -S stow)."

# ============================================================================
# 2. Migration
# ============================================================================
# Files written by nwg-look, the partial GTK4 theme-symlink hack, or Hyprland's
# own first-launch config generator sit exactly where stow needs to put symlinks.
#
# The GTK4 entries matter more than they look: symlinking only gtk.css from a
# theme into ~/.config/gtk-4.0/ breaks it, because GTK resolves that file's
# relative @imports against ~/.config/gtk-4.0/ (the logical path), not against
# the theme directory. libadwaita.css is then never found and GTK4 apps end up
# with no theme at all.
MIGRATE_PATHS=(
  # Hyprland writes a default config on its first launch when none exists. On a
  # fresh machine you log into Hyprland before running this script, so these are
  # almost always present and are the most common reason stow aborts. The
  # session banner "You're using an autogenerated config!" is the giveaway.
  "$HOME/.config/hypr/hyprland.lua"
  "$HOME/.config/hypr/hyprland.conf"
  "$HOME/.gtkrc-2.0.mine"
  "$HOME/.config/gtk-3.0/gtk.css"
  "$HOME/.config/gtk-4.0/gtk.css"
  "$HOME/.config/gtk-4.0/gtk-dark.css"
  "$HOME/.config/gtk-4.0/assets"
)

# Which MIGRATE_PATHS are actually present and not already links we own?
# A link already pointing into the repo is a *good* stow — moving it would undo
# the install and make repeated runs destructive instead of idempotent.
#
# Resolve the WHOLE path, not just the last component: when stow has folded a
# directory (~/.config/hypr -> repo/hyprland/.config/hypr), the file inside is
# a plain file whose canonical path is in the repo. Checking only `-L "$f"`
# misses that, and `mv` then drags the real config OUT of the repo — after
# which Hyprland writes its autogenerated default into the repo. Been there.
migratable_now() {
  local f
  for f in "${MIGRATE_PATHS[@]}"; do
    [[ -e "$f" || -L "$f" ]] || continue
    if [[ "$(readlink -f "$f" 2>/dev/null)" == "$DOTFILES_DIR"/* ]]; then
      continue
    fi
    printf '%s\n' "$f"
  done
}

do_migrate() {
  local backup rel f moved=0
  backup="$HOME/.config/orrery-backup-$(date +%Y%m%d-%H%M%S)"
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    # Preserve the path under $HOME, not just the basename: gtk-3.0/settings.ini
    # and gtk-4.0/settings.ini would otherwise collide and one would be lost.
    rel="${f#"$HOME"/}"
    mkdir -p "$backup/$(dirname "$rel")"
    mv -- "$f" "$backup/$rel"
    info "moved ~/${rel}"
    moved=$((moved+1))
  done < <(migratable_now)
  if [[ $moved -gt 0 ]]; then
    ok "Backed up $moved file(s) to ${backup/#$HOME/\~}"
  else
    ok "Nothing to move."
  fi
}

detect_conflicts() {
  stow --no --verbose=1 --target="$HOME" --dir="$DOTFILES_DIR" "${PACKAGES[@]}" 2>&1 \
    | grep -i 'existing target' || true
}

# Conflicts this script will NOT touch — anything outside MIGRATE_PATHS.
uncovered_conflicts() {
  local line m covered out=""
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    covered=0
    for m in "${MIGRATE_PATHS[@]}"; do
      grep -qF "${m#"$HOME"/}" <<<"$line" && { covered=1; break; }
    done
    [[ $covered -eq 0 ]] && out+="$line"$'\n'
  done <<<"$1"
  printf '%s' "$out"
}

step "Migration"
conflicts="$(detect_conflicts)"
pending="$(migratable_now)"

if [[ -z "$conflicts" ]]; then
  ok "Nothing in the way."
elif [[ $DRY_RUN -eq 1 ]]; then
  info "Would back up:"
  block "$(sed "s|^$HOME|~|" <<<"$pending")"
elif [[ -z "$pending" ]]; then
  ok "Nothing this script can move — see the checks below."
else
  uncovered="$(uncovered_conflicts "$conflicts")"

  warn "These files are where stow needs to put symlinks:"
  block "$(sed "s|^$HOME|~|" <<<"$pending")"

  # The overwhelmingly common case on a fresh install: you logged into Hyprland
  # once before running this, so Hyprland generated its own default config.
  if grep -q 'hypr/hyprland\.\(lua\|conf\)' <<<"$pending"; then
    echo
    info "hyprland.lua there is Hyprland's own autogenerated default — it writes"
    info "one on first launch when no config exists. Replacing it is expected."
  fi
  echo
  info "They will be MOVED (not deleted) to a timestamped backup under"
  info "~/.config/, so you can put any of them back afterwards."
  echo

  if [[ $NO_MIGRATE -eq 1 ]]; then
    warn "--no-migrate given; leaving them alone."
  elif [[ $MIGRATE -eq 1 ]]; then
    do_migrate
  elif [[ -t 0 && -t 1 ]]; then
    # Interactive: ask. Read from the terminal directly so this still works when
    # stdin is a pipe (e.g. `curl ... | bash` style invocations).
    reply=""
    read -r -p "  $(printf '%s' "${C_ACC}?${C_RST}") Back them up and continue? [Y/n] " reply </dev/tty || reply="n"
    echo
    case "${reply,,}" in
      ""|y|yes) do_migrate ;;
      *)        warn "Left alone at your request." ;;
    esac
  else
    warn "Not a terminal, so not moving anything without asking."
    warn "Re-run with --migrate to back these up automatically."
  fi

  if [[ -n "$uncovered" ]]; then
    echo
    warn "Note: these are outside what this script will touch —"
    block "$(conflict_targets "$uncovered")"
    warn "move them by hand before re-running."
  fi
fi

# ============================================================================
# 3. Pre-flight
# ============================================================================
step "Pre-flight checks"

if [[ $DRY_RUN -eq 0 ]]; then
  # Where screenshots are saved (scripts/screenshot.sh creates it too).
  mkdir -p "$HOME/Pictures/screenshot"
  # These must be REAL directories, not stow-folded symlinks.
  #
  # gtk-3.0/gtk-4.0: gtk.css starts with `@import '../orrery/palette.css'`.
  #   If the whole directory is a symlink into the repo, that relative import
  #   resolves from inside the repo (~/Orrery-dotfiles/gtk/.config/) rather than
  #   ~/.config/, finds nothing, and EVERY @define-color below it collapses —
  #   silently, leaving the stock theme colours. Keeping the directory real
  #   makes stow link the files inside it, so ../ is ~/.config/ as intended.
  # qt5ct/qt6ct: real dirs so the qt*ct.conf written below has somewhere to go.
  for _d in gtk-3.0 gtk-4.0 qt5ct qt6ct; do
    _t="$HOME/.config/$_d"
    # Unfold a directory symlink we previously created; never touch anything else.
    if [[ -L "$_t" && "$(readlink -f "$_t" 2>/dev/null)" == "$DOTFILES_DIR"/* ]]; then
      rm -- "$_t"
    fi
    mkdir -p "$_t"
  done

  # ~/.local: on a fresh machine it may not exist yet. Stow then folds the
  # WHOLE of ~/.local into a symlink to theme/.local, and every app that writes
  # to ~/.local (nvim, Trash, uv, ...) writes straight into the repo. Creating
  # the real path up front makes stow link only the one .colors file.
  #
  # If it is already folded, do NOT just delete the link like above: the app
  # data would be stranded inside the repo and re-linked back. Refuse instead.
  for _d in .local .local/bin .local/share; do
    _t="$HOME/$_d"
    if [[ -L "$_t" && "$(readlink -f "$_t" 2>/dev/null)" == "$DOTFILES_DIR"/* ]]; then
      warn "~/$_d is a symlink into the repo (stow folded it)."
      warn "Move the real data back home before re-running:"
      warn "  rm ~/$_d"
      warn "  mv $DOTFILES_DIR/theme/$_d ~/$_d"
      warn "  git -C $DOTFILES_DIR checkout -- theme/.local"
      die "Refusing to continue with ~/$_d folded."
    fi
    mkdir -p "$_t"
  done
  ok "Directories ready."
fi

# Every package must exist, or stow fails partway through.
absent=()
for pkg in "${PACKAGES[@]}"; do
  [[ -d "$DOTFILES_DIR/$pkg" ]] || absent+=("$pkg")
done
if [[ ${#absent[@]} -gt 0 ]]; then
  warn "These stow packages are listed but missing from the repo:"
  block "${absent[*]}"
  die "Repo looks incomplete — a partial clone?"
fi
ok "All ${#PACKAGES[@]} stow packages present."

# Re-check after the migration step. Anything still here was either declined,
# or is outside MIGRATE_PATHS and therefore not ours to move.
conflicts="$(detect_conflicts)"
if [[ -z "$conflicts" ]]; then
  ok "No conflicts."
elif [[ $DRY_RUN -eq 1 ]]; then
  # Nothing was moved, so of course they are still there. Say that plainly
  # rather than reporting it as a blocker.
  info "Still present (a real run would clear the migratable ones):"
  block "$(conflict_targets "$conflicts")"
else
  echo
  warn "Still blocked by:"
  block "$(conflict_targets "$conflicts")"
  # Use a real blocked path in the example, not a hardcoded one that may have
  # nothing to do with what is actually in the way.
  # Herestring rather than a pipe: `head -1` closes early, and with a large
  # enough upstream that raises SIGPIPE which `set -o pipefail` would turn into
  # an abort — inside the very block that is trying to explain the problem.
  all_targets="$(conflict_targets "$conflicts")"
  first="$(head -1 <<<"$all_targets")"
  warn "Move each aside and re-run, e.g.:"
  warn "   mv ${first} ${first}.bak"
  die "Aborting so nothing of yours is lost."
fi

# ============================================================================
# 4. Symlinks
# ============================================================================
if [[ $DRY_RUN -eq 1 ]]; then
  step "Symlinks (dry run)"
  plan="$(stow --no --verbose=2 --target="$HOME" --dir="$DOTFILES_DIR" "${PACKAGES[@]}" 2>&1 \
          | grep -E '^(LINK|UNLINK|CONFLICT)' || true)"
  if [[ -n "$plan" ]]; then
    block "$plan"
    info "$(grep -c '^LINK' <<<"$plan" || true) link(s) would be created."
  else
    ok "Nothing to do — all ${#PACKAGES[@]} packages are already linked."
  fi
  printf '\n  %s %s\n\n' "${C_OK}✓${C_RST}" "Dry run complete — nothing was changed."
  exit 0
fi

step "Symlinks"
info "Stowing: ${PACKAGES[*]}"
stow --restow --target="$HOME" --dir="$DOTFILES_DIR" "${PACKAGES[@]}"
ok "${#PACKAGES[@]} packages linked."

chmod +x "$HOME/.config/hypr/scripts/songdetail.sh" 2>/dev/null || true

# Earlier versions linked waybar, rofi, swaync and wlogout configs; those
# folders are gone from the repo, so their links point at nothing. Remove
# only links into this repo: anything of the user's own stays.
_repo_name="$(basename "$DOTFILES_DIR")"
for _old in "${RETIRED_PACKAGES[@]}"; do
  _dir="$HOME/.config/$_old"
  if [[ -L "$_dir" ]]; then
    [[ "$(readlink "$_dir")" == *"$_repo_name/$_old/"* ]] && rm -f "$_dir" && ok "Removed the old $_old link."
  elif [[ -d "$_dir" ]]; then
    find "$_dir" -type l -lname "*$_repo_name/$_old/*" -delete 2>/dev/null
    find "$_dir" -depth -type d -empty -delete 2>/dev/null
  fi
done

# ============================================================================
# 5. Qt configuration
# ============================================================================
# Templated rather than stowed: color_scheme_path must be an absolute path
# (qt*ct resolves it with QFile, which does not expand "~"), and the qt*ct GUIs
# rewrite these files in place, which would push window geometry into git.
step "Qt configuration"
# qt5ct.conf / qt6ct.conf and the colour scheme are rendered by orrery-theme
# (templates/qt*ct.conf.tpl) and installed by its Theme step below.
mkdir -p "$HOME/.config/qt5ct/colors" "$HOME/.config/qt6ct/colors"
ok "qt5ct/qt6ct directories ready (config comes from orrery-theme)."

# ============================================================================
# 6. Root theming
# ============================================================================
# Theme. Everything colour-related is rendered from theme/.config/orrery
# into ~/.config/orrery/current/ (gitignored) and applied to running apps.
# Without this step GTK, kitty, the shell... import files that do not exist yet.
step "Theme"
if [[ $DRY_RUN -eq 1 ]]; then
  info "Would run: orrery-theme set $(cat "$HOME/.config/orrery/current/theme.name" 2>/dev/null || echo eclipse)"
else
  _theme="$(cat "$HOME/.config/orrery/current/theme.name" 2>/dev/null || echo eclipse)"
  if "$HOME/.local/bin/orrery-theme" set "$_theme" >/dev/null; then
    ok "Theme '$_theme' rendered and applied."
  else
    warn "orrery-theme failed — run: orrery-theme set eclipse"
  fi
fi

# ============================================================================
# Shell odds and ends: the Quickshell shell is the notification daemon, so any
# other one installed (dunst from Arch's Hyprland profile, mako, swaync from an
# earlier version) must not be D-Bus-activated behind its back: whichever
# claims org.freedesktop.Notifications first wins, and the shell's popups and
# notification centre stay empty. Each one names a systemd user unit in its
# D-Bus service file; masking that unit stops the activation (the package
# stays). And the /orrery agent skill is
# linked into Claude Code / Codex / the generic ~/.agents dir so
# `/orrery <request>` works in any coding agent.
step "Shell"
if [[ $DRY_RUN -eq 1 ]]; then
  info "Would mask other notification daemons' user units and link the /orrery skill (orrery-agent skills install)."
  info "Would point Thunar's \"Open Terminal Here\" at orrery-terminal."
else
  for _svc in /usr/share/dbus-1/services/*.service; do
    grep -qx 'Name=org.freedesktop.Notifications' "$_svc" 2>/dev/null || continue
    _unit="$(sed -n 's/^SystemdService=//p' "$_svc")"
    [[ -n "$_unit" ]] || continue
    _bin="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$_svc")"
    # (set -e: each of these may "fail" harmlessly, e.g. nothing to stop)
    systemctl --user stop "$_unit" >/dev/null 2>&1 || true
    [[ -n "$_bin" ]] && { pkill -x "$(basename "$_bin")" 2>/dev/null || true; }
    systemctl --user mask "$_unit" >/dev/null 2>&1 \
      && ok "${_unit%.service} won't start: the shell shows notifications (unit masked)."
  done
  "$HOME/.local/bin/orrery-text-size" reset >/dev/null 2>&1 || true   # writes the terminal font family/size overrides
  # Thunar's "Open Terminal Here" runs exo-open, which on Xfce 4.20 needs
  # xfce4-mime-helper (xfce4-settings, not installed): point it at the rice's
  # default terminal instead. Only that one command is swapped; any other
  # custom actions stay as they are.
  _uca="$HOME/.config/Thunar/uca.xml"
  _exo='exo-open --working-directory %f --launch TerminalEmulator'
  if [[ ! -f "$_uca" && -f /etc/xdg/Thunar/uca.xml ]]; then
    mkdir -p "$(dirname "$_uca")" && cp /etc/xdg/Thunar/uca.xml "$_uca"
  fi
  if [[ -f "$_uca" ]] && grep -qF "$_exo" "$_uca"; then
    sed -i "s|$_exo|$HOME/.local/bin/orrery-terminal %f|" "$_uca" && ok "Thunar's \"Open Terminal Here\" opens your default terminal."
  fi
  # Thunar: right-click an image > "Set as wallpaper" (orrery-wall-theme use).
  # Added once, recognised by its id; uninstall.sh takes it out again.
  if [[ -f "$_uca" ]] && ! grep -q '<unique-id>orrery-set-wallpaper</unique-id>' "$_uca"; then
    _act="<action>\n\t<icon>preferences-desktop-wallpaper</icon>\n\t<name>Set as wallpaper</name>\n\t<submenu></submenu>\n\t<unique-id>orrery-set-wallpaper</unique-id>\n\t<command>$HOME/.local/bin/orrery-wall-theme use %f</command>\n\t<description>Use this picture as the wallpaper (Orrery)</description>\n\t<range>*</range>\n\t<patterns>*.png;*.jpg;*.jpeg;*.webp;*.PNG;*.JPG;*.JPEG;*.WEBP</patterns>\n\t<image-files/>\n</action>"
    sed -i "s|</actions>|$_act\n</actions>|" "$_uca" && ok "Thunar: right-click a picture > Set as wallpaper."
  fi
  if "$HOME/.local/bin/orrery-agent" skills install >/dev/null 2>&1; then
    ok "/orrery skill linked for coding agents ($(ls -d "$HOME"/.claude/skills "$HOME"/.agents/skills 2>/dev/null | tr '\n' ' '))."
  else
    warn "Skill link failed — run: orrery-agent skills install"
  fi
fi

# ============================================================================
# Services the desktop needs. Wi-Fi (NetworkManager), Bluetooth, power
# profiles and the login screen (SDDM). Careful with the two that another
# setup may already own: NetworkManager is not started while another network
# daemon runs (it would take the connection away mid-install), and SDDM is
# only enabled when no other display manager is.
if [[ $DRY_RUN -eq 1 ]]; then
  step "Services"
  info "Would enable: bluetooth, power-profiles-daemon, NetworkManager, sddm (each only if safe)."
elif ! command -v systemctl >/dev/null 2>&1; then
  skip "Services (no systemd)"
else
  step "Services"
  _enable() {   # unit [--now]
    systemctl is-enabled --quiet "$1" 2>/dev/null && { ok "$1 already enabled."; return; }
    if sudo systemctl enable ${2:-} "$1" >/dev/null 2>&1; then ok "$1 enabled."; else warn "Could not enable $1."; fi
  }
  systemctl list-unit-files bluetooth.service >/dev/null 2>&1 && _enable bluetooth.service --now
  systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1 && _enable power-profiles-daemon.service --now
  _other_net=""
  for u in systemd-networkd iwd dhcpcd connman netctl; do
    systemctl is-active --quiet "$u" 2>/dev/null && _other_net="$u"
  done
  if systemctl is-enabled --quiet NetworkManager 2>/dev/null; then
    ok "NetworkManager already enabled."
  elif [[ -n $_other_net ]]; then
    warn "$_other_net manages the network now; NetworkManager left alone (the Wi-Fi panel needs it)."
    info "To switch: sudo systemctl disable --now $_other_net && sudo systemctl enable --now NetworkManager"
  else
    _enable NetworkManager.service --now
  fi
  _dm="$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)"
  if [[ -z $_dm ]]; then
    _enable sddm.service   # not --now: that would end this session
  elif [[ $_dm == *sddm* ]]; then
    ok "sddm is the display manager."
  else
    warn "Display manager is $(basename "$_dm" .service); SDDM not enabled."
    info "To use the rice's login screen: sudo systemctl disable $(basename "$_dm") && sudo systemctl enable sddm"
  fi
fi

# ============================================================================
# SDDM login screen. The theme lives in sddm/orrery and mirrors hyprlock.
# Same approach as Omarchy: SDDM stays, gets a custom QML theme, and runs its
# greeter under Hyprland (sddm/hyprland.lua) instead of X11. All of it is
# plain files under /usr/share/sddm and /etc/sddm.conf.d — nothing is enabled
# or disabled, so a broken theme is fixed by deleting the drop-ins from a TTY.
if [[ $SKIP_ROOT -eq 1 ]]; then
  skip "SDDM theme"
elif [[ $DRY_RUN -eq 1 ]]; then
  skip "SDDM theme (dry run)"
elif ! command -v sddm >/dev/null 2>&1; then
  skip "SDDM theme (sddm not installed)"
else
  step "SDDM theme"
  info "Installs the Orrery login theme. sudo may prompt."
  if sudo -v; then
    sudo mkdir -p /usr/share/sddm/themes /etc/sddm.conf.d
    sudo rm -rf /usr/share/sddm/themes/orrery
    sudo cp -r -- "$DOTFILES_DIR/sddm/orrery"        /usr/share/sddm/themes/orrery
    sudo cp --    "$DOTFILES_DIR/sddm/hyprland.lua"    /usr/share/sddm/hyprland.lua
    sudo cp --    "$DOTFILES_DIR/sddm/sddm.conf.d/"*.conf /etc/sddm.conf.d/
    sudo chmod -R a+rX /usr/share/sddm/themes/orrery /usr/share/sddm/hyprland.lua
    ok "SDDM theme installed. Takes effect on next logout / reboot."
    info "Preview without logging out:"
    info "  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/orrery"
  else
    warn "Skipped — no sudo. Login screen keeps the current SDDM theme."
  fi
fi

# ============================================================================
# Root + SDDM sync. Two places a theme has to reach that the user cannot
# write: /root/.config (apps that re-exec through pkexec, e.g. grub-customizer,
# run as root and read root's GTK config — without it they stay stock/dark)
# and /usr/share/sddm/themes (the greeter runs as the sddm user).
#
# orrery-root-sync copies only fixed files from ~/.config/orrery/current
# and is installed root-owned (a copy, never a symlink into $HOME), with a
# sudoers rule for exactly that path so `orrery-theme set` can call it silently.
if [[ $SKIP_ROOT -eq 1 ]]; then
  skip "Root + SDDM sync"
elif [[ $DRY_RUN -eq 1 ]]; then
  skip "Root + SDDM sync (dry run)"
else
  step "Root + SDDM sync"
  info "Installs /usr/local/bin/orrery-root-sync and its sudoers rule. sudo may prompt."
  if sudo -v; then
    sudo install -o root -g root -m 755 -- "$DOTFILES_DIR/theme/.config/orrery/root-sync.sh" /usr/local/bin/orrery-root-sync
    _rule="$USER ALL=(root) NOPASSWD: /usr/local/bin/orrery-root-sync"
    printf '%s\n' "$_rule" | sudo tee /etc/sudoers.d/orrery-theme >/dev/null
    sudo chmod 440 /etc/sudoers.d/orrery-theme
    if sudo visudo -cf /etc/sudoers.d/orrery-theme >/dev/null 2>&1; then
      ok "sudoers rule installed for $USER."
    else
      sudo rm -f /etc/sudoers.d/orrery-theme
      warn "sudoers rule failed validation and was removed."
    fi
    if sudo /usr/local/bin/orrery-root-sync >/dev/null 2>&1; then
      ok "Theme synced to /root and SDDM."
    else
      warn "Sync failed — is a theme applied? (orrery-theme set eclipse)"
    fi
  else
    warn "Skipped — no sudo. pkexec GUIs keep the default theme; login screen keeps its colours."
  fi
fi

# ============================================================================
# Headset mic after sleep. Some laptops (Realtek codec behind Intel SOF) stop
# detecting a wired headset mic after suspend, so apps fall back to the
# built-in mic until the sound card is re-probed. orrery-fix-mic knows which
# models do this; on those, install its systemd-sleep hook. Everyone else can
# run `orrery-fix-mic` by hand, or `orrery-fix-mic enable` if they need it.
_fixmic="$DOTFILES_DIR/theme/.local/bin/orrery-fix-mic"
if [[ $SKIP_ROOT -eq 1 ]]; then
  skip "Headset mic after sleep"
elif [[ $DRY_RUN -eq 1 ]]; then
  skip "Headset mic after sleep (dry run)"
elif ! "$_fixmic" known; then
  skip "Headset mic after sleep (not needed on this model)"
else
  step "Headset mic after sleep"
  info "This laptop loses the headset mic on resume. Installs a sleep hook. sudo may prompt."
  if sudo -v; then
    sudo install -o root -g root -m 755 -- "$_fixmic" /usr/lib/systemd/system-sleep/orrery-headset-mic
    ok "Headset mic is re-detected after every sleep (orrery-fix-mic disable to undo)."
  else
    warn "Skipped — no sudo. Run orrery-fix-mic after waking if the headset mic is missing."
  fi
fi

# ============================================================================
# Summary
# ============================================================================
rule()  { printf '%s\n' "${C_DIM}  ────────────────────────────────────────────────────────────${C_RST}"; }
head2() { printf '\n  %s\n' "${C_HI}$*${C_RST}"; }
item()  { printf '  %s %s\n' "${C_DIM}·${C_RST}" "$*"; }

printf '\n'; rule
printf '\n  %s %s\n' "${C_OK}✓${C_RST}" "${C_HI}Installed.${C_RST}"

# NOTE: do not write this as `fc-list | grep -q`. `grep -q` exits on the first
# match, fc-list then dies of SIGPIPE (141), and `set -o pipefail` turns the
# whole pipeline into a failure — so the check reports "missing" even when the
# font is installed. Capture first, match second.
font_families="$(fc-list : family 2>/dev/null || true)"
if grep -qi 'JetBrainsMono Nerd Font Propo' <<<"$font_families"; then
  printf '  %s %s\n' "${C_OK}✓${C_RST}" "Font: JetBrainsMono Nerd Font Propo found."
else
  printf '  %s %s\n' "${C_WRN}!${C_RST}" "${C_WRN}Font missing:${C_RST} JetBrainsMono Nerd Font ${C_HI}Propo${C_RST}"
  printf '      %s\n' "Every icon in the bar and the menus will render as a blank box."
  printf '      %s\n' "Fix:  sudo pacman -S ttf-jetbrains-mono-nerd"
fi

head2 "Live already"
item "Configs are symlinked — Hyprland, the shell, theme engine, kitty, nvim, zsh."
item "${C_TXT}SUPER+CTRL+R${C_RST} restarts the shell; ${C_TXT}SUPER+SPACE${C_RST} is the menu; ${C_TXT}/orrery${C_RST} in Claude Code knows the rest."

head2 "Needs a reboot"
item "GTK and Qt apps read their theme once, at startup."
item "env.lua sets QT_QPA_PLATFORMTHEME and PATH — those only reach"
item "applications launched by a fresh session."

head2 "Worth doing first"
item "Screens use their preferred mode and an automatic scale. Pick a scale in"
item "Menu > Appearance > Display scale; exact modes go in ${C_TXT}monitors.local.lua${C_RST} (README)."
item "${C_TXT}orrery-theme set <name>${C_RST} re-renders and re-applies everything;"
item "the picker (SUPER+CTRL+SHIFT+SPACE) switches themes. GTK3 and Qt apps need"
item "a restart to follow a switch — the README has the live/restart table."

printf '\n'; rule

# ----------------------------------------------------------------- reboot ---
# The login screen, the services enabled above and every app's theme start
# cleanly only from a fresh boot, so offer one. A reboot needs nothing from
# the running session (a logout would have to talk to whatever Hyprland is
# running, with whatever config it loaded), so it works from a TTY too.
# Default is NO: rebooting closes whatever else is open.
if [[ $NO_REBOOT -eq 1 || $DRY_RUN -eq 1 ]]; then
  :
elif [[ -t 0 && -t 1 ]]; then
  printf '\n  %s %s\n' "${C_WRN}!${C_RST}" "Rebooting closes everything you have open."
  reply=""
  read -r -p "  $(printf '%s' "${C_ACC}?${C_RST}") Reboot now? [y/N] " reply </dev/tty || reply="n"
  echo
  case "${reply,,}" in
    y|yes)
      printf '  %s %s\n\n' "${C_ACC}·${C_RST}" "Rebooting..."
      systemctl reboot || warn "Could not reboot. Run: systemctl reboot"
      ;;
    *)
      printf '  %s %s\n\n' "${C_ACC}·${C_RST}" "Reboot when you are ready, then pick ${C_TXT}Hyprland${C_RST} on the login screen."
      ;;
  esac
else
  printf '\n  %s %s\n\n' "${C_ACC}·${C_RST}" "Reboot, then pick Hyprland on the login screen."
fi
