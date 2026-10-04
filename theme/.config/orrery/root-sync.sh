#!/usr/bin/env bash
# orrery-root-sync — the one privileged step of a theme switch.
#
# Installed by install.sh as /usr/local/bin/orrery-root-sync (root-owned,
# not a symlink) with a sudoers rule that lets the desktop user run exactly
# this file without a password. orrery-theme calls it after every `set`.
#
# It copies the rendered theme to the two places the user cannot write:
#   /root/.config/…              pkexec GUIs (grub-customizer) run as root and
#                                read root's GTK config, so they need the
#                                same palette + settings.ini or they stay dark.
#   /usr/share/sddm/themes/…     the login screen runs as the sddm user.
#
# It takes no arguments and copies only fixed, known files from the calling
# user's ~/.config/orrery/current/ — nothing user-supplied reaches a path.

set -euo pipefail

user="${SUDO_USER:-}"
[[ -n "$user" && "$user" != root ]] || { echo "run via sudo from a normal user" >&2; exit 1; }
home="$(getent passwd "$user" | cut -d: -f6)"
[[ -d "$home" ]] || { echo "no home for $user" >&2; exit 1; }

cur="$home/.config/orrery/current"
[[ -f "$cur/palette.css" ]] || { echo "no rendered theme at $cur — run: orrery-theme set <name>" >&2; exit 1; }

put() { # put <src> <dst>  (644, root-owned, dirs created)
    [[ -f "$1" ]] || return 0
    install -D -m 644 -- "$1" "$2"
}

# ---- root's GTK config (pkexec apps) ----
put "$cur/palette.css"        /root/.config/orrery/current/palette.css
put "$cur/gtk3-settings.ini"  /root/.config/gtk-3.0/settings.ini
put "$cur/gtk4-settings.ini"  /root/.config/gtk-4.0/settings.ini
put "$cur/gtkrc-2.0"          /root/.gtkrc-2.0
put "$cur/kdeglobals"         /root/.config/kdeglobals
# gtk.css is not generated; it lives in the dotfiles and imports the palette
# by the relative path ../orrery/current/palette.css, which is why the
# palette above goes to that exact spot under /root.
put "$home/.config/gtk-3.0/gtk.css" /root/.config/gtk-3.0/gtk.css
put "$home/.config/gtk-4.0/gtk.css" /root/.config/gtk-4.0/gtk.css

# ---- login screen ----
sddm=/usr/share/sddm/themes/orrery
if [[ -d "$sddm" ]]; then
    put "$cur/sddm-theme.conf" "$sddm/theme.conf"
    # current/background is a symlink set by orrery-wall. Copy it under its own
    # extension and point theme.conf at that name.
    if [[ -e "$cur/background" ]]; then
        real="$(readlink -f "$cur/background")"; ext="${real##*.}"; ext="${ext,,}"
        case "$ext" in
            png|jpg|jpeg|webp)
                put "$real" "$sddm/background.$ext"
                sed -i "s|^background=.*|background=background.$ext|" "$sddm/theme.conf"
                ;;
        esac
    fi
fi

# ---- Chromium-family browsers (chromium / chrome / brave) ----
# They follow dark/light from the portal on their own; the managed policy
# only sets the toolbar colour so the frame matches the rice (Omarchy does
# the same). Written only where a browser is installed.
bg="$(sed -n 's/^@define-color bg0 \(#[0-9a-fA-F]*\);.*/\1/p' "$cur/palette.css")"
if [[ "$bg" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    for pair in chromium:/etc/chromium google-chrome-stable:/etc/opt/chrome brave:/etc/brave; do
        bin="${pair%%:*}"; dir="${pair#*:}"
        command -v "$bin" >/dev/null 2>&1 || continue
        install -d -m 755 -o root -g root "$dir/policies/managed"
        printf '{ "BrowserThemeColor": "%s" }\n' "$bg" > "$dir/policies/managed/orrery-color.json"
        chmod 644 "$dir/policies/managed/orrery-color.json"
        # the same policy under the rice's old name (hypr-dotfiles): two files
        # setting one policy conflict, and the old colour could win
        rm -f "$dir/policies/managed/hypr-theme-color.json"
    done
fi

echo "synced theme for root, sddm and browsers"
