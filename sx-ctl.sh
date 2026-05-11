#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl main entrypoint
#
# Selects and loads the requested frontend.
# Default frontend: basic
#
# This file must work when executed locally and when piped through:
#   curl -fsSL .../sx-ctl.sh | sh
# ============================================================

SX_CTL_VERSION="${SX_CTL_VERSION:-0.1.0}"
SX_RAW_BASE="${SX_RAW_BASE:-https://raw.githubusercontent.com/Peppeppa/sx-ctl/main}"

sx_main_err() {
  printf '%s\n' "sx-ctl: $*" >&2
}

sx_main_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sx_main_fetch_url() {
  url=$1

  if sx_main_have_cmd curl; then
    curl -fsSL "$url"
    return $?
  fi

  if sx_main_have_cmd wget; then
    wget -qO- "$url"
    return $?
  fi

  sx_main_err "Neither curl nor wget is available."
  return 1
}

sx_main_make_temp_file() {
  if sx_main_have_cmd mktemp; then
    mktemp "${TMPDIR:-/tmp}/sx-ctl-frontend.XXXXXX"
    return $?
  fi

  tmp="${TMPDIR:-/tmp}/sx-ctl-frontend.$$"
  : >"$tmp" || return 1
  printf '%s\n' "$tmp"
}

sx_main_script_dir() {
  # Best-effort script directory detection for normal local execution.
  # When this file is executed through "sh" from stdin, this will usually
  # not point to the repository. In that case the remote fallback is used.
  case "$0" in
  */*)
    dir=${0%/*}
    ;;
  *)
    dir=.
    ;;
  esac

  cd "$dir" 2>/dev/null && pwd
}

sx_main_usage() {
  cat <<'EOF'
sx-ctl

Usage:
  sx-ctl
  sx-ctl [--basic] list
  sx-ctl [--basic] run <tool-id> [args...]
  sx-ctl [--basic] <tool-id> [args...]
  sx-ctl --fzf [args...]
  sx-ctl help
  sx-ctl version

Examples:
  sx-ctl list
  sx-ctl system.info
  sx-ctl misc.hello Peppeppa
  sx-ctl run misc.hello Peppeppa
  sx-ctl --basic list
  sx-ctl --fzf

Modes:
  --basic     Use the basic frontend. This is the default.
  --fzf       Use the fzf frontend. Not implemented yet.

Commands:
  list        List available tools
  run         Run a tool by id
  help        Show this help
  version     Show version
EOF
}

sx_main_version() {
  printf '%s\n' "sx-ctl $SX_CTL_VERSION"
}

sx_main_load_frontend() {
  frontend=$1
  shift

  case "$frontend" in
  basic)
    frontend_file="sx-ctl-basic.sh"
    ;;
  fzf)
    frontend_file="sx-ctl-fzf.sh"
    ;;
  *)
    sx_main_err "Unknown frontend: $frontend"
    return 1
    ;;
  esac

  # 1. Prefer explicitly configured local root.
  if [ -n "${SX_LOCAL_ROOT:-}" ] && [ -f "$SX_LOCAL_ROOT/$frontend_file" ]; then
    # shellcheck disable=SC1090
    . "$SX_LOCAL_ROOT/$frontend_file"
    return $?
  fi

  # 2. Prefer frontend next to this script in a local checkout.
  script_dir=$(sx_main_script_dir)

  if [ -f "$script_dir/$frontend_file" ]; then
    SX_LOCAL_ROOT="${SX_LOCAL_ROOT:-$script_dir}"
    export SX_LOCAL_ROOT

    # shellcheck disable=SC1090
    . "$script_dir/$frontend_file"
    return $?
  fi

  # 3. Fallback: fetch frontend from public raw GitHub repo.
  tmp_frontend=$(sx_main_make_temp_file) || {
    sx_main_err "Could not create temporary file."
    return 1
  }

  if ! sx_main_fetch_url "$SX_RAW_BASE/$frontend_file" >"$tmp_frontend"; then
    rm -f "$tmp_frontend"
    sx_main_err "Could not load frontend: $frontend_file"
    return 1
  fi

  # shellcheck disable=SC1090
  . "$tmp_frontend"
  status=$?

  rm -f "$tmp_frontend"

  return "$status"
}

sx_main_parse_and_run() {
  frontend="basic"

  case "${1:-}" in
  help | --help | -h)
    sx_main_usage
    return 0
    ;;
  version | --version | -v)
    sx_main_version
    return 0
    ;;
  --basic)
    frontend="basic"
    shift
    ;;
  --fzf)
    frontend="fzf"
    shift
    ;;
  esac

  if [ "$frontend" = "fzf" ]; then
    sx_main_err "The fzf frontend is not implemented yet."
    sx_main_err "Use '--basic' or omit the mode option for now."
    return 1
  fi

  sx_main_load_frontend "$frontend" "$@"
}

sx_main_parse_and_run "$@"
