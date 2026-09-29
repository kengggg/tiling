# tiling

AeroSpace and SketchyBar for Apple Silicon Macs. Separate from [kengggg/mac-setup](https://github.com/kengggg/mac-setup). This repo does not install Homebrew, a shell, or a terminal.

The bar is bash. Workspaces are `1`–`5`. The modifier is Option (`alt`).

## Install

Homebrew must already be installed. mac-setup does that.

```sh
git clone https://github.com/kengggg/tiling.git ~/Work/tiling
~/Work/tiling/install.sh
```

The clone can live anywhere. `install.sh` copies files into place. It does not symlink them, so moving the clone later does not break the bar.

| Copied to | From |
|-----------|------|
| `~/.aerospace.toml` | `aerospace.toml` |
| `~/.config/sketchybar/sketchybarrc` | `sketchybar/sketchybarrc` |
| `~/.config/sketchybar/plugins/*.sh` | every `sketchybar/plugins/*.sh` |

Each plugin script is marked executable, including scripts added to `plugins/` later. `sketchybarrc` is included too. It is the shell script SketchyBar runs, even though the name does not end in `.sh`.

If a live file or the whole `~/.config/sketchybar` directory differs from the clone, including an old symlink, it is moved to `name.bak-<timestamp>` and then replaced. A second run that finds the same bytes does not make another backup.

The installer adds these Homebrew packages only when they are missing. It does not upgrade them:

- `nikitabobko/tap/aerospace`
- `felixkratz/formulae/sketchybar`
- `font-hack-nerd-font` (the bar icons use Hack Nerd Font, not the Meslo font from mac-setup)

If windows do not tile, enable AeroSpace under **System Settings → Privacy & Security → Accessibility**, then log out and back in. `start-at-login` is on, and AeroSpace starts SketchyBar.

## Update another Mac

A pull updates only the clone. Copy the files into place again:

```sh
git -C ~/Work/tiling pull --ff-only
~/Work/tiling/install.sh
```

`install.sh` reloads AeroSpace and SketchyBar when they are already running. Moving the clone, or renaming its folder, does not affect the bar. Run `install.sh` from the new location only when you want to copy a newer version.

## Keys

Option (`alt`) is the modifier.

| Keys | Action |
|------|--------|
| `alt-h` `j` `k` `l` | Focus left, down, up, right |
| `alt-shift-h` `j` `k` `l` | Move the window that way |
| `alt-1` … `alt-5` | Switch workspace |
| `alt-shift-1` … `alt-shift-5` | Move the current window to that workspace |
| `alt-tab` | Previous workspace |
| `alt-f` | Fullscreen |
| `alt-shift-semicolon` | Service mode (`esc` leaves it) |

Click a workspace number on the bar to switch to it.

## Bar

Left: workspaces `1`–`5`, then the front app name. Right: Wi-Fi icon, volume, battery, clock.

The Wi-Fi item is an icon only. macOS prints `<redacted>` instead of the network name, and the script does not show that word. A down link shows `off`.

## Not in this repo

- Monitor layout. Home, work, and client sites use different extra displays. Do not pin workspaces to a monitor name here.
- `plugins/space.sh`, the unused macOS Spaces helper from the old bar.
- Lua, SbarLua, and JankyBorders.
