#!/usr/bin/env bash
# Thin installer for AeroSpace + SketchyBar.
# Assumes Homebrew is already installed. Never runs as root.
# Backs up a real file before replacing it with a symlink.
# Re-run this after moving the clone. Links go through ~/.config/tiling/repo.

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run install.sh as root." >&2
  exit 1
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TS="$(date +%Y%m%d%H%M%S)"
REPO_LINK="$HOME/.config/tiling/repo"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

case "$REPO" in
  "$HOME/.config/sketchybar"|"$HOME/.config/sketchybar"/*)
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

# Missing packages only. Already-installed packages are left at their current version.
install_cask aerospace nikitabobko/tap/aerospace
install_formula sketchybar felixkratz/formulae/sketchybar
install_cask font-hack-nerd-font font-hack-nerd-font

mkdir -p "$HOME/.config/tiling"
ln -sfn "$REPO" "$REPO_LINK"
log "repo pointer $REPO_LINK -> $REPO"

link_one() {
  local rel dest want
  rel="$1"
  dest="$2"
  want="$REPO_LINK/$rel"
  if [ "$(readlink "$dest" 2>/dev/null)" = "$want" ]; then
    log "already linked $dest"
    return 0
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak-$TS"
    warn "backed up $dest -> $dest.bak-$TS"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$want" "$dest"
  log "linked $dest -> $want"
}

link_one aerospace.toml "$HOME/.aerospace.toml"
link_one sketchybar "$HOME/.config/sketchybar"

chmod +x "$REPO/sketchybar/plugins/"*.sh

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
