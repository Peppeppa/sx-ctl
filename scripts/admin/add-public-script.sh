#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.add-public-script
# Name:        Public Script hinzufügen
# Description: Kopiert ein bestehendes Script ins Public Repo und ergänzt das Manifest
# Dependencies: sh, cp, chmod, find, awk
# Risk:        medium
# ============================================================

PUBLIC_ROOT="${SX_LOCAL_ROOT:-$(pwd)}"
PUBLIC_SCRIPTS_DIR="$PUBLIC_ROOT/scripts"
PUBLIC_MANIFEST="$PUBLIC_ROOT/manifest.txt"

err() {
  printf '%s\n' "admin.add-public-script: $*" >&2
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
    mktemp "${TMPDIR:-/tmp}/sx-ctl-add-public.XXXXXX"
    return $?
  fi

  tmp="${TMPDIR:-/tmp}/sx-ctl-add-public.$$"
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

validate_id() {
  id=$1

  case "$id" in
  private.*)
    die "Public tool id must not start with 'private.': $id"
    ;;
  *'|'* | "")
    die "Invalid tool id: $id"
    ;;
  esac
}

manifest_has_id() {
  id=$1

  [ -f "$PUBLIC_MANIFEST" ] || return 1

  awk -F '|' -v wanted="$id" 'NR > 1 && $1 == wanted { found = 1 } END { exit(found ? 0 : 1) }' "$PUBLIC_MANIFEST"
}

choose_category() {
  categories_file=$(make_temp_file) || die "Could not create temporary file."

  find "$PUBLIC_SCRIPTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
    while IFS= read -r dir; do
      basename "$dir"
    done |
    sort >"$categories_file"

  echo "Wähle eine Kategorie:"
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

    mkdir -p "$PUBLIC_SCRIPTS_DIR/$new_category"
    printf '%s\n' "$new_category"
    return 0
  fi

  die "Category selection out of range."
}

prompt_default() {
  prompt=$1
  default=$2

  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default"
  else
    printf '%s: ' "$prompt"
  fi

  IFS= read -r value

  if [ -z "$value" ]; then
    value=$default
  fi

  printf '%s\n' "$value"
}

main() {
  need_cmd cp
  need_cmd chmod
  need_cmd find
  need_cmd awk

  source_file=${1:-}

  if [ -z "$source_file" ]; then
    printf '%s' "Pfad zur Script-Datei: "
    IFS= read -r source_file
  fi

  [ -n "$source_file" ] || die "Missing script file."
  [ -f "$source_file" ] || die "Script file not found: $source_file"

  [ -d "$PUBLIC_ROOT" ] || die "Public root not found: $PUBLIC_ROOT"
  [ -d "$PUBLIC_SCRIPTS_DIR" ] || die "Public scripts directory not found: $PUBLIC_SCRIPTS_DIR"
  [ -f "$PUBLIC_MANIFEST" ] || die "Public manifest not found: $PUBLIC_MANIFEST"

  category=$(choose_category)

  default_file_name=$(basename "$source_file")
  file_name=$(prompt_default "Dateiname im Zielordner" "$default_file_name")
  [ -n "$file_name" ] || die "File name must not be empty."

  case "$file_name" in
  */* | *..*)
    die "Invalid file name: $file_name"
    ;;
  esac

  dest_dir="$PUBLIC_SCRIPTS_DIR/$category"
  dest_path="$dest_dir/$file_name"
  manifest_path="scripts/$category/$file_name"

  if [ -e "$dest_path" ]; then
    die "Destination already exists: $dest_path"
  fi

  base_name=${file_name%.*}
  default_id="$category.$base_name"

  tool_id=$(prompt_default "Tool-ID" "$default_id")
  validate_id "$tool_id"

  if manifest_has_id "$tool_id"; then
    die "Tool-ID already exists in manifest: $tool_id"
  fi

  label=$(prompt_default "Label" "$base_name")
  description=$(prompt_default "Beschreibung" "TODO")
  shell_name=$(prompt_default "Shell sh/bash" "sh")
  deps=$(prompt_default "Dependencies" "$shell_name")
  risk=$(prompt_default "Risk low/medium/high" "low")

  validate_no_pipe "$tool_id" "id"
  validate_no_pipe "$category" "category"
  validate_no_pipe "$label" "label"
  validate_no_pipe "$manifest_path" "path"
  validate_no_pipe "$description" "description"
  validate_no_pipe "$shell_name" "shell"
  validate_no_pipe "$deps" "deps"
  validate_no_pipe "$risk" "risk"

  case "$shell_name" in
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

  mkdir -p "$dest_dir"
  cp "$source_file" "$dest_path"
  chmod +x "$dest_path"

  printf '%s|public|%s|%s|%s|%s|%s|%s|%s\n' \
    "$tool_id" \
    "$category" \
    "$label" \
    "$manifest_path" \
    "$description" \
    "$shell_name" \
    "$deps" \
    "$risk" >>"$PUBLIC_MANIFEST"

  echo
  echo "Public script added:"
  echo "  $dest_path"
  echo
  echo "Manifest entry:"
  echo "  $tool_id|public|$category|$label|$manifest_path|$description|$shell_name|$deps|$risk"
  echo
  echo "Next checks:"
  echo "  sx-ctl admin.validate-manifest"
  echo "  sh tests/check.sh"
}

main "$@"
