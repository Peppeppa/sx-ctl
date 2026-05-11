#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl uninstaller
#
# Removes the installed sx-ctl wrapper.
#
# This script intentionally does not remove:
#   ~/.config/sx-ctl
#
# User configuration and private overlays should not be deleted
# without explicit user consent.
# ============================================================

SX_INSTALL_DIR="${SX_INSTALL_DIR:-$HOME/.local/bin}"
SX_INSTALL_BIN="${SX_INSTALL_BIN:-$SX_INSTALL_DIR/sx-ctl}"

sx_uninstall_err() {
  printf '%s\n' "sx-ctl uninstall: $*" >&2
}

sx_uninstall_usage() {
  cat <<'EOF'
sx-ctl uninstaller

Usage:
  sh uninstall.sh
  sh uninstall.sh --help

Environment:
  SX_INSTALL_DIR    Override install directory
  SX_INSTALL_BIN    Override installed binary path

Default:
  ~/.local/bin/sx-ctl

Note:
  This removes only the installed sx-ctl wrapper.
  It does not remove ~/.config/sx-ctl.
EOF
}

sx_uninstall_main() {
  case "${1:-}" in
  --help | -h | help)
    sx_uninstall_usage
    return 0
    ;;
  "")
    ;;
  *)
    sx_uninstall_err "Unknown argument: $1"
    sx_uninstall_err "Run: sh uninstall.sh --help"
    return 1
    ;;
  esac

  if [ ! -e "$SX_INSTALL_BIN" ]; then
    printf '%s\n' "sx-ctl is not installed at:"
    printf '%s\n' "  $SX_INSTALL_BIN"
    return 0
  fi

  if [ -d "$SX_INSTALL_BIN" ]; then
    sx_uninstall_err "Refusing to remove directory:"
    sx_uninstall_err "  $SX_INSTALL_BIN"
    return 1
  fi

  rm -f "$SX_INSTALL_BIN"

  printf '%s\n' "sx-ctl uninstalled successfully:"
  printf '%s\n' "  $SX_INSTALL_BIN"

  printf '\n'
  printf '%s\n' "Note:"
  printf '%s\n' "  ~/.config/sx-ctl was not removed."
}

sx_uninstall_main "$@"
