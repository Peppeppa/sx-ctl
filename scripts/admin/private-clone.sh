#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.private-clone
# Name:        Private Overlay klonen
# Description: Klont ein bestehendes privates Git-Repo als Overlay
# Dependencies: sh, git
# Risk:        medium
# ============================================================

PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

err() {
  printf '%s\n' "admin.private-clone: $*" >&2
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

parent_dir() {
  path=$1
  parent=${path%/*}

  if [ "$parent" = "$path" ]; then
    parent=.
  fi

  printf '%s\n' "$parent"
}

write_default_manifest() {
  manifest_file="$PRIVATE_ROOT/manifest.txt"

  if [ -f "$manifest_file" ]; then
    return 0
  fi

  cat >"$manifest_file" <<'EOF_MANIFEST'
id|source|category|label|path|description|shell|deps|risk
private.personal.hello|private|personal|Private Hello|scripts/personal/hello.sh|Ein privates Beispielscript|sh|sh|low
EOF_MANIFEST
}

write_default_env() {
  env_file="$PRIVATE_ROOT/env"

  if [ -f "$env_file" ]; then
    return 0
  fi

  cat >"$env_file" <<'EOF_ENV'
# sx-ctl private environment
# This file is not loaded by sx-ctl automatically.
# Private scripts may source it explicitly if needed.

SX_HOME_CITY="Berlin"
SX_COUNTRY="Germany"
SX_WEATHER_UNITS="metric"
EOF_ENV

  chmod 600 "$env_file" 2>/dev/null || true
}

write_default_script() {
  script_file="$PRIVATE_ROOT/scripts/personal/hello.sh"

  if [ -f "$script_file" ]; then
    return 0
  fi

  mkdir -p "$PRIVATE_ROOT/scripts/personal"

  cat >"$script_file" <<'EOF_SCRIPT'
#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl private script
# ID:          private.personal.hello
# Name:        Private Hello
# Description: Ein privates Beispielscript
# Dependencies: sh
# Risk:        low
# ============================================================

ENV_FILE="${SX_PRIVATE_ENV:-$HOME/.config/sx-ctl/overlays/private/env}"

if [ -f "$ENV_FILE" ]; then
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
EOF_SCRIPT

  chmod +x "$script_file"
}

write_default_readme() {
  readme_file="$PRIVATE_ROOT/README.md"

  if [ -f "$readme_file" ]; then
    return 0
  fi

  cat >"$readme_file" <<'EOF_README'
# sx-ctl private overlay

This repository contains private sx-ctl scripts.

sx-ctl loads this overlay when manifest.txt exists.

Default location:

    ~/.config/sx-ctl/overlays/private

Useful commands:

    sx-ctl -la
    sx-ctl private.personal.hello
    sx-ctl admin.private-status
    sx-ctl admin.private-pull
EOF_README
}

initialize_overlay_files() {
  mkdir -p "$PRIVATE_ROOT/scripts/personal"
  mkdir -p "$PRIVATE_ROOT/templates"

  write_default_manifest
  write_default_env
  write_default_script
  write_default_readme
}

main() {
  repo_url=${1:-}

  if [ -z "$repo_url" ]; then
    err "Missing Git repository URL."
    err "Usage: sx-ctl admin.private-clone <git-url>"
    err "Example: sx-ctl admin.private-clone git@github.com:USER/sx-ctl-private.git"
    return 1
  fi

  require_cmd git || return 1

  if [ -e "$PRIVATE_ROOT" ]; then
    err "Private overlay path already exists:"
    err "  $PRIVATE_ROOT"
    err "Remove it first or use a different SX_PRIVATE_ROOT."
    return 1
  fi

  parent=$(parent_dir "$PRIVATE_ROOT")
  mkdir -p "$parent"

  git clone "$repo_url" "$PRIVATE_ROOT"

  initialize_overlay_files

  echo "Private overlay cloned and initialized:"
  echo "  $PRIVATE_ROOT"
  echo

  if [ -d "$PRIVATE_ROOT/.git" ]; then
    (
      cd "$PRIVATE_ROOT"

      if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
        echo "No default files had to be added."
      else
        echo "Default sx-ctl overlay files were created."
        echo
        echo "Review, commit and push them:"
        echo "  cd \"$PRIVATE_ROOT\""
        echo "  git status"
        echo "  git add ."
        echo "  git commit -m \"Initialize sx-ctl private overlay\""
        echo "  git push"
      fi
    )
  fi

  echo
  echo "Test with:"
  echo "  sx-ctl -la"
  echo "  sx-ctl private.personal.hello"
  echo "  sx-ctl admin.private-status"
}

main "$@"
