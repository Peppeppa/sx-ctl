#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl installer
#
# Installs a small wrapper to:
#   ~/.local/bin/sx-ctl
#
# The wrapper fetches the latest sx-ctl.sh from the public repo
# whenever sx-ctl is started.
# ============================================================

SX_RAW_BASE="${SX_RAW_BASE:-https://raw.githubusercontent.com/Peppeppa/sx-ctl/main}"
SX_INSTALL_DIR="${SX_INSTALL_DIR:-$HOME/.local/bin}"
SX_INSTALL_BIN="${SX_INSTALL_BIN:-$SX_INSTALL_DIR/sx-ctl}"

sx_install_err() {
  printf '%s\n' "sx-ctl install: $*" >&2
}

sx_install_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sx_install_usage() {
  cat <<'EOF'
sx-ctl installer

Usage:
  sh install.sh
  sh install.sh --help

Environment:
  SX_RAW_BASE       Override public raw GitHub base URL
  SX_INSTALL_DIR    Override install directory
  SX_INSTALL_BIN    Override installed binary path

Default:
  ~/.local/bin/sx-ctl
EOF
}

sx_install_check_fetcher() {
  if sx_install_have_cmd curl || sx_install_have_cmd wget; then
    return 0
  fi

  sx_install_err "Neither curl nor wget is available."
  sx_install_err "Please install curl or wget and run the installer again."
  return 1
}

sx_install_write_wrapper() {
  mkdir -p "$SX_INSTALL_DIR"

  cat >"$SX_INSTALL_BIN" <<EOF
#!/usr/bin/env sh
set -eu

SX_RAW_BASE="\${SX_RAW_BASE:-$SX_RAW_BASE}"

sx_ctl_err() {
  printf '%s\\n' "sx-ctl: \$*" >&2
}

sx_ctl_have_cmd() {
  command -v "\$1" >/dev/null 2>&1
}

sx_ctl_fetch_url() {
  url=\$1

  if sx_ctl_have_cmd curl; then
    curl -fsSL "\$url"
    return \$?
  fi

  if sx_ctl_have_cmd wget; then
    wget -qO- "\$url"
    return \$?
  fi

  sx_ctl_err "Neither curl nor wget is available."
  return 1
}

sx_ctl_make_temp_file() {
  if sx_ctl_have_cmd mktemp; then
    mktemp "\${TMPDIR:-/tmp}/sx-ctl.XXXXXX"
    return \$?
  fi

  tmp="\${TMPDIR:-/tmp}/sx-ctl.\$\$"
  : > "\$tmp" || return 1
  printf '%s\\n' "\$tmp"
}

tmp_file=\$(sx_ctl_make_temp_file) || {
  sx_ctl_err "Could not create temporary file."
  exit 1
}

if ! sx_ctl_fetch_url "\$SX_RAW_BASE/sx-ctl.sh" > "\$tmp_file"; then
  rm -f "\$tmp_file"
  sx_ctl_err "Could not fetch sx-ctl.sh."
  exit 1
fi

sh "\$tmp_file" "\$@"
status=\$?

rm -f "\$tmp_file"

exit "\$status"
EOF

  chmod +x "$SX_INSTALL_BIN"
}

sx_install_print_path_notice() {
  case ":${PATH:-}:" in
  *":$SX_INSTALL_DIR:"*)
    return 0
    ;;
  esac

  cat <<EOF

Hinweis:
  $SX_INSTALL_DIR ist aktuell nicht in deinem PATH.

Füge z. B. diese Zeile zu deiner Shell-Konfiguration hinzu:

  export PATH="\$HOME/.local/bin:\$PATH"

Je nach Shell ist das z. B. eine dieser Dateien:

  ~/.profile
  ~/.shrc
  ~/.bashrc
  ~/.zshrc

Danach Terminal neu starten oder die Datei neu laden.
EOF
}

sx_install_main() {
  case "${1:-}" in
  --help | -h | help)
    sx_install_usage
    return 0
    ;;
  "")
    ;;
  *)
    sx_install_err "Unknown argument: $1"
    sx_install_err "Run: sh install.sh --help"
    return 1
    ;;
  esac

  sx_install_check_fetcher
  sx_install_write_wrapper

  printf '%s\n' "sx-ctl installed successfully:"
  printf '%s\n' "  $SX_INSTALL_BIN"

  sx_install_print_path_notice

  printf '\n'
  printf '%s\n' "Test with:"
  printf '%s\n' "  sx-ctl version"
  printf '%s\n' "  sx-ctl list"
}

sx_install_main "$@"
