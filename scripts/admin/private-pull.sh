#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.private-pull
# Name:        Private Overlay aktualisieren
# Description: Führt git pull --ff-only im privaten Overlay aus
# Dependencies: sh, git
# Risk:        medium
# ============================================================

PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

err() {
  printf '%s\n' "admin.private-pull: $*" >&2
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  cmd=$1

  if ! have_cmd "$cmd"; then
    err "Required command not found: $cmd"
    return 1
  fi
}

main() {
  require_cmd git || return 1

  if [ ! -d "$PRIVATE_ROOT" ]; then
    err "Private overlay directory not found:"
    err "  $PRIVATE_ROOT"
    err "Clone or initialize it first:"
    err "  sx-ctl admin.private-clone <git-url>"
    err "  sx-ctl admin.private-init"
    return 1
  fi

  if [ ! -d "$PRIVATE_ROOT/.git" ]; then
    err "Private overlay is not a Git repository:"
    err "  $PRIVATE_ROOT"
    err "Use admin.private-pull only for Git-backed private overlays."
    return 1
  fi

  echo "Updating private overlay"
  echo "========================"
  echo
  echo "Root:"
  echo "  $PRIVATE_ROOT"
  echo

  (
    cd "$PRIVATE_ROOT"

    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
      err "Refusing to pull with uncommitted changes."
      err "Commit, stash or discard local changes first."
      return 1
    fi

    git pull --ff-only
  )
}

main "$@"
