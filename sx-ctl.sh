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
SX-CTL(1)                  User Commands                  SX-CTL(1)

NAME
    sx-ctl - lightweight command runner for repository-hosted shell scripts

SYNOPSIS
    sx-ctl
    sx-ctl -ls
    sx-ctl -la
    sx-ctl -r <tool-id> [args...]
    sx-ctl <tool-id> [args...]
    sx-ctl -b [args...]
    sx-ctl -f [args...]
    sx-ctl -h
    sx-ctl -v
    sx-ctl private <command> [args...]

DESCRIPTION
    sx-ctl is a lightweight, modular command-line framework for running
    shell scripts from a GitHub repository without cloning or manually
    pulling the public repository.

    By default, sx-ctl uses the basic frontend. The fzf frontend is planned
    as an optional enhanced interface.

OPTIONS
    -ls
        List available tools as a compact tree grouped by source and category.

    -la
        List all available tools as a detailed tree with label, risk and description.

    -r <tool-id> [args...]
        Run a tool by ID and pass optional arguments to the script.

    -b [args...]
        Use the basic frontend. This is the default mode.

    -f [args...]
        Use the fzf frontend. This mode is planned but not implemented yet.

    -h
        Show this help text.

    -v
        Show the sx-ctl version.

COMMANDS
    list, ls
        Compatibility aliases for -ls.

    listall, la
        Compatibility aliases for -la.

    run
        Compatibility alias for -r.

    help, --help
        Compatibility aliases for -h.

    version, --version
        Compatibility aliases for -v.

    --basic
        Compatibility alias for -b.

    --fzf
        Compatibility alias for -f.

    private
        Manage the optional private overlay.

EXAMPLES
    sx-ctl
        Start the interactive category-based menu.

    sx-ctl -ls
        Show only available tool IDs.

    sx-ctl -la
        Show all tools grouped by source and category.

    sx-ctl system.info
        Run the tool with ID system.info.

    sx-ctl misc.hello Peppeppa
        Run misc.hello and pass "Peppeppa" as first argument.

    sx-ctl -r misc.hello Peppeppa
        Run misc.hello using the explicit run flag.

    sx-ctl private status
        Show private overlay status.

    sx-ctl private clone git@github.com:Peppeppa/sx-ctl-private.git
        Clone and initialize the private overlay.

FILES
    manifest.txt
        Public tool manifest.

    lib/core.sh
        Shared core logic.

    sx-ctl-basic.sh
        Minimal frontend without additional dependencies.

    sx-ctl-fzf.sh
        Optional fzf frontend, planned for a later phase.

PRIVATE OVERLAY
    If this file exists, private tools are loaded in addition to public tools:

        ~/.config/sx-ctl/overlays/private/manifest.txt

    Private scripts are executed locally from:

        ~/.config/sx-ctl/overlays/private/

    Private script paths must be relative and must not contain "..".

EXIT STATUS
    0
        Command completed successfully.

    non-zero
        An error occurred, the tool was not found, or the selected script
        returned a non-zero exit code.

SEE ALSO
    sh(1), bash(1), curl(1), wget(1), fzf(1)

SX-CTL(1)                  User Commands                  SX-CTL(1)
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

sx_main_run_private_alias() {
  private_cmd=${1:-}

  case "$private_cmd" in
  "" | -h | --help | help)
    cat <<'EOF'
SX-CTL-PRIVATE(1)          User Commands          SX-CTL-PRIVATE(1)

NAME
    sx-ctl private - compatibility aliases for private overlay admin tools

SYNOPSIS
    sx-ctl private status
    sx-ctl private init
    sx-ctl private init-local
    sx-ctl private clone <git-url>
    sx-ctl private pull
    sx-ctl private remove

DESCRIPTION
    These commands are compatibility aliases.

    The canonical commands are:

        sx-ctl admin.private-status
        sx-ctl admin.private-init
        sx-ctl admin.private-clone <git-url>
        sx-ctl admin.private-pull
        sx-ctl admin.private-remove

EOF
    return 0
    ;;
  status)
    shift
    sx_main_load_frontend "basic" admin.private-status "$@"
    ;;
  init | init-local)
    shift
    sx_main_load_frontend "basic" admin.private-init "$@"
    ;;
  clone)
    shift
    sx_main_load_frontend "basic" admin.private-clone "$@"
    ;;
  pull)
    shift
    sx_main_load_frontend "basic" admin.private-pull "$@"
    ;;
  remove)
    shift
    sx_main_load_frontend "basic" admin.private-remove "$@"
    ;;
  *)
    sx_main_err "Unknown private command: $private_cmd"
    sx_main_err "Run: sx-ctl private -h"
    return 1
    ;;
  esac
}

sx_main_parse_and_run() {
  frontend="basic"

  case "${1:-}" in
  -h | --help | help)
    sx_main_usage
    return 0
    ;;
  -v | --version | version)
    sx_main_version
    return 0
    ;;
  private)
    shift
    sx_main_run_private_alias "$@"
    return $?
    ;;
  -b | --basic)
    frontend="basic"
    shift
    ;;
  -f | --fzf)
    frontend="fzf"
    shift
    ;;
  esac

  if [ "$frontend" = "fzf" ]; then
    sx_main_err "The fzf frontend is not implemented yet."
    sx_main_err "Use '-b' or omit the mode option for now."
    return 1
  fi

  sx_main_load_frontend "$frontend" "$@"
}

sx_main_parse_and_run "$@"
