#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.create-private-script
# Name:        Private Script erstellen
# Description: Erstellt ein neues Private Script aus dem Template und öffnet es in Neovim
# Dependencies: sh, cp, chmod, find, nvim, awk
# Risk:        medium
# ============================================================

PUBLIC_ROOT="${SX_LOCAL_ROOT:-$(pwd)}"
PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"
PRIVATE_SCRIPTS_DIR="$PRIVATE_ROOT/scripts"
TEMPLATE_FILE="$PUBLIC_ROOT/templates/script-template.sh"
EDITOR_CMD="${SX_EDITOR:-nvim}"

err() {
  printf '%s\n' "admin.create-private-script: $*" >&2
}

die() {
  err "$@"
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_cmd() {
  cmd=$1
  have_cmd "$cmd" || die "Required command not found: $cmd"
}

make_temp_file() {
  if have_cmd mktemp; then
    mktemp "${TMPDIR:-/tmp}/sx-ctl-create-private.XXXXXX"
    return $?
  fi

  tmp="${TMPDIR:-/tmp}/sx-ctl-create-private.$$"
  : >"$tmp" || return 1
  printf '%s\n' "$tmp"
}

validate_no_pipe() {
  value=$1
  field=$2

  case "$value" in
  *'|'*)
    die "$field must not contain pipe character '|'."
    ;;
  esac
}

ensure_private_overlay() {
  mkdir -p "$PRIVATE_ROOT"
  mkdir -p "$PRIVATE_SCRIPTS_DIR"

  if [ ! -f "$PRIVATE_ROOT/manifest.txt" ]; then
    cat >"$PRIVATE_ROOT/manifest.txt" <<'EOF'
id|source|category|label|path|description|shell|deps|risk
EOF
  fi
}

choose_category() {
  categories_file=$(make_temp_file) || die "Could not create temporary file."

  find "$PRIVATE_SCRIPTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
    while IFS= read -r dir; do
      basename "$dir"
    done |
    sort >"$categories_file"

  echo "private" >&2

  count=0
  while IFS= read -r category; do
    count=$((count + 1))

    if [ "$count" -eq 1 ]; then
      printf '%s\n' "├── $category" >&2
    else
      printf '%s\n' "├── $category" >&2
    fi
  done <"$categories_file"

  printf '%s\n' "└── neue Kategorie" >&2
  echo >&2

  count=0
  while IFS= read -r category; do
    count=$((count + 1))
    printf '  %s) %s\n' "$count" "$category" >&2
  done <"$categories_file"

  new_choice=$((count + 1))
  printf '  %s) %s\n' "$new_choice" "neu" >&2
  echo >&2

  printf '%s' "Auswahl: " >&2
  IFS= read -r choice

  case "$choice" in
  n | N | neu | new)
    choice=$new_choice
    ;;
  esac

  case "$choice" in
  *[!0-9]* | "")
    rm -f "$categories_file"
    die "Invalid category selection."
    ;;
  esac

  selected=""
  current=0

  while IFS= read -r category; do
    current=$((current + 1))

    if [ "$current" -eq "$choice" ] 2>/dev/null; then
      selected=$category
      break
    fi
  done <"$categories_file"

  rm -f "$categories_file"

  if [ -n "$selected" ]; then
    printf '%s\n' "$selected"
    return 0
  fi

  if [ "$choice" -eq "$new_choice" ] 2>/dev/null; then
    printf '%s' "Neue Kategorie: " >&2
    IFS= read -r new_category

    [ -n "$new_category" ] || die "Category must not be empty."
    validate_no_pipe "$new_category" "category"

    case "$new_category" in
    */* | *..* | .*)
      die "Invalid category name: $new_category"
      ;;
    esac

    mkdir -p "$PRIVATE_SCRIPTS_DIR/$new_category"
    printf '%s\n' "$new_category"
    return 0
  fi

  die "Category selection out of range."
}

validate_id() {
  id=$1

  case "$id" in
  private.*)
    ;;
  *)
    die "Private tool id must start with 'private.': $id"
    ;;
  esac

  case "$id" in
  *'|'* | "")
    die "Invalid tool id: $id"
    ;;
  esac
}

manifest_has_id() {
  id=$1
  manifest_file="$PRIVATE_ROOT/manifest.txt"

  [ -f "$manifest_file" ] || return 1

  awk -F '|' -v wanted="$id" '
    NR > 1 && $1 == wanted {
      found = 1
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$manifest_file"
}

prompt_default() {
  prompt=$1
  default=$2

  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi

  IFS= read -r value

  if [ -z "$value" ]; then
    value=$default
  fi

  printf '%s\n' "$value"
}

register_private_script() {
  category=$1
  script_name=$2
  script_path=$3

  manifest_file="$PRIVATE_ROOT/manifest.txt"
  manifest_path="scripts/$category/$script_name.sh"

  if [ ! -f "$manifest_file" ]; then
    cat >"$manifest_file" <<'EOF'
id|source|category|label|path|description|shell|deps|risk
EOF
  fi

  tool_id="private.$category.$script_name"
  label="$script_name"

  header_description=$(get_header_value "Description" "$script_path" || true)
  header_deps=$(get_header_value "Dependencies" "$script_path" || true)
  detected_shell=$(detect_shell "$script_path")

  if [ -z "$header_description" ] || [ "$header_description" = "Short description of what this script does" ]; then
    header_description="TODO"
  fi

  if [ -z "$header_deps" ]; then
    header_deps="$detected_shell"
  fi

  deps=$(normalize_deps "$header_deps")
  [ -n "$deps" ] || deps="$detected_shell"

  echo
  echo "Manifest-Eintrag erstellen"
  echo "=========================="
  echo
  echo "Automatisch erkannt:"
  echo "  Tool-ID:       $tool_id"
  echo "  Source:        private"
  echo "  Category:      $category"
  echo "  Label:         $label"
  echo "  Path:          $manifest_path"
  echo "  Shell:         $detected_shell"
  echo "  Dependencies:  $deps"
  echo

  validate_id "$tool_id"

  if manifest_has_id "$tool_id"; then
    die "Tool-ID already exists in private manifest: $tool_id"
  fi

  description=$(prompt_default "Beschreibung" "$header_description")
  risk=$(prompt_default "Risk low/medium/high" "low")

  validate_no_pipe "$tool_id" "id"
  validate_no_pipe "$category" "category"
  validate_no_pipe "$label" "label"
  validate_no_pipe "$manifest_path" "path"
  validate_no_pipe "$description" "description"
  validate_no_pipe "$detected_shell" "shell"
  validate_no_pipe "$deps" "deps"
  validate_no_pipe "$risk" "risk"

  case "$detected_shell" in
  sh | bash)
    ;;
  *)
    die "Shell must be 'sh' or 'bash'."
    ;;
  esac

  case "$risk" in
  low | medium | high)
    ;;
  *)
    die "Risk must be 'low', 'medium' or 'high'."
    ;;
  esac

  printf '%s|private|%s|%s|%s|%s|%s|%s|%s\n' \
    "$tool_id" \
    "$category" \
    "$label" \
    "$manifest_path" \
    "$description" \
    "$detected_shell" \
    "$deps" \
    "$risk" >>"$manifest_file"

  echo
  echo "Private manifest updated:"
  echo "  $manifest_file"
  echo
  echo "Manifest entry:"
  echo "  $tool_id|private|$category|$label|$manifest_path|$description|$detected_shell|$deps|$risk"
  echo
  echo "Next checks:"
  echo "  sx-ctl admin.validate-manifest"
  echo "  sx-ctl -la"
  echo
  echo "Run script:"
  echo "  sx-ctl $tool_id"
}

get_header_value() {
  key=$1
  file=$2

  awk -v key="$key" '
    BEGIN {
      pattern = "^# " key ":[[:space:]]*"
    }
    $0 ~ pattern {
      sub(pattern, "", $0)
      print $0
      exit
    }
  ' "$file"
}

detect_shell() {
  file=$1

  first_line=$(sed -n '1p' "$file")

  case "$first_line" in
  *bash*)
    printf '%s\n' "bash"
    ;;
  *)
    printf '%s\n' "sh"
    ;;
  esac
}

normalize_deps() {
  deps=$1

  printf '%s\n' "$deps" |
    tr ',' ' ' |
    awk '
      {
        for (i = 1; i <= NF; i++) {
          if ($i != "") {
            if (out == "") {
              out = $i
            } else {
              out = out "," $i
            }
          }
        }
      }
      END {
        print out
      }
    '
}

main() {
  need_cmd cp
  need_cmd chmod
  need_cmd find
  need_cmd awk
  need_cmd sed
  need_cmd tr
  need_cmd "$EDITOR_CMD"

  [ -f "$TEMPLATE_FILE" ] || die "Template not found: $TEMPLATE_FILE"

  ensure_private_overlay

  category=$(choose_category)

  printf '%s' "Script-Dateiname ohne .sh: "
  IFS= read -r script_name

  [ -n "$script_name" ] || die "Script name must not be empty."

  case "$script_name" in
  */* | *..* | *.sh | .*)
    die "Invalid script name. Use name without .sh, for example: weather"
    ;;
  esac

  dest_dir="$PRIVATE_SCRIPTS_DIR/$category"
  dest_path="$dest_dir/$script_name.sh"

  if [ -e "$dest_path" ]; then
    die "Destination already exists: $dest_path"
  fi

  mkdir -p "$dest_dir"
  cp "$TEMPLATE_FILE" "$dest_path"
  chmod +x "$dest_path"

  echo
  echo "Created private script:"
  echo "  $dest_path"
  echo
  echo "Opening with:"
  echo "  $EDITOR_CMD $dest_path"
  echo

  "$EDITOR_CMD" "$dest_path"

  register_private_script "$category" "$script_name" "$dest_path"
}

main "$@"
