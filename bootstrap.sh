#!/bin/bash
# Download a complete source archive before running setup; Git is not required.
set -euo pipefail

bootstrap() {
  [ "$(id -u)" -ne 0 ] || { printf 'Run setup without sudo.\n' >&2; return 1; }
  [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || {
    printf 'This release supports Apple Silicon Macs in a native terminal.\n' >&2
    return 1
  }
  BOOTSTRAP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tiling-download.XXXXXX")"
  trap 'rm -rf "$BOOTSTRAP_DIR"' EXIT
  curl -fL --retry 3 https://github.com/kengggg/tiling/archive/refs/heads/main.tar.gz -o "$BOOTSTRAP_DIR/source.tar.gz"
  tar -xzf "$BOOTSTRAP_DIR/source.tar.gz" -C "$BOOTSTRAP_DIR"
  /bin/bash "$BOOTSTRAP_DIR/tiling-main/install.sh" "$@"
}

# BASH_SOURCE is empty when the documented command feeds this through stdin.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then bootstrap "$@"; fi
