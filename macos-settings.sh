#!/bin/bash
# Sourced by install.sh. Only the listed keys are backed up and changed.

settings_spec() {
  cat <<'SETTINGS'
NSGlobalDomain|_HIHideMenuBar|1|Auto-hide the menu bar
NSGlobalDomain|AppleMenuBarVisibleInFullscreen|0|Hide the menu bar in fullscreen
com.apple.dock|autohide|1|Auto-hide the Dock
com.apple.dock|expose-group-apps|1|Group Mission Control windows by application
com.apple.spaces|spans-displays|0|Give displays separate Spaces
com.apple.WindowManager|GloballyEnabled|0|Disable Stage Manager
com.apple.WindowManager|EnableStandardClickToShowDesktop|0|Disable wallpaper-click desktop reveal
com.apple.WindowManager|EnableTilingByEdgeDrag|0|Disable native edge tiling
com.apple.WindowManager|EnableTopTilingByEdgeDrag|0|Disable native top-edge fill
com.apple.WindowManager|EnableTilingOptionAccelerator|0|Disable native Option-drag tiling
com.apple.WindowManager|EnableTiledWindowMargins|0|Disable native tiling margins
SETTINGS
}

read_setting() {
  local value
  value="$(defaults read "$1" "$2" 2>/dev/null)" || return 1
  case "$value" in
    1|true|TRUE|YES) printf '1\n' ;;
    0|false|FALSE|NO) printf '0\n' ;;
    *) return 2 ;;
  esac
}

bool_literal() { if [ "$1" = 1 ]; then printf true; else printf false; fi; }

check_settings() {
  local domain key wanted description actual failed=0
  while IFS='|' read -r domain key wanted description; do
    actual="$(read_setting "$domain" "$key")" || actual=unset
    if [ "$actual" != "$wanted" ]; then
      warn "macOS setting differs or is not explicitly configured: $description"
      failed=1
    fi
  done < <(settings_spec)
  return "$failed"
}

prepare_settings() {
  SETTINGS_NEEDED=0
  [ "$SETTINGS_MODE" != skip ] || { log "Skipping macOS preferences."; return 0; }
  if ! check_settings; then
    if [ "$SETTINGS_MODE" != apply ]; then
      confirm "Back up and apply the shared macOS settings listed above? The Dock will restart." || die "Cancelled. Use --skip-settings to install only the app configuration."
    fi
    SETTINGS_NEEDED=1
  fi
}

apply_settings() {
  local domain key wanted description actual rc snapshot
  [ "$SETTINGS_NEEDED" -eq 1 ] || return 0
  mkdir -p "$USER_DIR/.config/tiling"
  snapshot="$(mktemp -d "$USER_DIR/.config/tiling/macos-settings-$TS.XXXXXX")"
  printf '#!/bin/bash\nset -euo pipefail\n' > "$snapshot/restore.sh"
  # Finish the entire snapshot before any preference writes. Missing keys are
  # restored by deletion, preserving the original macOS default behavior.
  while IFS='|' read -r domain key wanted description; do
    if actual="$(read_setting "$domain" "$key")"; then
      printf 'defaults write %q %q -bool %q\n' "$domain" "$key" "$(bool_literal "$actual")" >> "$snapshot/restore.sh"
    else
      rc=$?
      [ "$rc" -eq 1 ] || die "Unexpected non-boolean setting $domain/$key. No preferences changed."
      printf 'defaults delete %q %q 2>/dev/null || true\n' "$domain" "$key" >> "$snapshot/restore.sh"
    fi
  done < <(settings_spec)
  cat >> "$snapshot/restore.sh" <<'RESTORE'
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
printf 'Preferences restored. Log out and back in to apply any separate-Spaces change.\n'
RESTORE
  chmod 700 "$snapshot/restore.sh"
  log "macOS preference restore script: $snapshot/restore.sh"

  while IFS='|' read -r domain key wanted description; do
    actual="$(read_setting "$domain" "$key")" || actual=unset
    if [ "$actual" != "$wanted" ]; then
      defaults write "$domain" "$key" -bool "$(bool_literal "$wanted")"
      log "$description"
    fi
  done < <(settings_spec)
  if [ "$NO_START" -eq 0 ]; then
    killall Dock 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
  fi
  check_settings || die "Some preferences did not persist. Restore script: $snapshot/restore.sh"
  log "Shared macOS preferences applied. If separate Spaces changed, log out and back in."
}
