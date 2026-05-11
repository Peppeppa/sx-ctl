#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl basic frontend
#
# Minimal frontend without fzf, jq, git, Python or Node.
# Uses lib/core.sh for all non-UI logic.
# ============================================================

SX_CTL_VERSION="${SX_CTL_VERSION:-0.1.0}"
SX_RAW_BASE="${SX_RAW_BASE:-https://raw.githubusercontent.com/Peppeppa/sx-ctl/main}"

sx_basic_err() {
  printf '%s\n' "sx-ctl-basic: $*" >&2
}

sx_basic_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sx_basic_fetch_url() {
  url=$1

  if sx_basic_have_cmd curl; then
    curl -fsSL "$url"
    return $?
  fi

  if sx_basic_have_cmd wget; then
    wget -qO- "$url"
    return $?
  fi

  sx_basic_err "Neither curl nor wget is available."
  return 1
}

sx_basic_script_dir() {
  # Best-effort script directory detection for normal local execution.
  # This is intentionally simple and POSIX-compatible.
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

sx_basic_load_core() {
  # 1. Prefer explicitly configured local root.
  if [ -n "${SX_LOCAL_ROOT:-}" ] && [ -f "$SX_LOCAL_ROOT/lib/core.sh" ]; then
    # shellcheck disable=SC1090
    . "$SX_LOCAL_ROOT/lib/core.sh"
    return 0
  fi

  # 2. Prefer core next to this script in a local checkout.
  script_dir=$(sx_basic_script_dir)

  if [ -f "$script_dir/lib/core.sh" ]; then
    SX_LOCAL_ROOT="${SX_LOCAL_ROOT:-$script_dir}"
    export SX_LOCAL_ROOT
    # shellcheck disable=SC1090
    . "$script_dir/lib/core.sh"
    return 0
  fi

  # 3. Fallback: fetch core from the public raw GitHub repo.
  tmp_core="${TMPDIR:-/tmp}/sx-ctl-core.$$"

  if ! sx_basic_fetch_url "$SX_RAW_BASE/lib/core.sh" >"$tmp_core"; then
    rm -f "$tmp_core"
    sx_basic_err "Could not load lib/core.sh."
    return 1
  fi

  # shellcheck disable=SC1090
  . "$tmp_core"
  rm -f "$tmp_core"

  return 0
}

sx_basic_usage() {
  cat <<'EOF'
sx-ctl-basic

Usage:
  sx-ctl-basic.sh
  sx-ctl-basic.sh list
  sx-ctl-basic.sh run <tool-id> [args...]
  sx-ctl-basic.sh <tool-id> [args...]
  sx-ctl-basic.sh help
  sx-ctl-basic.sh version

Examples:
  sx-ctl-basic.sh list
  sx-ctl-basic.sh system.info
  sx-ctl-basic.sh misc.hello Peppeppa
  sx-ctl-basic.sh run misc.hello Peppeppa

Commands:
  list       List available tools
  run        Run a tool by id
  help       Show this help
  version    Show version

Without arguments, sx-ctl-basic starts a category-based interactive menu.
EOF
}

sx_basic_version() {
  printf '%s\n' "sx-ctl-basic $SX_CTL_VERSION"
}

sx_basic_print_list() {
  list_file=$(sx_basic_make_temp_file) || {
    sx_basic_err "Could not create temporary file."
    return 1
  }

  sx_list >"$list_file"

  if [ ! -s "$list_file" ]; then
    rm -f "$list_file"
    sx_basic_err "No tools available."
    return 1
  fi

  printf '%s\n' "sx-ctl tools"

  sources=$(cut -d '|' -f 2 "$list_file" | sort -u)

  source_count=$(printf '%s\n' "$sources" | sed '/^$/d' | wc -l | tr -d ' ')

  source_index=0
  printf '%s\n' "$sources" | while IFS= read -r source; do
    [ -n "$source" ] || continue

    source_index=$((source_index + 1))

    if [ "$source_index" -eq "$source_count" ]; then
      source_prefix="└──"
      category_indent="    "
    else
      source_prefix="├──"
      category_indent="│   "
    fi

    printf '%s %s\n' "$source_prefix" "$source"

    categories=$(awk -F '|' -v wanted_source="$source" '
      $2 == wanted_source {
        print $3
      }
    ' "$list_file" | sort -u)

    category_count=$(printf '%s\n' "$categories" | sed '/^$/d' | wc -l | tr -d ' ')

    category_index=0
    printf '%s\n' "$categories" | while IFS= read -r category; do
      [ -n "$category" ] || continue

      category_index=$((category_index + 1))

      if [ "$category_index" -eq "$category_count" ]; then
        category_prefix="${category_indent}└──"
        tool_indent="${category_indent}    "
      else
        category_prefix="${category_indent}├──"
        tool_indent="${category_indent}│   "
      fi

      printf '%s %s\n' "$category_prefix" "$category"

      tools=$(awk -F '|' \
        -v wanted_source="$source" \
        -v wanted_category="$category" '
        $2 == wanted_source && $3 == wanted_category {
          print $1 "|" $4 "|" $5 "|" $6
        }
      ' "$list_file")

      tool_count=$(printf '%s\n' "$tools" | sed '/^$/d' | wc -l | tr -d ' ')

      tool_index=0
      printf '%s\n' "$tools" | while IFS='|' read -r id label risk description; do
        [ -n "$id" ] || continue

        tool_index=$((tool_index + 1))

        if [ "$tool_index" -eq "$tool_count" ]; then
          tool_prefix="${tool_indent}└──"
        else
          tool_prefix="${tool_indent}├──"
        fi

        printf '%s %s - %s [%s]\n' "$tool_prefix" "$id" "$label" "$risk"
        printf '%s    %s\n' "$tool_indent" "$description"
      done
    done
  done

  rm -f "$list_file"
}

sx_basic_prompt() {
  categories_file=$(sx_basic_make_temp_file) || {
    sx_basic_err "Could not create temporary file."
    return 1
  }

  tools_file=$(sx_basic_make_temp_file) || {
    rm -f "$categories_file"
    sx_basic_err "Could not create temporary file."
    return 1
  }

  sx_list | while IFS='|' read -r id source category label risk description; do
    [ -n "$id" ] || continue
    printf '%s\n' "$category"
  done | sort -u >"$categories_file"

  if [ ! -s "$categories_file" ]; then
    rm -f "$categories_file" "$tools_file"
    sx_basic_err "No tools available."
    return 1
  fi

  printf '%s\n' "Wähle eine Kategorie:"
  printf '\n'

  count=0
  while IFS= read -r category; do
    count=$((count + 1))
    printf '  %s) %s\n' "$count" "$category"
  done <"$categories_file"

  printf '\n'
  printf '%s' "Auswahl: "
  IFS= read -r category_choice || {
    rm -f "$categories_file" "$tools_file"
    return 1
  }

  if [ -z "$category_choice" ]; then
    rm -f "$categories_file" "$tools_file"
    printf '%s\n' "Keine Kategorie ausgewählt."
    return 0
  fi

  case "$category_choice" in
  *[!0-9]*)
    rm -f "$categories_file" "$tools_file"
    sx_basic_err "Invalid category selection: $category_choice"
    return 1
    ;;
  esac

  selected_category=""
  count=0
  while IFS= read -r category; do
    count=$((count + 1))

    if [ "$count" -eq "$category_choice" ] 2>/dev/null; then
      selected_category=$category
      break
    fi
  done <"$categories_file"

  if [ -z "$selected_category" ]; then
    rm -f "$categories_file" "$tools_file"
    sx_basic_err "Category selection out of range: $category_choice"
    return 1
  fi

  sx_list | while IFS='|' read -r id source category label risk description; do
    [ -n "$id" ] || continue

    if [ "$category" = "$selected_category" ]; then
      printf '%s|%s|%s|%s|%s|%s\n' \
        "$id" \
        "$source" \
        "$category" \
        "$label" \
        "$risk" \
        "$description"
    fi
  done >"$tools_file"

  if [ ! -s "$tools_file" ]; then
    rm -f "$categories_file" "$tools_file"
    sx_basic_err "No tools found for category: $selected_category"
    return 1
  fi

  printf '\n'
  printf 'Kategorie: %s\n' "$selected_category"
  printf '\n'

  count=0
  while IFS='|' read -r id source category label risk description; do
    count=$((count + 1))

    printf '  %s) %s\n' "$count" "$label"
    printf '     ID:          %s\n' "$id"
    printf '     Source:      %s\n' "$source"
    printf '     Risk:        %s\n' "$risk"
    printf '     Description: %s\n' "$description"
    printf '\n'
  done <"$tools_file"

  printf '%s' "Auswahl: "
  IFS= read -r tool_choice || {
    rm -f "$categories_file" "$tools_file"
    return 1
  }

  if [ -z "$tool_choice" ]; then
    rm -f "$categories_file" "$tools_file"
    printf '%s\n' "Kein Tool ausgewählt."
    return 0
  fi

  case "$tool_choice" in
  *[!0-9]*)
    rm -f "$categories_file" "$tools_file"
    sx_basic_err "Invalid tool selection: $tool_choice"
    return 1
    ;;
  esac

  selected_tool_id=""
  count=0
  while IFS='|' read -r id source category label risk description; do
    count=$((count + 1))

    if [ "$count" -eq "$tool_choice" ] 2>/dev/null; then
      selected_tool_id=$id
      break
    fi
  done <"$tools_file"

  if [ -z "$selected_tool_id" ]; then
    rm -f "$categories_file" "$tools_file"
    sx_basic_err "Tool selection out of range: $tool_choice"
    return 1
  fi

  rm -f "$categories_file" "$tools_file"

  printf '\n'
  printf '%s' "Argumente optional eingeben, sonst Enter: "
  IFS= read -r tool_args || tool_args=""

  printf '\n'

  if [ -z "$tool_args" ]; then
    sx_run "$selected_tool_id"
  else
    # Simple whitespace-based argument splitting for the basic menu.
    # For complex quoting, use direct CLI mode:
    #   sx-ctl <tool-id> [args...]
    # shellcheck disable=SC2086
    sx_run "$selected_tool_id" $tool_args
  fi

}

sx_basic_main() {
  sx_basic_load_core || return 1

  cmd="${1:-}"

  case "$cmd" in
  "")
    sx_basic_prompt
    ;;
  help | --help | -h)
    sx_basic_usage
    ;;
  version | --version | -v)
    sx_basic_version
    ;;
  list | ls)
    sx_basic_print_list
    ;;
  run)
    shift

    if [ $# -lt 1 ]; then
      sx_basic_err "Missing tool id."
      sx_basic_err "Usage: sx-ctl-basic.sh run <tool-id> [args...]"
      return 1
    fi

    tool_id=$1
    shift

    sx_run "$tool_id" "$@"
    ;;
  -*)
    sx_basic_err "Unknown option: $cmd"
    sx_basic_err "Run 'sx-ctl-basic.sh help' for usage."
    return 1
    ;;
  *)
    tool_id=$1
    shift
    sx_run "$tool_id" "$@"
    ;;
  esac
}

sx_basic_make_temp_file() {
  if sx_basic_have_cmd mktemp; then
    mktemp "${TMPDIR:-/tmp}/sx-ctl-basic.XXXXXX"
    return $?
  fi

  tmp="${TMPDIR:-/tmp}/sx-ctl-basic.$$"
  : >"$tmp" || return 1
  printf '%s\n' "$tmp"
}

sx_basic_main "$@"
