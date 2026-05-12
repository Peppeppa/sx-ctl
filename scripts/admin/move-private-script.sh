#!/usr/bin/env sh
set -eu

PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"
PRIVATE_SCRIPTS_DIR="$PRIVATE_ROOT/scripts"
PRIVATE_MANIFEST="$PRIVATE_ROOT/manifest.txt"

err() { printf '%s\n' "admin.move-private-script: $*" >&2; }
die() {
  err "$@"
  exit 1
}
have_cmd() { command -v "$1" >/dev/null 2>&1; }
need_cmd() { have_cmd "$1" || die "Required command not found: $1"; }

make_temp_file() {
  if have_cmd mktemp; then
    mktemp "${TMPDIR:-/tmp}/sx-ctl-move-private.XXXXXX"
  else
    tmp="${TMPDIR:-/tmp}/sx-ctl-move-private.$$"
    : >"$tmp" || return 1
    printf '%s\n' "$tmp"
  fi
}

validate_no_pipe() {
  case "$1" in
  *'|'*) die "$2 must not contain pipe character '|'." ;;
  esac
}

choose_tool() {
  entries_file=$(make_temp_file) || die "Could not create temporary file."

  awk -F '|' 'NR > 1 && $2 == "private" {
    print $1 "|" $3 "|" $4 "|" $5 "|" $6 "|" $7 "|" $8 "|" $9
  }' "$PRIVATE_MANIFEST" >"$entries_file"

  [ -s "$entries_file" ] || {
    rm -f "$entries_file"
    die "No private tools found."
  }

  echo "Wähle ein privates Tool:" >&2
  echo >&2

  count=0
  while IFS='|' read -r id category label path description shell_name deps risk; do
    count=$((count + 1))
    printf '  %s) %s - %s\n' "$count" "$id" "$label" >&2
    printf '     Path: %s\n' "$path" >&2
  done <"$entries_file"

  echo >&2
  printf '%s' "Auswahl: " >&2
  IFS= read -r choice

  case "$choice" in
  *[!0-9]* | "")
    rm -f "$entries_file"
    die "Invalid selection."
    ;;
  esac

  selected=""
  count=0
  while IFS='|' read -r id category label path description shell_name deps risk; do
    count=$((count + 1))
    if [ "$count" -eq "$choice" ] 2>/dev/null; then
      selected="$id|$category|$label|$path|$description|$shell_name|$deps|$risk"
      break
    fi
  done <"$entries_file"

  rm -f "$entries_file"

  [ -n "$selected" ] || die "Selection out of range."
  printf '%s\n' "$selected"
}

choose_category() {
  categories_file=$(make_temp_file) || die "Could not create temporary file."

  mkdir -p "$PRIVATE_SCRIPTS_DIR"

  find "$PRIVATE_SCRIPTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
    while IFS= read -r dir; do basename "$dir"; done |
    sort >"$categories_file"

  echo "private" >&2

  count=0
  while IFS= read -r category; do
    count=$((count + 1))
    printf '  %s) %s\n' "$count" "$category" >&2
  done <"$categories_file"

  new_choice=$((count + 1))
  printf '  %s) %s\n' "$new_choice" "neu" >&2
  echo >&2
  printf '%s' "Auswahl Zielkategorie: " >&2
  IFS= read -r choice

  case "$choice" in
  n | N | neu | new) choice=$new_choice ;;
  esac

  case "$choice" in
  *[!0-9]* | "")
    rm -f "$categories_file"
    die "Invalid category selection."
    ;;
  esac

  selected=""
  count=0
  while IFS= read -r category; do
    count=$((count + 1))
    if [ "$count" -eq "$choice" ] 2>/dev/null; then
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
    */* | *..* | .*) die "Invalid category name: $new_category" ;;
    esac

    mkdir -p "$PRIVATE_SCRIPTS_DIR/$new_category"
    printf '%s\n' "$new_category"
    return 0
  fi

  die "Category selection out of range."
}

manifest_has_id() {
  wanted=$1
  old=$2

  awk -F '|' -v wanted="$wanted" -v old="$old" '
    NR > 1 && $1 == wanted && $1 != old { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$PRIVATE_MANIFEST"
}

main() {
  need_cmd awk
  need_cmd find
  need_cmd mv

  [ -f "$PRIVATE_MANIFEST" ] || die "Private manifest not found: $PRIVATE_MANIFEST"

  selected=$(choose_tool)

  old_id=$(printf '%s\n' "$selected" | cut -d '|' -f 1)
  old_category=$(printf '%s\n' "$selected" | cut -d '|' -f 2)
  old_label=$(printf '%s\n' "$selected" | cut -d '|' -f 3)
  old_path=$(printf '%s\n' "$selected" | cut -d '|' -f 4)
  old_description=$(printf '%s\n' "$selected" | cut -d '|' -f 5)
  old_shell=$(printf '%s\n' "$selected" | cut -d '|' -f 6)
  old_deps=$(printf '%s\n' "$selected" | cut -d '|' -f 7)
  old_risk=$(printf '%s\n' "$selected" | cut -d '|' -f 8)

  old_file="$PRIVATE_ROOT/$old_path"
  [ -f "$old_file" ] || die "Script file not found: $old_file"

  new_category=$(choose_category)
  old_file_name=$(basename "$old_path")

  printf 'Neuer Dateiname [%s]: ' "$old_file_name" >&2
  IFS= read -r new_file_name
  [ -n "$new_file_name" ] || new_file_name=$old_file_name

  case "$new_file_name" in
  */* | *..*) die "Invalid file name: $new_file_name" ;;
  esac

  base_name=${new_file_name%.*}
  new_id="private.$new_category.$base_name"
  new_path="scripts/$new_category/$new_file_name"
  new_file="$PRIVATE_ROOT/$new_path"

  validate_no_pipe "$new_id" "id"
  validate_no_pipe "$new_category" "category"
  validate_no_pipe "$new_path" "path"

  if manifest_has_id "$new_id" "$old_id"; then
    die "Target tool id already exists: $new_id"
  fi

  [ ! -e "$new_file" ] || die "Target file already exists: $new_file"

  mkdir -p "$PRIVATE_ROOT/scripts/$new_category"
  mv "$old_file" "$new_file"

  tmp_manifest=$(make_temp_file) || die "Could not create temporary file."

  awk -F '|' -v OFS='|' \
    -v old_id="$old_id" \
    -v new_id="$new_id" \
    -v new_category="$new_category" \
    -v label="$old_label" \
    -v new_path="$new_path" \
    -v description="$old_description" \
    -v shell_name="$old_shell" \
    -v deps="$old_deps" \
    -v risk="$old_risk" '
    NR == 1 { print; next }
    $1 == old_id {
      print new_id, "private", new_category, label, new_path, description, shell_name, deps, risk
      next
    }
    { print }
  ' "$PRIVATE_MANIFEST" >"$tmp_manifest"

  mv "$tmp_manifest" "$PRIVATE_MANIFEST"

  echo
  echo "Private script moved:"
  echo "  $old_path"
  echo "  -> $new_path"
  echo
  echo "Tool ID:"
  echo "  $old_id"
  echo "  -> $new_id"
  echo
  echo "Run:"
  echo "  sx-ctl $new_id"
}

main "$@"
