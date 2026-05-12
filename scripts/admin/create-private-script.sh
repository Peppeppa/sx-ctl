#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.create-private-script
# Name:        Private Script erstellen
# Description: Erstellt ein neues Private Script aus dem Template und öffnet es in Neovim
# Dependencies: sh, cp, chmod, find, nvim
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

  echo "Wähle eine private Kategorie:"
  echo

  count=0
  while IFS= read -r category; do
    count=$((count + 1))
    printf '  %s) %s\n' "$count" "$category"
  done <"$categories_file"

  count=$((count + 1))
  printf '  %s) %s\n' "$count" "Neue Kategorie erstellen"

  echo
  printf '%s' "Auswahl: "
  IFS= read -r choice

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

  if [ "$choice" -eq "$count" ] 2>/dev/null; then
    printf '%s' "Neue Kategorie: "
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

main() {
  need_cmd cp
  need_cmd chmod
  need_cmd find
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

  echo
  echo "Next step:"
  echo "  sx-ctl admin.add-private-script $dest_path"
}

main "$@"
