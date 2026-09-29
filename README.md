# tiling

AeroSpace and SketchyBar for Apple Silicon Macs. Separate from [kengggg/mac-setup](https://github.com/kengggg/mac-setup). This repo does not install Homebrew, a shell, or a terminal.

The bar is bash. Workspaces are `1`–`5`. The modifier is Option (`alt`).

## Install

Homebrew must already be installed. mac-setup does that.

```sh
git clone https://github.com/kengggg/tiling.git ~/Work/tiling
~/Work/tiling/install.sh
```

The clone can live anywhere. `install.sh` points `~/.config/tiling/repo` at it, then links:

| Live path | Repo file |
|-----------|-----------|
| `~/.aerospace.toml` | `aerospace.toml` |
| `~/.config/sketchybar` | `sketchybar/` |

A real file at either path is moved to `name.bak-<timestamp>` before the link is created. Running `install.sh` again does not make another backup when the link is already correct.

The installer adds these Homebrew packages only when they are missing. It does not upgrade them:

- `nikitabobko/tap/aerospace`
- `felixkratz/formulae/sketchybar`
- `font-hack-nerd-font` (the bar icons use Hack Nerd Font, not the Meslo font from mac-setup)

If windows do not tile, enable AeroSpace under **System Settings → Privacy & Security → Accessibility**, then log out and back in. `start-at-login` is on, and AeroSpace starts SketchyBar.

## Update another Mac

Configs are symlinks, so a pull updates the live files:

```sh
git -C ~/Work/tiling pull --ff-only
aerospace reload-config
sketchybar --reload
```

If the clone was moved:

```sh
~/Work/tiling/install.sh
```

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
