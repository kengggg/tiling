#!/bin/bash
# Guided installer, compatible with macOS's bundled Bash 3.2.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/macos-settings.sh"

log() { printf '==> %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

usage() {
  cat <<'HELP'
Usage: install.sh [--replace-config] [--apply-settings | --skip-settings] [--no-start] [--check]

  --replace-config  Back up and replace differing configurations without prompting.
  --apply-settings  Back up and apply shared macOS preferences without prompting.
  --skip-settings   Leave macOS preferences unchanged (health checks still report drift).
  --no-start        Skip application launch, reload, and Dock/menu-bar restart commands.
  --check           Report installation health without changing anything.
  --help            Show this help.

Existing configurations require confirmation before replacement. They are backed
up, not merged. Changed macOS preferences also require confirmation and are backed
up. Homebrew installation and dependency upgrades are guided steps.
HELP
}

confirm() {
  local answer
  if ! ( : </dev/tty ) 2>/dev/null; then
    warn "An interactive terminal is needed: $1"
    return 1
  fi
  printf '%s [y/N] ' "$1" >/dev/tty
  IFS= read -r answer </dev/tty || return 1
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

init_paths() {
  USER_DIR="$1"
  REPO="$2"
  LIVE_AERO="$USER_DIR/.aerospace.toml"
  LIVE_BAR="$USER_DIR/.config/sketchybar"
  ALT_AERO="$USER_DIR/.config/aerospace/aerospace.toml"
  XDG_AERO="${3:-$USER_DIR/.config}/aerospace/aerospace.toml"
  case "$XDG_AERO" in /*) ;; *) die "XDG_CONFIG_HOME must be an absolute path." ;; esac
  TS="$(date +%Y%m%d%H%M%S)"
}

check_platform() {
  [ "$(id -u)" -ne 0 ] || die "Run this as your normal user, without sudo."
  [ "$(uname -s)" = Darwin ] || die "This setup supports macOS only."
  [ "$(uname -m)" = arm64 ] || die "This release supports Apple Silicon in a native terminal. Intel and Rosetta are not supported."
  local macos_major
  macos_major="$(sw_vers -productVersion | cut -d. -f1)"
  [[ "$macos_major" =~ ^[0-9]+$ ]] && [ "$macos_major" -ge 27 ] || die "macOS 27 or newer is required."
}

exists() { [ -e "$1" ] || [ -L "$1" ]; }

same_file() {
  [ -f "$1" ] && [ -f "$2" ] && [ ! -L "$1" ] && [ ! -L "$2" ] && cmp -s "$1" "$2"
}

bar_current() {
  [ -d "$LIVE_BAR" ] && [ ! -L "$LIVE_BAR" ] || return 1
  # A linked directory can otherwise pass byte comparisons of its children.
  [ -z "$(find "$LIVE_BAR" -type l -print -quit)" ] || return 1
  diff -qr -x .DS_Store "$REPO/sketchybar" "$LIVE_BAR" >/dev/null 2>&1
}

check_source() {
  local sh physical_bar
  case "$REPO" in "$LIVE_BAR"|"$LIVE_BAR"/*) die "The clone must not live inside $LIVE_BAR." ;; esac
  if [ -d "$LIVE_BAR" ]; then
    physical_bar="$(cd "$LIVE_BAR" && pwd -P)"
    case "$REPO" in "$physical_bar"|"$physical_bar"/*) die "The clone must not live inside the installed bar directory." ;; esac
  fi
  [ -f "$REPO/aerospace.toml" ] || die "Missing aerospace.toml in $REPO."
  [ -f "$REPO/sketchybar/sketchybarrc" ] || die "Missing sketchybarrc in $REPO."
  [ -f "$REPO/sketchybar/plugins/aerospace.sh" ] || die "Missing SketchyBar plugins in $REPO."
  /bin/bash -n "$REPO/sketchybar/sketchybarrc"
  for sh in "$REPO/sketchybar/plugins/"*.sh; do /bin/bash -n "$sh"; done
}

confirm_replacement() {
  local conflicts=0 path
  if exists "$LIVE_AERO" && ! same_file "$REPO/aerospace.toml" "$LIVE_AERO"; then
    warn "Different AeroSpace configuration: $LIVE_AERO"
    conflicts=1
  fi
  if exists "$LIVE_BAR" && ! bar_current; then
    warn "Different SketchyBar configuration: $LIVE_BAR (the whole directory)"
    conflicts=1
  fi
  for path in "$ALT_AERO" "$XDG_AERO"; do
    if exists "$path"; then
      warn "Conflicting AeroSpace configuration to back up and remove: $path"
      conflicts=1
    fi
    [ "$ALT_AERO" != "$XDG_AERO" ] || break
  done
  if [ "$conflicts" -eq 1 ] && [ "$REPLACE_CONFIG" -ne 1 ]; then
    confirm "Back up these configurations and replace them with the shared defaults?" || die "Cancelled. Your configurations have not been changed."
  fi
}

find_brew() {
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW=/opt/homebrew/bin/brew
  elif command -v brew >/dev/null 2>&1; then
    BREW="$(command -v brew)"
  else
    return 1
  fi
  eval "$("$BREW" shellenv)"
}

ensure_brew() {
  if ! find_brew; then
    log "Homebrew is required: https://brew.sh"
    confirm "Download and run the official Homebrew installer? It may request your administrator password." || die "Install Homebrew, then run setup again."
    curl -fL --retry 3 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$WORK_DIR/homebrew.sh"
    /bin/bash "$WORK_DIR/homebrew.sh" </dev/tty
    find_brew || die "Homebrew was not found after installation."
  fi
  [ "$("$BREW" --prefix)" = /opt/homebrew ] || die "This release requires native Homebrew at /opt/homebrew."
}

install_packages() {
  if ! "$BREW" list --cask aerospace >/dev/null 2>&1; then
    "$BREW" install --cask nikitabobko/tap/aerospace
  fi
  if ! "$BREW" list --formula sketchybar >/dev/null 2>&1; then
    "$BREW" install felixkratz/formulae/sketchybar
  fi
  if ! "$BREW" list --cask font-hack-nerd-font >/dev/null 2>&1; then
    "$BREW" install --cask font-hack-nerd-font
  fi
}

version_at_least() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  awk -v actual="$1" -v minimum="$2" 'BEGIN {
    split(actual, a, "."); split(minimum, b, ".")
    for (i = 1; i <= 3; i++) {
      if (a[i]+0 > b[i]+0) exit 0
      if (a[i]+0 < b[i]+0) exit 1
    }
    exit 0
  }'
}

aerospace_version() {
  { aerospace --version 2>/dev/null || true; } | sed -nE 's/^aerospace CLI client version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'
}

check_versions() {
  local version
  version="$(aerospace_version)"
  if ! version_at_least "$version" 0.21.0; then
    if [ "$CHECK_ONLY" -eq 1 ]; then
      warn "AeroSpace 0.21.0-Beta or newer is required; found ${version:-unknown}."
      return 1
    fi
    confirm "AeroSpace ${version:-unknown} is too old. Upgrade it with Homebrew?" || die "AeroSpace 0.21.0-Beta or newer is required. No configurations were changed."
    "$BREW" upgrade --cask aerospace
    version_at_least "$(aerospace_version)" 0.21.0 || die "AeroSpace is still incompatible. Check for a pinned cask or an older CLI in PATH."
    warn "If AeroSpace is already open, quit and reopen it to use the upgraded version."
  fi
  command -v sketchybar >/dev/null 2>&1 || { warn "SketchyBar is missing."; return 1; }
  version="$(sketchybar --version | sed -nE 's/^sketchybar-v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
  if ! version_at_least "$version" 2.24.0; then
    if [ "$CHECK_ONLY" -eq 1 ]; then
      warn "SketchyBar 2.24.0 or newer is required; found ${version:-unknown}."
      return 1
    fi
    confirm "SketchyBar ${version:-unknown} is older than the tested baseline. Upgrade it with Homebrew?" || die "SketchyBar 2.24.0 or newer is required. No configurations were changed."
    "$BREW" upgrade sketchybar
    version="$(sketchybar --version | sed -nE 's/^sketchybar-v([0-9]+\.[0-9]+\.[0-9]+).*/\1/p')"
    version_at_least "$version" 2.24.0 || die "SketchyBar is still incompatible. Check for a pinned formula or an older binary in PATH."
  fi
  log "AeroSpace $(aerospace_version); $(sketchybar --version)"
}

backup_path() {
  local dest="$1" backup suffix=0
  LAST_BACKUP=""
  exists "$dest" || return 0
  backup="$dest.bak-$TS"
  while exists "$backup"; do
    suffix=$((suffix + 1))
    backup="$dest.bak-$TS-$suffix"
  done
  # Materialize links so moving an old clone cannot invalidate the backup.
  # Failed copies leave the live path untouched.
  if [ -L "$dest" ] && [ ! -e "$dest" ]; then
    ln -s "$(readlink "$dest")" "$backup" || return 1
  elif ! cp -pRL "$dest" "$backup"; then
    rm -rf "$backup"
    warn "Could not back up $dest. The original is unchanged; check for broken links."
    return 1
  fi
  rm -rf "$dest" || return 1
  LAST_BACKUP="$backup"
  warn "Backed up $dest -> $backup"
}

replace_path() {
  local staged="$1" dest="$2"
  backup_path "$dest" || return 1
  if ! mv "$staged" "$dest"; then
    if [ -n "$LAST_BACKUP" ]; then
      mv "$LAST_BACKUP" "$dest"
      warn "Restored $dest after installation failed."
    fi
    return 1
  fi
}

install_configs() {
  local path sh
  # Prepare complete replacements before touching existing configurations.
  mkdir -p "$WORK_DIR/bar/plugins" "$USER_DIR/.config"
  cp -p "$REPO/aerospace.toml" "$WORK_DIR/aerospace.toml"
  cp -p "$REPO/sketchybar/sketchybarrc" "$WORK_DIR/bar/sketchybarrc"
  for sh in "$REPO/sketchybar/plugins/"*.sh; do cp -p "$sh" "$WORK_DIR/bar/plugins/"; done
  chmod +x "$WORK_DIR/bar/sketchybarrc" "$WORK_DIR/bar/plugins/"*.sh

  for path in "$ALT_AERO" "$XDG_AERO"; do
    backup_path "$path"
    [ "$ALT_AERO" != "$XDG_AERO" ] || break
  done
  if same_file "$REPO/aerospace.toml" "$LIVE_AERO"; then
    log "Already current: $LIVE_AERO"
  else
    replace_path "$WORK_DIR/aerospace.toml" "$LIVE_AERO"
    log "Installed $LIVE_AERO"
  fi
  if bar_current; then
    chmod +x "$LIVE_BAR/sketchybarrc" "$LIVE_BAR/plugins/"*.sh
    log "Already current: $LIVE_BAR"
  else
    replace_path "$WORK_DIR/bar" "$LIVE_BAR"
    log "Installed $LIVE_BAR"
  fi
}

json_value() { /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null; }

bar_service_running() {
  local info
  info="$("$BREW" services info sketchybar --json 2>/dev/null)" || return 1
  [ "$(printf '%s' "$info" | json_value 0.running)" = true ] &&
    [ "$(printf '%s' "$info" | json_value 0.registered)" = true ]
}

ensure_bar_service() {
  local attempt
  if ! bar_service_running; then
    # Remove an old registration before replacing an unmanaged bar process.
    "$BREW" services stop sketchybar
    pkill -u "$(id -u)" -x sketchybar 2>/dev/null || true
    for attempt in 1 2 3 4 5; do
      if ! pgrep -u "$(id -u)" -x sketchybar >/dev/null 2>&1; then break; fi
      sleep 1
    done
    "$BREW" services start sketchybar
  fi
  log "Homebrew manages SketchyBar startup and recovery."
}

check_bar_state() {
  local focused mode sid item expected status failed=0
  focused="$(aerospace list-workspaces --focused 2>/dev/null)" || return 1
  mode="$(aerospace list-modes --current 2>/dev/null)" || return 1
  case "$focused" in 1|2|3|4|5) ;; *) warn "Focused workspace is outside the shared preset: $focused"; return 1 ;; esac
  [ -n "$mode" ] || return 1
  for sid in 1 2 3 4 5; do
    item="$(sketchybar --query "space.$sid" 2>/dev/null)" || item='{}'
    expected=off
    [ "$sid" != "$focused" ] || expected=on
    if [ "$(printf '%s' "$item" | json_value label.value)" != "$sid" ] ||
       [ "$(printf '%s' "$item" | json_value geometry.drawing)" != on ] ||
       [ "$(printf '%s' "$item" | json_value geometry.background.drawing)" != "$expected" ]; then
      warn "Workspace button $sid is missing, hidden, or incorrectly highlighted (focused: $focused)."
      failed=1
    fi
  done
  status="$(sketchybar --query aerospace_status 2>/dev/null)" || status='{}'
  if [ "$mode" = main ]; then
    [ "$(printf '%s' "$status" | json_value geometry.drawing)" = off ] || failed=1
  else
    expected="$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]') · Esc to exit"
    [ "$(printf '%s' "$status" | json_value geometry.drawing)" = on ] &&
      [ "$(printf '%s' "$status" | json_value label.value)" = "$expected" ] || failed=1
  fi
  [ "$failed" -eq 0 ] || { warn "SketchyBar state does not match AeroSpace's workspace/mode."; return 1; }
  log "All five workspace buttons, selection ($focused), and mode indicator ($mode) are correct."
}

start_apps() {
  local attempt
  ensure_bar_service
  if aerospace list-monitors >/dev/null 2>&1; then
    aerospace reload-config --no-gui || die "AeroSpace could not load the configuration. Check its version and the backups printed above. Restart AeroSpace if its app version differs from the CLI."
  else
    open -a AeroSpace
    log "Opened AeroSpace. Allow Accessibility access when macOS asks."
  fi
  for attempt in 1 2 3 4 5; do
    if sketchybar --query bar >/dev/null 2>&1; then break; fi
    sleep 1
  done
  sketchybar --reload "$LIVE_BAR/sketchybarrc" || die "SketchyBar did not load. Check brew services info sketchybar."
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if aerospace list-monitors >/dev/null 2>&1 && check_bar_state >/dev/null 2>&1; then
      log "AeroSpace and all five workspace buttons are ready. Try Option-1 through Option-5."
      return 0
    fi
    sleep 1
  done
  if ! aerospace list-monitors >/dev/null 2>&1; then
    warn "Setup needs Accessibility access. Enable AeroSpace in System Settings → Privacy & Security → Accessibility, then reopen AeroSpace."
  else
    warn "The bar has not synchronized yet. Run install.sh --check and inspect /opt/homebrew/var/log/sketchybar/."
  fi
}

check_health() {
  local failed=0 path
  find_brew || { warn "Homebrew is missing."; return 1; }
  check_versions || failed=1
  for path in "$ALT_AERO" "$XDG_AERO"; do
    if exists "$path" && exists "$LIVE_AERO"; then warn "Conflicting config: $path"; failed=1; fi
    [ "$ALT_AERO" != "$XDG_AERO" ] || break
  done
  [ -f "$LIVE_AERO" ] || { warn "Missing $LIVE_AERO"; failed=1; }
  [ -x "$LIVE_BAR/sketchybarrc" ] || { warn "Missing or non-executable $LIVE_BAR/sketchybarrc"; failed=1; }
  if ! same_file "$REPO/aerospace.toml" "$LIVE_AERO" || ! bar_current; then
    warn "Installed files differ from this shared setup. Re-run setup to synchronize them."
    failed=1
  fi
  if aerospace list-monitors >/dev/null 2>&1; then
    path="$(aerospace config --config-path)"
    log "Active AeroSpace configuration: $path"
    [ "$path" = "$LIVE_AERO" ] || { warn "AeroSpace is using a different configuration."; failed=1; }
    aerospace reload-config --dry-run --no-gui || failed=1
  else
    warn "AeroSpace is not responding. Open it and grant Accessibility access."
    failed=1
  fi
  if bar_service_running; then
    log "SketchyBar's Homebrew service is running and registered for login."
  else
    warn "SketchyBar's Homebrew service is not running and registered. Re-run setup."
    failed=1
  fi
  check_bar_state || failed=1
  check_settings || failed=1
  return "$failed"
}

main() {
  REPLACE_CONFIG=0
  NO_START=0
  CHECK_ONLY=0
  SETTINGS_MODE=ask
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --replace-config) REPLACE_CONFIG=1 ;;
      --apply-settings) SETTINGS_MODE=apply ;;
      --skip-settings) SETTINGS_MODE=skip ;;
      --no-start) NO_START=1 ;;
      --check) CHECK_ONLY=1 ;;
      -h|--help) usage; return 0 ;;
      *) usage >&2; die "Unknown option: $1" ;;
    esac
    shift
  done
  check_platform
  init_paths "$HOME" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" "${XDG_CONFIG_HOME:-$HOME/.config}"
  if [ "$CHECK_ONLY" -eq 1 ]; then check_health; return; fi
  check_source
  confirm_replacement
  prepare_settings
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tiling-install.XXXXXX")"
  trap 'rm -rf "$WORK_DIR"' EXIT
  log "Installing AeroSpace, SketchyBar and Hack Nerd Font."
  ensure_brew
  install_packages
  check_versions
  install_configs
  apply_settings
  if [ "$NO_START" -eq 0 ]; then start_apps; fi
  log "Configuration installed. AeroSpace starts at login; Homebrew supervises SketchyBar after setup starts it."
  log "System settings and restore instructions are in README.md. Monitor arrangement is your choice."
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
