#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.private-init
# Name:        Private Overlay initialisieren
# Description: Erstellt ein lokales privates Overlay mit Beispielstruktur
# Dependencies: sh
# Risk:        medium
# ============================================================

PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

err() {
  printf '%s\n' "admin.private-init: $*" >&2
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

Structure:

    .
    ├── env
    ├── manifest.txt
    ├── scripts/
    │   └── personal/
    │       └── hello.sh
    └── templates/

Useful commands:

    sx-ctl -la
    sx-ctl private.personal.hello
    sx-ctl admin.private-status
EOF_README
}

main() {
  if [ -e "$PRIVATE_ROOT" ] && [ ! -d "$PRIVATE_ROOT" ]; then
    err "Path exists but is not a directory:"
    err "  $PRIVATE_ROOT"
    return 1
  fi

  mkdir -p "$PRIVATE_ROOT/scripts/personal"
  mkdir -p "$PRIVATE_ROOT/templates"

  write_default_manifest
  write_default_env
  write_default_script
  write_default_readme

  echo "Private overlay initialized:"
  echo "  $PRIVATE_ROOT"
  echo
  echo "Created or verified:"
  echo "  manifest.txt"
  echo "  env"
  echo "  scripts/personal/hello.sh"
  echo "  templates/"
  echo "  README.md"
  echo
  echo "Test with:"
  echo "  sx-ctl -la"
  echo "  sx-ctl private.personal.hello"
  echo "  sx-ctl admin.private-status"
}

main "$@"
