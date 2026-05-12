#!/usr/bin/env sh
# shellcheck shell=sh

# ============================================================
# sx-ctl private overlay helper
#
# Internal helper loaded through:
#   sx-ctl private <command>
#
# Default private overlay:
#   ~/.config/sx-ctl/overlays/private
#
# This helper does not install dependencies.
# ============================================================

SX_PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

sx_private_err() {
  printf '%s\n' "sx-ctl private: $*" >&2
}

sx_private_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sx_private_require_cmd() {
  cmd=$1

  if ! sx_private_have_cmd "$cmd"; then
    sx_private_err "Required command not found: $cmd"
    return 1
  fi
}

sx_private_usage() {
  cat <<'EOF'
SX-CTL-PRIVATE(1)          User Commands          SX-CTL-PRIVATE(1)

NAME
    sx-ctl private - manage the optional sx-ctl private overlay

SYNOPSIS
    sx-ctl private status
    sx-ctl private init-local
    sx-ctl private clone <git-ssh-url>
    sx-ctl private pull
    sx-ctl private remove
    sx-ctl private -h

DESCRIPTION
    sx-ctl private manages the optional local private overlay.

    The default private overlay path is:

        ~/.config/sx-ctl/overlays/private

    Private tools are loaded by sx-ctl when this file exists:

        ~/.config/sx-ctl/overlays/private/manifest.txt

    Private scripts are executed locally from the private overlay directory.

COMMANDS
    status
        Show the current private overlay status.

    init-local
        Create a local private overlay without connecting it to Git.

    clone <git-ssh-url>
        Clone an existing private Git repository into the private overlay path.
        Missing sx-ctl overlay files are created after cloning.

    pull
        Run git pull --ff-only inside the private overlay.

    remove
        Remove the local private overlay directory after confirmation.

    -h, help, --help
        Show this help text.

ENVIRONMENT
    SX_PRIVATE_ROOT
        Override the private overlay directory.

EXAMPLES
    sx-ctl private status

    sx-ctl private init-local

    sx-ctl private clone git@github.com:Peppeppa/sx-ctl-private.git

    sx-ctl private pull

    sx-ctl private remove

NOTES
    This helper does not install git or configure SSH.

    Creating a GitHub repository is intentionally not handled here. Create the
    private repository in GitHub first, then clone it with:

        sx-ctl private clone <git-ssh-url>

SX-CTL-PRIVATE(1)          User Commands          SX-CTL-PRIVATE(1)
EOF
}

sx_private_parent_dir() {
  path=$1
  parent=${path%/*}

  if [ "$parent" = "$path" ]; then
    parent=.
  fi

  printf '%s\n' "$parent"
}

sx_private_is_empty_dir() {
  dir=$1

  if [ ! -d "$dir" ]; then
    return 1
  fi

  # POSIX-safe emptiness check.
  # Finds one entry and stops.
  set -- "$dir"/*
  if [ "$1" = "$dir/*" ]; then
    return 0
  fi

  return 1
}

sx_private_write_default_files() {
  mkdir -p "$SX_PRIVATE_ROOT/scripts/personal"
  mkdir -p "$SX_PRIVATE_ROOT/templates"

  if [ ! -f "$SX_PRIVATE_ROOT/manifest.txt" ]; then
    cat >"$SX_PRIVATE_ROOT/manifest.txt" <<'EOF'
id|source|category|label|path|description|shell|deps|risk
private.hello|private|personal|Private Hello|scripts/personal/hello.sh|Ein privates Beispielscript|sh|sh|low
EOF
  fi

  if [ ! -f "$SX_PRIVATE_ROOT/env" ]; then
    cat >"$SX_PRIVATE_ROOT/env" <<'EOF'
# sx-ctl private environment
# This file is not loaded by sx-ctl automatically.
# Private scripts may source it explicitly if needed.

SX_HOME_CITY="Berlin"
SX_COUNTRY="Germany"
SX_WEATHER_UNITS="metric"
EOF
    chmod 600 "$SX_PRIVATE_ROOT/env" 2>/dev/null || true
  fi

  if [ ! -f "$SX_PRIVATE_ROOT/scripts/personal/hello.sh" ]; then
    cat >"$SX_PRIVATE_ROOT/scripts/personal/hello.sh" <<'EOF'
#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl private script
# ID:          private.hello
# Name:        Private Hello
# Description: Ein privates Beispielscript
# Dependencies: sh
# Risk:        low
# ============================================================

ENV_FILE="${SX_PRIVATE_ENV:-$HOME/.config/sx-ctl/overlays/private/env}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

main() {
  name="${1:-private sx-ctl}"

  echo "Hello from $name!"
  echo "Private overlay is working."

  if [ -n "${SX_HOME_CITY:-}" ]; then
    echo "Configured city: $SX_HOME_CITY"
  fi
}

main "$@"
EOF
    chmod +x "$SX_PRIVATE_ROOT/scripts/personal/hello.sh"
  fi

  if [ ! -f "$SX_PRIVATE_ROOT/README.md" ]; then
    cat >"$SX_PRIVATE_ROOT/README.md" <<'EOF'
# sx-ctl private overlay

This repository contains private sx-ctl scripts.

sx-ctl loads this overlay when manifest.txt exists.

Default location:

    ~/.config/sx-ctl/overlays/private

Useful commands:

    sx-ctl -la
    sx-ctl private.hello
    sx-ctl private status
    sx-ctl private pull
EOF
  fi
}

sx_private_status() {
  printf '%s\n' "Private overlay status"
  printf '%s\n' "======================"
  printf '\n'
  printf 'Root:      %s\n' "$SX_PRIVATE_ROOT"

  if [ -d "$SX_PRIVATE_ROOT" ]; then
    printf '%s\n' "Exists:    yes"
  else
    printf '%s\n' "Exists:    no"
    return 0
  fi

  if [ -f "$SX_PRIVATE_ROOT/manifest.txt" ]; then
    printf '%s\n' "Manifest:  yes"
  else
    printf '%s\n' "Manifest:  no"
  fi

  if [ -d "$SX_PRIVATE_ROOT/.git" ]; then
    printf '%s\n' "Git repo:  yes"

    if sx_private_have_cmd git; then
      (
        cd "$SX_PRIVATE_ROOT"

        remote=$(git remote get-url origin 2>/dev/null || true)
        branch=$(git branch --show-current 2>/dev/null || true)

        if [ -n "$remote" ]; then
          printf 'Remote:    %s\n' "$remote"
        fi

        if [ -n "$branch" ]; then
          printf 'Branch:    %s\n' "$branch"
        fi

        if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
          printf '%s\n' "Changes:   clean"
        else
          printf '%s\n' "Changes:   uncommitted"
        fi
      )
    fi
  else
    printf '%s\n' "Git repo:  no"
  fi
}

sx_private_init_local() {
  if [ -e "$SX_PRIVATE_ROOT" ] && [ ! -d "$SX_PRIVATE_ROOT" ]; then
    sx_private_err "Path exists but is not a directory:"
    sx_private_err "  $SX_PRIVATE_ROOT"
    return 1
  fi

  sx_private_write_default_files

  printf '%s\n' "Private overlay initialized:"
  printf '%s\n' "  $SX_PRIVATE_ROOT"
  printf '\n'
  printf '%s\n' "Test with:"
  printf '%s\n' "  sx-ctl -la"
  printf '%s\n' "  sx-ctl private.hello"
}

sx_private_clone() {
  repo_url=${1:-}

  if [ -z "$repo_url" ]; then
    sx_private_err "Missing Git SSH URL."
    sx_private_err "Usage: sx-ctl private clone <git-ssh-url>"
    return 1
  fi

  sx_private_require_cmd git || return 1

  if [ -e "$SX_PRIVATE_ROOT" ]; then
    sx_private_err "Private overlay path already exists:"
    sx_private_err "  $SX_PRIVATE_ROOT"
    sx_private_err "Remove it first or use a different SX_PRIVATE_ROOT."
    return 1
  fi

  parent=$(sx_private_parent_dir "$SX_PRIVATE_ROOT")
  mkdir -p "$parent"

  git clone "$repo_url" "$SX_PRIVATE_ROOT"

  sx_private_write_default_files

  printf '%s\n' "Private overlay cloned and initialized:"
  printf '%s\n' "  $SX_PRIVATE_ROOT"
  printf '\n'

  if [ -d "$SX_PRIVATE_ROOT/.git" ]; then
    (
      cd "$SX_PRIVATE_ROOT"

      if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
        printf '%s\n' "No new files were created."
      else
        printf '%s\n' "Default sx-ctl overlay files were created."
        printf '%s\n' "Review them, then commit and push:"
        printf '\n'
        printf '%s\n' "  cd \"$SX_PRIVATE_ROOT\""
        printf '%s\n' "  git status"
        printf '%s\n' "  git add ."
        printf '%s\n' "  git commit -m \"Initialize sx-ctl private overlay\""
        printf '%s\n' "  git push"
      fi
    )
  fi

  printf '\n'
  printf '%s\n' "Test with:"
  printf '%s\n' "  sx-ctl -la"
  printf '%s\n' "  sx-ctl private.hello"
}

sx_private_pull() {
  sx_private_require_cmd git || return 1

  if [ ! -d "$SX_PRIVATE_ROOT" ]; then
    sx_private_err "Private overlay does not exist:"
    sx_private_err "  $SX_PRIVATE_ROOT"
    return 1
  fi

  if [ ! -d "$SX_PRIVATE_ROOT/.git" ]; then
    sx_private_err "Private overlay is not a Git repository:"
    sx_private_err "  $SX_PRIVATE_ROOT"
    return 1
  fi

  (
    cd "$SX_PRIVATE_ROOT"
    git pull --ff-only
  )
}

sx_private_remove() {
  if [ ! -e "$SX_PRIVATE_ROOT" ]; then
    printf '%s\n' "Private overlay does not exist:"
    printf '%s\n' "  $SX_PRIVATE_ROOT"
    return 0
  fi

  if [ ! -d "$SX_PRIVATE_ROOT" ]; then
    sx_private_err "Private overlay path exists but is not a directory:"
    sx_private_err "  $SX_PRIVATE_ROOT"
    return 1
  fi

  printf '%s\n' "This will remove the local private overlay:"
  printf '%s\n' "  $SX_PRIVATE_ROOT"
  printf '\n'
  printf '%s\n' "This does not delete the remote GitHub repository."
  printf '\n'
  printf '%s' "Type 'yes' to continue: "

  IFS= read -r answer || return 1

  if [ "$answer" != "yes" ]; then
    printf '%s\n' "Aborted."
    return 0
  fi

  rm -rf "$SX_PRIVATE_ROOT"

  printf '%s\n' "Private overlay removed:"
  printf '%s\n' "  $SX_PRIVATE_ROOT"
}

sx_private_main() {
  cmd=${1:-}

  case "$cmd" in
  "" | -h | --help | help)
    sx_private_usage
    ;;
  status)
    sx_private_status
    ;;
  init-local)
    sx_private_init_local
    ;;
  clone)
    shift
    sx_private_clone "$@"
    ;;
  pull)
    sx_private_pull
    ;;
  remove)
    sx_private_remove
    ;;
  *)
    sx_private_err "Unknown command: $cmd"
    sx_private_err "Run: sx-ctl private -h"
    return 1
    ;;
  esac
}

sx_private_main "$@"
