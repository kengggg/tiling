#!/usr/bin/env bash
# Thin installer for AeroSpace + SketchyBar.
# Assumes Homebrew is already installed. Never runs as root.
# Copies the config into place. The running files do not point at the clone,
# so moving the clone does not break the bar. Run this again after a pull.
# A live file that differs is moved to name.bak-<timestamp> first.

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run install.sh as root." >&2
  exit 1
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TS="$(date +%Y%m%d%H%M%S)"
LIVE_AERO="$HOME/.aerospace.toml"
LIVE_BAR="$HOME/.config/sketchybar"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

case "$REPO" in
  "$LIVE_BAR"|"$LIVE_BAR"/*)
    echo "This clone must not live inside ~/.config/sketchybar." >&2
    exit 1
    ;;
esac

if [ -x /opt/homebrew/bin/brew ]; then
  BREW=/opt/homebrew/bin/brew
elif command -v brew >/dev/null 2>&1; then
  BREW="$(command -v brew)"
else
  echo "Homebrew is not installed. Install it first, or run mac-setup, then re-run this." >&2
  exit 1
fi
eval "$("$BREW" shellenv)"

install_cask() {
  local token="$1" spec="$2"
  if brew list --cask "$token" >/dev/null 2>&1; then
    log "$token already installed"
    return 0
  fi
  log "brew install --cask $spec"
  brew install --cask "$spec"
}

install_formula() {
  local token="$1" spec="$2"
  if brew list "$token" >/dev/null 2>&1; then
    log "$token already installed"
    return 0
  fi
  log "brew install $spec"
  brew install "$spec"
}

# A regular file with the same bytes. Symlinks are never "current".
same_file() {
  [ -f "$1" ] && [ -f "$2" ] && [ ! -L "$1" ] && [ ! -L "$2" ] && cmp -s "$1" "$2"
}

plugin_scripts() {
  local sh
  shopt -s nullglob
  for sh in "$REPO/sketchybar/plugins/"*.sh; do
    printf '%s\n' "$sh"
  done
}

bar_current() {
  local sh base found=0
  [ -d "$LIVE_BAR" ] && [ ! -L "$LIVE_BAR" ] || return 1
  same_file "$REPO/sketchybar/sketchybarrc" "$LIVE_BAR/sketchybarrc" || return 1
  while IFS= read -r sh; do
    [ -n "$sh" ] || continue
    found=1
    base="$(basename "$sh")"
    same_file "$sh" "$LIVE_BAR/plugins/$base" || return 1
  done < <(plugin_scripts)
  [ "$found" -eq 1 ] || return 1
  shopt -s nullglob
  for sh in "$LIVE_BAR/plugins/"*.sh; do
    base="$(basename "$sh")"
    [ -f "$REPO/sketchybar/plugins/$base" ] || return 1
  done
  return 0
}

backup_path() {
  local dest="$1" target
  if [ -L "$dest" ]; then
    target="$(readlink "$dest")"
    case "$target" in
      /*) ;;
      *) target="$(dirname "$dest")/$target" ;;
    esac
    # Keep a real copy of whatever the symlink still reaches. A saved symlink
    # would dangle once the old repo pointer is removed.
    if [ -d "$target" ]; then
      mkdir -p "$dest.bak-$TS"
      cp -R "$target"/. "$dest.bak-$TS"/
      rm "$dest"
      warn "backed up $dest -> $dest.bak-$TS"
    elif [ -f "$target" ]; then
      cp -p "$target" "$dest.bak-$TS"
      rm "$dest"
      warn "backed up $dest -> $dest.bak-$TS"
    else
      rm "$dest"
      warn "removed dangling symlink $dest"
    fi
    return 0
  fi
  if [ -e "$dest" ]; then
    mv "$dest" "$dest.bak-$TS"
    warn "backed up $dest -> $dest.bak-$TS"
  fi
}

install_plugins() {
  local sh base
  mkdir -p "$LIVE_BAR/plugins"
  cp -p "$REPO/sketchybar/sketchybarrc" "$LIVE_BAR/sketchybarrc"
  chmod +x "$LIVE_BAR/sketchybarrc"
  while IFS= read -r sh; do
    [ -n "$sh" ] || continue
    base="$(basename "$sh")"
    cp -p "$sh" "$LIVE_BAR/plugins/$base"
    chmod +x "$LIVE_BAR/plugins/$base"
    log "installed ~/.config/sketchybar/plugins/$base"
  done < <(plugin_scripts)
}

# Missing packages only. Already-installed packages are left at their current version.
install_cask aerospace nikitabobko/tap/aerospace
install_formula sketchybar felixkratz/formulae/sketchybar
install_cask font-hack-nerd-font font-hack-nerd-font

if same_file "$REPO/aerospace.toml" "$LIVE_AERO"; then
  log "already current ~/.aerospace.toml"
else
  backup_path "$LIVE_AERO"
  cp -p "$REPO/aerospace.toml" "$LIVE_AERO"
  log "installed ~/.aerospace.toml"
fi

if bar_current; then
  log "already current ~/.config/sketchybar"
  chmod +x "$LIVE_BAR/sketchybarrc" "$LIVE_BAR/plugins/"*.sh
else
  backup_path "$LIVE_BAR"
  install_plugins
  log "installed ~/.config/sketchybar"
fi

# The old installer linked through this pointer. Copies do not use it.
# Remove it only after backups, so a symlink backup can still read the files.
if [ -L "$HOME/.config/tiling/repo" ]; then
  rm "$HOME/.config/tiling/repo"
  rmdir "$HOME/.config/tiling" 2>/dev/null || true
  log "removed the old repo pointer ~/.config/tiling/repo"
fi

if aerospace list-monitors >/dev/null 2>&1; then
  aerospace reload-config
  log "reloaded AeroSpace"
else
  warn "AeroSpace is not running yet. Open it, or log out and back in."
fi

if pgrep -x sketchybar >/dev/null 2>&1; then
  /opt/homebrew/bin/sketchybar --reload
  log "reloaded SketchyBar"
else
  warn "SketchyBar is not running yet. AeroSpace starts it on launch."
fi

warn "If windows do not tile, enable AeroSpace under System Settings → Privacy & Security → Accessibility, then log out and back in."
