#!/usr/bin/env sh
# shellcheck shell=sh

# ============================================================
# sx-ctl core
# Shared core logic for sx-ctl frontends.
#
# This file intentionally contains no interactive UI logic.
# It is meant to be sourced by sx-ctl-basic.sh, sx-ctl-fzf.sh
# or sx-ctl.sh.
# ============================================================

# Public raw GitHub base URL.
# Can be overridden for tests.
SX_RAW_BASE="${SX_RAW_BASE:-https://raw.githubusercontent.com/Peppeppa/sx-ctl/main}"

# Optional local repo root for development/testing.
# Example:
#   SX_LOCAL_ROOT="$PWD" . ./lib/core.sh
SX_LOCAL_ROOT="${SX_LOCAL_ROOT:-}"

# Default private overlay root.
SX_PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

SX_MANIFEST_HEADER="id|source|category|label|path|description|shell|deps|risk"

sx_err() {
  printf '%s\n' "sx-ctl: $*" >&2
}

sx_die() {
  sx_err "$@"
  return 1
}

sx_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sx_fetch_url() {
  url=$1

  if sx_have_cmd curl; then
    curl -fsSL "$url"
    return $?
  fi

  if sx_have_cmd wget; then
    wget -qO- "$url"
    return $?
  fi

  sx_die "Neither curl nor wget is available."
}

sx_public_url() {
  path=$1

  case "$path" in
  /*)
    path=${path#/}
    ;;
  esac

  printf '%s/%s\n' "$SX_RAW_BASE" "$path"
}

sx_read_public_file() {
  path=$1

  case "$path" in
  /*)
    path=${path#/}
    ;;
  esac

  if [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/$path" ]; then
    cat "$SX_LOCAL_ROOT/$path"
    return $?
  fi

  sx_fetch_url "$(sx_public_url "$path")"
}

sx_private_root() {
  printf '%s\n' "$SX_PRIVATE_ROOT"
}

sx_manifest_public() {
  sx_read_public_file "manifest.txt"
}

sx_manifest_private() {
  private_manifest="$(sx_private_root)/manifest.txt"

  if [ -f "$private_manifest" ]; then
    cat "$private_manifest"
  fi
}

sx_manifest_all() {
  printed_header=0

  sx_manifest_public | while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue

    if [ "$printed_header" -eq 0 ]; then
      printf '%s\n' "$line"
      printed_header=1
      continue
    fi

    printf '%s\n' "$line"
  done

  private_manifest="$(sx_private_root)/manifest.txt"

  if [ -f "$private_manifest" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [ -z "$line" ] && continue
      [ "$line" = "$SX_MANIFEST_HEADER" ] && continue
      printf '%s\n' "$line"
    done <"$private_manifest"
  fi
}

sx_is_header() {
  [ "$1" = "$SX_MANIFEST_HEADER" ]
}

sx_validate_manifest_entry() {
  entry=$1

  old_ifs=$IFS
  IFS='|'
  # shellcheck disable=SC2086
  set -- $entry
  IFS=$old_ifs

  field_count=$#

  if [ "$field_count" -ne 9 ]; then
    sx_die "Invalid manifest entry field count: $entry"
    return 1
  fi

  id=$1
  source=$2
  category=$3
  label=$4
  path=$5
  description=$6
  shell_name=$7
  deps=$8
  risk=$9

  [ -n "$id" ] || sx_die "Manifest entry has empty id: $entry" || return 1
  [ -n "$source" ] || sx_die "Manifest entry has empty source: $entry" || return 1
  [ -n "$category" ] || sx_die "Manifest entry has empty category: $entry" || return 1
  [ -n "$label" ] || sx_die "Manifest entry has empty label: $entry" || return 1
  [ -n "$path" ] || sx_die "Manifest entry has empty path: $entry" || return 1
  [ -n "$description" ] || sx_die "Manifest entry has empty description: $entry" || return 1
  [ -n "$shell_name" ] || sx_die "Manifest entry has empty shell: $entry" || return 1
  [ -n "$risk" ] || sx_die "Manifest entry has empty risk: $entry" || return 1

  case "$source" in
  public | private)
    ;;
  *)
    sx_die "Unsupported source '$source' for tool '$id'."
    return 1
    ;;
  esac

  case "$source:$id" in
  private:private.*)
    ;;
  private:*)
    sx_die "Private tool id '$id' must start with 'private.'."
    return 1
    ;;
  public:private.*)
    sx_die "Public tool id '$id' must not start with 'private.'."
    return 1
    ;;
  public:*)
    ;;
  esac

  case "$shell_name" in
  sh | bash)
    ;;
  *)
    sx_die "Unsupported shell '$shell_name' for tool '$id'."
    return 1
    ;;
  esac

  case "$risk" in
  low | medium | high)
    ;;
  *)
    sx_die "Unsupported risk '$risk' for tool '$id'."
    return 1
    ;;
  esac

  case "$path" in
  /*)
    sx_die "Script path for tool '$id' must be relative."
    return 1
    ;;
  *../* | ../* | *'/..')
    sx_die "Script path for tool '$id' must not contain '..'."
    return 1
    ;;
  esac

  # deps may be empty in future manifests, so it is intentionally not rejected.
  return 0
}

sx_field() {
  entry=$1
  number=$2

  printf '%s\n' "$entry" | cut -d '|' -f "$number"
}

sx_entry_id() {
  sx_field "$1" 1
}

sx_entry_source() {
  sx_field "$1" 2
}

sx_entry_category() {
  sx_field "$1" 3
}

sx_entry_label() {
  sx_field "$1" 4
}

sx_entry_path() {
  sx_field "$1" 5
}

sx_entry_description() {
  sx_field "$1" 6
}

sx_entry_shell() {
  sx_field "$1" 7
}

sx_entry_deps() {
  sx_field "$1" 8
}

sx_entry_risk() {
  sx_field "$1" 9
}

sx_list() {
  sx_check_duplicate_ids || return 1

  sx_manifest_all | while IFS= read -r entry || [ -n "$entry" ]; do
    [ -z "$entry" ] && continue
    sx_is_header "$entry" && continue

    if ! sx_validate_manifest_entry "$entry"; then
      return 1
    fi

    id=$(sx_entry_id "$entry")
    source=$(sx_entry_source "$entry")
    category=$(sx_entry_category "$entry")
    label=$(sx_entry_label "$entry")
    risk=$(sx_entry_risk "$entry")
    description=$(sx_entry_description "$entry")

    printf '%s|%s|%s|%s|%s|%s\n' \
      "$id" \
      "$source" \
      "$category" \
      "$label" \
      "$risk" \
      "$description"
  done
}

sx_check_duplicate_ids() {
  ids_file=$(sx_make_temp_file) || {
    sx_err "Could not create temporary file."
    return 1
  }

  sx_manifest_all | while IFS= read -r entry || [ -n "$entry" ]; do
    [ -z "$entry" ] && continue
    sx_is_header "$entry" && continue

    if ! sx_validate_manifest_entry "$entry"; then
      rm -f "$ids_file"
      return 1
    fi

    sx_entry_id "$entry"
  done >"$ids_file"

  duplicates=$(sort "$ids_file" | uniq -d)

  rm -f "$ids_file"

  if [ -n "$duplicates" ]; then
    sx_err "Duplicate tool IDs found:"
    printf '%s\n' "$duplicates" | while IFS= read -r duplicate_id; do
      [ -n "$duplicate_id" ] || continue
      sx_err "  $duplicate_id"
    done
    sx_err "Tool IDs must be globally unique."
    sx_err "Use a namespace such as 'private.admin.help' for private tools."
    return 1
  fi

  return 0
}

sx_find_entry() {
  sx_check_duplicate_ids || return 1

  wanted_id=$1

  sx_manifest_all | while IFS= read -r entry || [ -n "$entry" ]; do
    [ -z "$entry" ] && continue
    sx_is_header "$entry" && continue

    if ! sx_validate_manifest_entry "$entry"; then
      return 1
    fi

    id=$(sx_entry_id "$entry")

    if [ "$id" = "$wanted_id" ]; then
      printf '%s\n' "$entry"
      return 0
    fi
  done
}

sx_require_shell() {
  shell_name=$1

  if ! sx_have_cmd "$shell_name"; then
    sx_die "Required shell '$shell_name' is not available."
    return 1
  fi
}

sx_make_temp_file() {
  if sx_have_cmd mktemp; then
    mktemp "${TMPDIR:-/tmp}/sx-ctl.XXXXXX"
    return $?
  fi

  tmp="${TMPDIR:-/tmp}/sx-ctl.$$"
  : >"$tmp" || return 1
  printf '%s\n' "$tmp"
}

sx_run_public() {
  path=$1
  shell_name=$2
  shift 2

  sx_require_shell "$shell_name" || return 1

  tmp_file=$(sx_make_temp_file) || {
    sx_err "Could not create temporary file."
    return 1
  }

  if ! sx_read_public_file "$path" >"$tmp_file"; then
    rm -f "$tmp_file"
    sx_err "Could not fetch public script: $path"
    return 1
  fi

  chmod +x "$tmp_file" 2>/dev/null || true

  "$shell_name" "$tmp_file" "$@"
  status=$?

  rm -f "$tmp_file"

  return "$status"
}

sx_run_private() {
  path=$1
  shell_name=$2
  shift 2

  sx_require_shell "$shell_name" || return 1

  case "$path" in
  /*)
    sx_die "Private script path must be relative: $path"
    return 1
    ;;
  *../* | ../* | *'/..')
    sx_die "Private script path must not contain '..': $path"
    return 1
    ;;
  esac

  script_path="$(sx_private_root)/$path"

  if [ ! -f "$script_path" ]; then
    sx_die "Private script not found: $script_path"
    return 1
  fi

  "$shell_name" "$script_path" "$@"
}

sx_run() {
  tool_id=$1
  shift || true

  entry=$(sx_find_entry "$tool_id")

  if [ -z "$entry" ]; then
    sx_die "Unknown tool id: $tool_id"
    return 1
  fi

  sx_validate_manifest_entry "$entry" || return 1

  source=$(sx_entry_source "$entry")
  path=$(sx_entry_path "$entry")
  shell_name=$(sx_entry_shell "$entry")

  case "$source" in
  public)
    sx_run_public "$path" "$shell_name" "$@"
    ;;
  private)
    sx_run_private "$path" "$shell_name" "$@"
    ;;
  *)
    sx_die "Unsupported source: $source"
    return 1
    ;;
  esac
}
