# tiling

The shared AeroSpace + SketchyBar setup for my Apple Silicon Macs and anyone who wants the same layout. Supports desktops and laptops running **macOS 27 or newer**. Five workspaces, Option (`alt`) shortcuts, and a Bash status bar.

The reference machine was checked on macOS 27.0 with AeroSpace 0.21.3-Beta and SketchyBar 2.24.0. Future macOS releases are a support target; they still need testing when available. Intel Macs and Rosetta terminals are rejected before installation.

## One-command guided setup

Run this in Terminal as your normal user:

```sh
/bin/bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/kengggg/tiling/main/bootstrap.sh | /bin/bash'
```

This downloads the current `main` archive from this repository, runs setup, and removes the temporary download. Git is not required. Review [bootstrap.sh](bootstrap.sh) and [install.sh](install.sh) before running if you prefer.

Setup will:

1. Check the operating system and architecture.
2. Show any existing configurations that differ. Replacement requires confirmation and makes backups. Declining stops setup before changing configurations or installing dependencies.
3. Show differing macOS preferences and ask to back them up and apply the shared settings below. Declining stops setup; use `--skip-settings` to opt out.
4. Offer to install [Homebrew](https://brew.sh) if missing. Its official installer may request an administrator password and install Apple's command line tools.
5. Install AeroSpace, SketchyBar, and Hack Nerd Font. Existing compatible packages are retained. Older dependencies require confirmation to upgrade.
6. Copy the shared configuration, apply the agreed preferences, open AeroSpace, and start or reload SketchyBar through Homebrew services.
7. Check that all five workspace buttons and their selected highlight match AeroSpace. Accessibility permission may still need your attention.

### Shared macOS settings

Setup backs up and applies these preferences after confirmation:

| Setting | Shared value |
|---|---|
| Automatically hide and show the menu bar | Always |
| Automatically hide and show the Dock | On |
| Group windows by application in Mission Control | On |
| Displays have separate Spaces | On |
| Stage Manager | Off |
| Click wallpaper to reveal desktop | Only in Stage Manager (inactive while Stage Manager is off) |
| Drag windows to screen edges to tile | Off |
| Drag windows to menu bar to fill screen | Off |
| Hold Option while dragging to tile | Off |
| Tiled windows have margins | Off |

The wallpaper stays behind your windows when clicked. Native edge and Option-drag tiling are disabled so AeroSpace owns tiling. Preference backups contain a restore script for only these keys; unrelated preferences are left alone. The Dock and menu-bar process restart after changes. If separate Spaces changed, log out and back in. SketchyBar [requires separate Spaces](https://felixkratz.github.io/SketchyBar/setup).

Grant **AeroSpace** access in **System Settings → Privacy & Security → Accessibility** when asked, then reopen it if needed. Each Mac needs its own permission. Quit competing window managers. Arrange monitors to suit each desk; workspace assignments are not tied to monitor names.

AeroSpace starts at login. **Homebrew services is SketchyBar's sole supervisor**, starting it at login and recovering it after an exit. AeroSpace sends state notifications to the bar. All five buttons are created even if AeroSpace starts later; the status item retries every five seconds and on wake. With AeroSpace unavailable, it displays “Waiting for AeroSpace”.

### Install from a clone instead

For editing and contributing:

```sh
git clone https://github.com/kengggg/tiling.git ~/Work/tiling && ~/Work/tiling/install.sh
```

If you already have this clone:

```sh
./install.sh
```

Homebrew must use its native Apple Silicon prefix, `/opt/homebrew`. Setup requires AeroSpace **0.21.0-Beta or newer** and SketchyBar **2.24.0 or newer**. The AeroSpace minimum supports `auto-reload-config`; the SketchyBar minimum is the tested baseline. Compatible packages are not automatically upgraded or pinned to exact versions.

## Shared configuration and backups

The installed files are copies. Moving or deleting the download or clone does not break the running setup.

| Installed path | Source |
|---|---|
| `~/.aerospace.toml` | `aerospace.toml` |
| `~/.config/sketchybar/sketchybarrc` | `sketchybar/sketchybarrc` |
| `~/.config/sketchybar/plugins/*.sh` | Every `sketchybar/plugins/*.sh` |

The installer stages complete replacements before touching live files. It makes scripts executable and backs up differing configurations beside their original locations as `name.bak-<timestamp>`, adding a number if necessary. Matching files do not create another backup. Linked configurations are copied into real backups, including linked plugin directories.

AeroSpace cannot use both `~/.aerospace.toml` and its alternate config location. Setup checks `~/.config/aerospace/aerospace.toml` and `$XDG_CONFIG_HOME/aerospace/aerospace.toml`. Existing alternate files are shown for confirmation, backed up, and removed from active use. This setup always installs to the paths in the table.

**Updates replace the shared configuration; they do not merge customizations.** This keeps machines on the same settings. The entire SketchyBar directory is replaced if it differs, including additional personal files; those files remain in its backup. If you want to keep a different setup, decline replacement and manage it separately.

For an intentional replacement and preference update without those two prompts:

```sh
./install.sh --replace-config --apply-settings
```

To copy files without changing macOS preferences or issuing launch, reload, or restart commands:

```sh
./install.sh --no-start --skip-settings
```

An already running AeroSpace may still auto-reload when its config changes. `--no-start` defers service registration until a normal setup run. Homebrew installation and upgrades still require their own guided confirmation. `--skip-settings` is an opt-out from the shared baseline; `--check` still reports preference differences.

## Update another Mac

Run the one-command setup again to download the current shared setup. With a clone, use:

```sh
git -C ~/Work/tiling pull --ff-only && ~/Work/tiling/install.sh
```

A Git pull alone does not update the installed copies. Keep the same repository revision across Macs when comparing configurations. The package versions can differ above the supported minimums.

## Check and troubleshoot

From the clone:

```sh
./install.sh --check
```

This check makes no changes. It reports dependency versions, config conflicts or differences, the active AeroSpace config and its validation, SketchyBar's Homebrew service registration, all five workspace buttons and their current highlight, the binding-mode indicator, and shared macOS preference differences. A nonzero exit means something needs attention. From the downloaded setup, the equivalent command is:

```sh
/bin/bash -o pipefail -c 'curl -fsSL https://raw.githubusercontent.com/kengggg/tiling/main/bootstrap.sh | /bin/bash -s -- --check'
```

- **No tiling:** open AeroSpace and check Accessibility permission. After a dependency upgrade, quit and reopen AeroSpace so its running app matches its installed CLI.
- **No bar:** rerun setup, or inspect `brew services info sketchybar`. Service logs are `/opt/homebrew/var/log/sketchybar/sketchybar.out.log` and `sketchybar.err.log`.
- **Missing icons:** verify `font-hack-nerd-font` is installed, then reload the bar.
- **Two menu bars or overlapping windows:** check the menu bar and Spaces settings above. Test with both the built-in screen and any external display.
- **Wrong workspace highlight after reload:** allow up to five seconds for synchronization, then run the health check. Workspace events update immediately; periodic queries also recover missed events.
- **SERVICE indicator:** the keyboard is in service mode. Press Escape to reload and return to normal bindings.

## Restore or uninstall

Backups are never automatically deleted. Setup prints their exact paths.

To restore an earlier setup:

1. Quit AeroSpace from its menu. Run `brew services stop sketchybar` to stop its supervisor, then `pkill -u "$(id -u)" -x sketchybar` if an unmanaged bar remains.
2. Move the current `~/.aerospace.toml` and `~/.config/sketchybar` aside so you keep any newer edits.
3. Copy your selected backups back to their original paths, removing the `.bak-…` suffix. Restore a whole SketchyBar directory, not just its entry script.
4. If restoring an alternate AeroSpace config, remove the newly installed `~/.aerospace.toml` from active use so only one config location remains. Reopen AeroSpace; start SketchyBar using the method expected by the restored config.
5. To restore macOS preferences, run `/bin/bash` with the exact `~/.config/tiling/macos-settings-<timestamp>.<suffix>/restore.sh` path printed by setup. It restores previous values (or removes keys that were originally unset) and restarts the Dock/menu-bar process. Log out and back in if separate Spaces changed.

To remove the applications entirely, first stop them as above, then run:

```sh
brew uninstall --cask aerospace
brew uninstall sketchybar
```

Move the installed configuration paths aside or delete them after checking for edits. Keep the backups if you may restore later. Hack Nerd Font may be used by other applications; remove it separately only if unwanted. Restore macOS preferences with the saved script above or through System Settings.

## Keys

Option (`alt`) is the modifier.

| Keys | Action |
|---|---|
| `alt-h`, `alt-j`, `alt-k`, `alt-l` | Focus left, down, up, right |
| `alt-shift-h`, `alt-shift-j`, `alt-shift-k`, `alt-shift-l` | Move the window that way |
| `alt-minus`, `alt-equal` | Shrink or grow the window |
| `alt-1` … `alt-5` | Switch workspace |
| `alt-shift-1` … `alt-shift-5` | Move the current window to that workspace |
| `alt-tab` | Previous workspace |
| `alt-slash` | Change tiled layout orientation |
| `alt-comma` | Change accordion layout orientation |
| `alt-f` | AeroSpace fullscreen |
| `alt-shift-f` | Toggle floating/tiling |
| `alt-shift-semicolon` | Enter service mode |

In service mode: `esc` reloads the config and exits, `r` resets the workspace layout, and `f` toggles floating/tiling. The bar shows **SERVICE · Esc to exit**. **Option-Shift-Backspace closes every other window in the current workspace.** Plain Backspace has no close action. Each of these commands then leaves service mode.

Click a workspace number on the bar to switch to it. Bindings use QWERTY key positions and may take over Option combinations used for typing special characters.

## Bar

Left: workspaces `1`–`5`, then the front app name. Right: Wi-Fi, volume, battery, clock.

Desktop Macs without an internal battery hide the battery item. Wi-Fi hardware is detected rather than assumed to be `en0`; its icon shows link status, with `off` when disconnected. A Mac without a Wi-Fi interface hides that item. No network name is displayed.

This project is separate from [mac-setup](https://github.com/kengggg/mac-setup). It does not install a shell, terminal, Lua, SbarLua, or JankyBorders.

## Development checks

Run the regression suite with Python 3 (needed for development only):

```sh
python3 tests/test_setup.py
```

Tests use temporary directories and mocked applications. They cover copying, backups, symlinks, config conflicts, compatibility gates, service startup, delayed AeroSpace startup, stale or missing bar state, preference backup/restore, download failures, and hardware-specific plugins. They do not install packages or change your live settings. Accessibility grants, login startup, and multiple monitor layouts still need a real Mac check.

## License

This repository is licensed under the [MIT License](LICENSE). AeroSpace, SketchyBar, and the installed fonts retain their own licenses.
