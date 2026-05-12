#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.private-remove
# Name:        Private Overlay entfernen
# Description: Entfernt das lokale private Overlay nach Bestätigung
# Dependencies: sh
# Risk:        high
# ============================================================

PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

err() {
  printf '%s\n' "admin.private-remove: $*" >&2
}

main() {
  if [ ! -e "$PRIVATE_ROOT" ]; then
    echo "Private overlay does not exist:"
    echo "  $PRIVATE_ROOT"
    return 0
  fi

  if [ ! -d "$PRIVATE_ROOT" ]; then
    err "Private overlay path exists but is not a directory:"
    err "  $PRIVATE_ROOT"
    return 1
  fi

  echo "This will remove the local private overlay:"
  echo "  $PRIVATE_ROOT"
  echo
  echo "This does not delete any remote GitHub repository."
  echo
  echo "Risk: high"
  echo
  printf '%s' "Type 'yes' to continue: "

  IFS= read -r answer || return 1

  if [ "$answer" != "yes" ]; then
    echo "Aborted."
    return 0
  fi

  rm -rf "$PRIVATE_ROOT"

  echo "Private overlay removed:"
  echo "  $PRIVATE_ROOT"
}

main "$@"
