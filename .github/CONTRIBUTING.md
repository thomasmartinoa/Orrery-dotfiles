# Contributing to Orrery

Thanks for helping. Here's where things go:

- **Questions and setup help:** [Q&A](https://github.com/thomasmartinoa/Orrery-dotfiles/discussions/categories/q-a).
- **Bugs:** [open an issue](https://github.com/thomasmartinoa/Orrery-dotfiles/issues/new/choose)
  and include `orrery-doctor --share`.
- **Ideas:** [Ideas](https://github.com/thomasmartinoa/Orrery-dotfiles/discussions/categories/ideas)
  first, so we can agree on the shape before you write code.
- **Your own themes:** [Show and tell](https://github.com/thomasmartinoa/Orrery-dotfiles/discussions/categories/show-and-tell).
  New themes aren't added to the repo by pull request; sharing them there lets everyone try them.

## Pull requests

1. Fork, then work on a branch off `main`.
2. Keep each pull request to one change, with a commit message that says *why*.
3. Run `tests/check.py`: it checks scripts, QML, Lua, the menu, icons and every theme in a
   few seconds. GitHub runs it again on your pull request, along with a full install,
   uninstall and reinstall on a fresh Arch system. Then test on your machine: anything visual
   should look right in both a dark theme (Eclipse) and the light one (Zenith).
4. Don't commit anything personal: your name, home paths, monitor names, or wallpapers you
   don't have the rights to share.

## How it fits together

- `hyprland/`, `quickshell/`, `kittyterminal/`… are [GNU Stow](https://www.gnu.org/software/stow/)
  packages: each mirrors your home folder.
- Themes live in `theme/.config/orrery/themes/<name>/colors.toml`; `orrery-theme` renders every
  app's colours from them through the templates in `theme/.config/orrery/templates/`.
- The shell is plain QML under `quickshell/.config/quickshell/`. Restart it with `SUPER` `CTRL` `R`
  and read its log with `qs log`.
- The `/orrery` agent skill (`theme/.config/orrery/skills/orrery/`) documents all of this in
  detail. It's worth reading even if you don't use an agent.

By contributing, you agree that your work is released under the [MIT licence](../LICENSE).
