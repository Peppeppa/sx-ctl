#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.doctor
# Name:        Doctor Check
# Description: Prüft sx-ctl Setup, Dependencies und Overlay-Status
# Dependencies: sh, awk
# Risk:        low
# ============================================================

SX_RAW_BASE="${SX_RAW_BASE:-https://raw.githubusercontent.com/Peppeppa/sx-ctl/main}"
SX_LOCAL_ROOT="${SX_LOCAL_ROOT:-}"
SX_PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"
SX_INSTALL_BIN="${SX_INSTALL_BIN:-$HOME/.local/bin/sx-ctl}"

ERRORS=0
WARNINGS=0

section() {
  echo
  echo "$1"
  echo "------------------------"
}

ok() {
  printf '%s\n' "OK:    $*"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf '%s\n' "WARN:  $*"
}

fail() {
  ERRORS=$((ERRORS + 1))
  printf '%s\n' "ERROR: $*"
}

info() {
  printf '%s\n' "INFO:  $*"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_command() {
  cmd=$1
  required=${2:-optional}

  if have_cmd "$cmd"; then
    path=$(command -v "$cmd")
    ok "$cmd found: $path"
    return 0
  fi

  if [ "$required" = "required" ]; then
    fail "$cmd not found."
    return 1
  fi

  warn "$cmd not found."
  return 0
}

check_runtime() {
  section "Runtime"

  ok "POSIX shell is running."

  check_command sh required

  if have_cmd awk; then
    ok "awk found: $(command -v awk)"
  else
    fail "awk not found. Some admin helpers require awk."
  fi

  if have_cmd curl || have_cmd wget; then
    if have_cmd curl; then
      ok "curl found: $(command -v curl)"
    fi

    if have_cmd wget; then
      ok "wget found: $(command -v wget)"
    fi
  else
    fail "Neither curl nor wget found. sx-ctl cannot fetch public files."
  fi

  check_command git optional
  check_command bash optional
  check_command fzf optional
}

check_public_repo_context() {
  section "Public sx-ctl context"

  echo "SX_RAW_BASE:"
  echo "  $SX_RAW_BASE"

  if [ -n "$SX_LOCAL_ROOT" ]; then
    echo "SX_LOCAL_ROOT:"
    echo "  $SX_LOCAL_ROOT"

    if [ -d "$SX_LOCAL_ROOT" ]; then
      ok "SX_LOCAL_ROOT exists."
    else
      fail "SX_LOCAL_ROOT does not exist."
    fi
  else
    info "SX_LOCAL_ROOT is not set."
  fi

  if [ -f "./manifest.txt" ]; then
    ok "Local manifest found: ./manifest.txt"
  elif [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/manifest.txt" ]; then
    ok "Local manifest found: $SX_LOCAL_ROOT/manifest.txt"
  else
    warn "No local public manifest found. Remote manifest will be used when needed."
  fi

  if [ -f "./sx-ctl.sh" ]; then
    ok "Local entrypoint found: ./sx-ctl.sh"
  elif [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/sx-ctl.sh" ]; then
    ok "Local entrypoint found: $SX_LOCAL_ROOT/sx-ctl.sh"
  else
    warn "Local sx-ctl.sh not found."
  fi

  if [ -f "./sx-ctl-basic.sh" ]; then
    ok "Local basic frontend found: ./sx-ctl-basic.sh"
  elif [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/sx-ctl-basic.sh" ]; then
    ok "Local basic frontend found: $SX_LOCAL_ROOT/sx-ctl-basic.sh"
  else
    warn "Local sx-ctl-basic.sh not found."
  fi

  if [ -f "./lib/core.sh" ]; then
    ok "Local core found: ./lib/core.sh"
  elif [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/lib/core.sh" ]; then
    ok "Local core found: $SX_LOCAL_ROOT/lib/core.sh"
  else
    warn "Local lib/core.sh not found."
  fi
}

check_installation() {
  section "Installation"

  if [ -f "$SX_INSTALL_BIN" ]; then
    ok "Installed wrapper found: $SX_INSTALL_BIN"

    if [ -x "$SX_INSTALL_BIN" ]; then
      ok "Installed wrapper is executable."
    else
      warn "Installed wrapper exists but is not executable."
    fi
  else
    warn "Installed wrapper not found: $SX_INSTALL_BIN"
    info "Install with: curl -fsSL $SX_RAW_BASE/install.sh | sh"
  fi

  install_dir=${SX_INSTALL_BIN%/*}

  case ":${PATH:-}:" in
  *":$install_dir:"*)
    ok "Install directory is in PATH: $install_dir"
    ;;
  *)
    warn "Install directory is not in PATH: $install_dir"
    info "Add to shell config: export PATH=\"$install_dir:\$PATH\""
    ;;
  esac
}

check_private_overlay() {
  section "Private overlay"

  echo "SX_PRIVATE_ROOT:"
  echo "  $SX_PRIVATE_ROOT"

  if [ ! -e "$SX_PRIVATE_ROOT" ]; then
    warn "Private overlay does not exist."
    info "Create local overlay: sx-ctl admin.private-init"
    info "Clone private repo:  sx-ctl admin.private-clone <git-url>"
    return 0
  fi

  if [ ! -d "$SX_PRIVATE_ROOT" ]; then
    fail "Private overlay path exists but is not a directory."
    return 1
  fi

  ok "Private overlay directory exists."

  if [ -f "$SX_PRIVATE_ROOT/manifest.txt" ]; then
    ok "Private manifest found."
  else
    warn "Private manifest not found."
  fi

  if [ -f "$SX_PRIVATE_ROOT/env" ]; then
    ok "Private env found."
  else
    warn "Private env not found."
  fi

  if [ -d "$SX_PRIVATE_ROOT/scripts" ]; then
    ok "Private scripts directory found."
  else
    warn "Private scripts directory not found."
  fi

  if [ -d "$SX_PRIVATE_ROOT/.git" ]; then
    ok "Private overlay is a Git repository."

    if have_cmd git; then
      (
        cd "$SX_PRIVATE_ROOT"

        remote=$(git remote get-url origin 2>/dev/null || true)
        branch=$(git branch --show-current 2>/dev/null || true)

        if [ -n "$remote" ]; then
          ok "Private remote: $remote"
        else
          warn "Private Git remote is not configured."
        fi

        if [ -n "$branch" ]; then
          ok "Private branch: $branch"
        else
          warn "Private Git branch could not be determined."
        fi

        if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
          ok "Private Git working tree is clean."
        else
          warn "Private Git working tree has uncommitted changes."
        fi
      )
    else
      warn "git not found, cannot inspect private Git status."
    fi
  else
    info "Private overlay is not a Git repository."
  fi
}

check_manifest_validation() {
  section "Manifest validation"

  if [ -f "./scripts/admin/validate-manifest.sh" ]; then
    validator="./scripts/admin/validate-manifest.sh"
  elif [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/scripts/admin/validate-manifest.sh" ]; then
    validator="$SX_LOCAL_ROOT/scripts/admin/validate-manifest.sh"
  else
    warn "validate-manifest helper not found locally."
    info "You can still run: sx-ctl admin.validate-manifest"
    return 0
  fi

  if sh "$validator"; then
    ok "Manifest validation passed."
  else
    fail "Manifest validation failed."
  fi
}

main() {
  echo "sx-ctl doctor"
  echo "============="

  check_runtime
  check_public_repo_context
  check_installation
  check_private_overlay
  check_manifest_validation

  echo
  echo "Summary"
  echo "-------"
  echo "Errors:   $ERRORS"
  echo "Warnings: $WARNINGS"

  if [ "$ERRORS" -ne 0 ]; then
    echo
    echo "Result: issues found"
    return 1
  fi

  if [ "$WARNINGS" -ne 0 ]; then
    echo
    echo "Result: usable with warnings"
    return 0
  fi

  echo
  echo "Result: healthy"
  return 0
}

main "$@"
