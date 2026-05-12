#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.validate-manifest
# Name:        Manifest prüfen
# Description: Prüft Public und Private Manifest auf Strukturfehler
# Dependencies: sh, awk
# Risk:        low
# ============================================================

SX_RAW_BASE="${SX_RAW_BASE:-https://raw.githubusercontent.com/Peppeppa/sx-ctl/main}"
SX_LOCAL_ROOT="${SX_LOCAL_ROOT:-}"
SX_PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

MANIFEST_HEADER="id|source|category|label|path|description|shell|deps|risk"

ERRORS=0
WARNINGS=0

err() {
  printf '%s\n' "admin.validate-manifest: $*" >&2
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

fetch_url() {
  url=$1

  if have_cmd curl; then
    curl -fsSL "$url"
    return $?
  fi

  if have_cmd wget; then
    wget -qO- "$url"
    return $?
  fi

  err "Neither curl nor wget is available."
  return 1
}

make_temp_file() {
  if have_cmd mktemp; then
    mktemp "${TMPDIR:-/tmp}/sx-ctl-validate.XXXXXX"
    return $?
  fi

  tmp="${TMPDIR:-/tmp}/sx-ctl-validate.$$"
  : >"$tmp" || return 1
  printf '%s\n' "$tmp"
}

add_error() {
  ERRORS=$((ERRORS + 1))
  printf '%s\n' "ERROR: $*"
}

add_warning() {
  WARNINGS=$((WARNINGS + 1))
  printf '%s\n' "WARN:  $*"
}

read_public_manifest_to_file() {
  target_file=$1

  if [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/manifest.txt" ]; then
    cat "$SX_LOCAL_ROOT/manifest.txt" >"$target_file"
    return $?
  fi

  if [ -f "./manifest.txt" ]; then
    cat "./manifest.txt" >"$target_file"
    return $?
  fi

  fetch_url "$SX_RAW_BASE/manifest.txt" >"$target_file"
}

validate_path() {
  source_name=$1
  manifest_name=$2
  line_no=$3
  tool_id=$4
  path=$5

  case "$path" in
  "")
    add_error "$manifest_name:$line_no: tool '$tool_id' has empty path."
    return 1
    ;;
  /*)
    add_error "$manifest_name:$line_no: tool '$tool_id' path must be relative: $path"
    return 1
    ;;
  *../* | ../* | *'/..')
    add_error "$manifest_name:$line_no: tool '$tool_id' path must not contain '..': $path"
    return 1
    ;;
  esac

  case "$source_name" in
  public)
    if [ -n "$SX_LOCAL_ROOT" ]; then
      if [ ! -f "$SX_LOCAL_ROOT/$path" ]; then
        add_error "$manifest_name:$line_no: public script not found locally: $path"
        return 1
      fi
    elif [ -f "./manifest.txt" ]; then
      if [ ! -f "./$path" ]; then
        add_error "$manifest_name:$line_no: public script not found locally: $path"
        return 1
      fi
    fi
    ;;
  private)
    if [ ! -f "$SX_PRIVATE_ROOT/$path" ]; then
      add_error "$manifest_name:$line_no: private script not found: $SX_PRIVATE_ROOT/$path"
      return 1
    fi
    ;;
  esac

  return 0
}

validate_entry() {
  manifest_name=$1
  expected_source=$2
  line_no=$3
  line=$4
  ids_file=$5

  field_count=$(printf '%s\n' "$line" | awk -F '|' '{ print NF }')

  if [ "$field_count" -ne 9 ]; then
    add_error "$manifest_name:$line_no: expected 9 fields, got $field_count: $line"
    return 1
  fi

  id=$(printf '%s\n' "$line" | awk -F '|' '{ print $1 }')
  source=$(printf '%s\n' "$line" | awk -F '|' '{ print $2 }')
  category=$(printf '%s\n' "$line" | awk -F '|' '{ print $3 }')
  label=$(printf '%s\n' "$line" | awk -F '|' '{ print $4 }')
  path=$(printf '%s\n' "$line" | awk -F '|' '{ print $5 }')
  description=$(printf '%s\n' "$line" | awk -F '|' '{ print $6 }')
  shell_name=$(printf '%s\n' "$line" | awk -F '|' '{ print $7 }')
  deps=$(printf '%s\n' "$line" | awk -F '|' '{ print $8 }')
  risk=$(printf '%s\n' "$line" | awk -F '|' '{ print $9 }')

  if [ -z "$id" ]; then
    add_error "$manifest_name:$line_no: id is empty."
    return 1
  fi

  if [ -z "$source" ]; then
    add_error "$manifest_name:$line_no: source is empty for tool '$id'."
    return 1
  fi

  if [ -z "$category" ]; then
    add_error "$manifest_name:$line_no: category is empty for tool '$id'."
    return 1
  fi

  if [ -z "$label" ]; then
    add_error "$manifest_name:$line_no: label is empty for tool '$id'."
    return 1
  fi

  if [ -z "$description" ]; then
    add_error "$manifest_name:$line_no: description is empty for tool '$id'."
    return 1
  fi

  if [ -z "$shell_name" ]; then
    add_error "$manifest_name:$line_no: shell is empty for tool '$id'."
    return 1
  fi

  if [ -z "$risk" ]; then
    add_error "$manifest_name:$line_no: risk is empty for tool '$id'."
    return 1
  fi

  case "$source" in
  public | private)
    ;;
  *)
    add_error "$manifest_name:$line_no: unsupported source '$source' for tool '$id'."
    return 1
    ;;
  esac

  if [ "$source" != "$expected_source" ]; then
    add_error "$manifest_name:$line_no: expected source '$expected_source', got '$source' for tool '$id'."
    return 1
  fi

  case "$source:$id" in
  private:private.*)
    ;;
  private:*)
    add_error "$manifest_name:$line_no: private tool id '$id' must start with 'private.'."
    return 1
    ;;
  public:private.*)
    add_error "$manifest_name:$line_no: public tool id '$id' must not start with 'private.'."
    return 1
    ;;
  public:*)
    ;;
  esac

  case "$shell_name" in
  sh | bash)
    ;;
  *)
    add_error "$manifest_name:$line_no: unsupported shell '$shell_name' for tool '$id'."
    return 1
    ;;
  esac

  case "$risk" in
  low | medium | high)
    ;;
  *)
    add_error "$manifest_name:$line_no: unsupported risk '$risk' for tool '$id'."
    return 1
    ;;
  esac

  if printf '%s\n' "$id$source$category$label$path$description$shell_name$deps$risk" | grep '|' >/dev/null 2>&1; then
    add_error "$manifest_name:$line_no: manifest field contains pipe character for tool '$id'."
    return 1
  fi

  validate_path "$source" "$manifest_name" "$line_no" "$id" "$path" || return 1

  printf '%s|%s|%s\n' "$id" "$manifest_name" "$line_no" >>"$ids_file"

  return 0
}

validate_manifest_file() {
  manifest_name=$1
  expected_source=$2
  manifest_file=$3
  ids_file=$4

  echo
  echo "Checking $manifest_name"
  echo "------------------------"

  if [ ! -f "$manifest_file" ]; then
    if [ "$expected_source" = "private" ]; then
      echo "SKIP: private manifest not found."
      return 0
    fi

    add_error "$manifest_name: manifest file not found."
    return 1
  fi

  if [ ! -s "$manifest_file" ]; then
    add_error "$manifest_name: manifest is empty."
    return 1
  fi

  first_line=$(sed -n '1p' "$manifest_file")

  if [ "$first_line" != "$MANIFEST_HEADER" ]; then
    add_error "$manifest_name: invalid header."
    printf '%s\n' "Expected: $MANIFEST_HEADER"
    printf '%s\n' "Actual:   $first_line"
    return 1
  fi

  valid_count=0
  line_no=0

  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))

    [ -z "$line" ] && continue

    if [ "$line_no" -eq 1 ]; then
      continue
    fi

    if validate_entry "$manifest_name" "$expected_source" "$line_no" "$line" "$ids_file"; then
      valid_count=$((valid_count + 1))
    fi
  done <"$manifest_file"

  if [ "$valid_count" -eq 0 ]; then
    add_warning "$manifest_name: no tool entries found."
  else
    echo "OK: $valid_count tool entries checked."
  fi

  return 0
}

check_duplicate_ids() {
  ids_file=$1

  echo
  echo "Checking duplicate tool IDs"
  echo "---------------------------"

  if [ ! -s "$ids_file" ]; then
    echo "SKIP: no IDs collected."
    return 0
  fi

  duplicates=$(cut -d '|' -f 1 "$ids_file" | sort | uniq -d)

  if [ -z "$duplicates" ]; then
    echo "OK: no duplicate tool IDs found."
    return 0
  fi

  printf '%s\n' "$duplicates" | while IFS= read -r duplicate_id; do
    [ -n "$duplicate_id" ] || continue
    add_error "duplicate tool id found: $duplicate_id"
    grep "^$duplicate_id|" "$ids_file" | while IFS='|' read -r id manifest_name line_no; do
      printf '%s\n' "  - $manifest_name:$line_no"
    done
  done

  return 1
}

main() {
  if ! have_cmd awk; then
    err "Required command not found: awk"
    return 1
  fi

  public_manifest_file=$(make_temp_file) || {
    err "Could not create temporary file."
    return 1
  }

  ids_file=$(make_temp_file) || {
    rm -f "$public_manifest_file"
    err "Could not create temporary file."
    return 1
  }

  private_manifest_file="$SX_PRIVATE_ROOT/manifest.txt"

  echo "sx-ctl manifest validation"
  echo "=========================="
  echo
  echo "Public source:"
  if [ -n "$SX_LOCAL_ROOT" ] && [ -f "$SX_LOCAL_ROOT/manifest.txt" ]; then
    echo "  $SX_LOCAL_ROOT/manifest.txt"
  elif [ -f "./manifest.txt" ]; then
    echo "  ./manifest.txt"
  else
    echo "  $SX_RAW_BASE/manifest.txt"
  fi
  echo
  echo "Private source:"
  echo "  $private_manifest_file"

  if ! read_public_manifest_to_file "$public_manifest_file"; then
    rm -f "$public_manifest_file" "$ids_file"
    err "Could not read public manifest."
    return 1
  fi

  validate_manifest_file "public manifest" "public" "$public_manifest_file" "$ids_file"
  validate_manifest_file "private manifest" "private" "$private_manifest_file" "$ids_file"
  check_duplicate_ids "$ids_file" || true

  rm -f "$public_manifest_file" "$ids_file"

  echo
  echo "Summary"
  echo "-------"
  echo "Errors:   $ERRORS"
  echo "Warnings: $WARNINGS"

  if [ "$ERRORS" -ne 0 ]; then
    echo
    echo "Result: invalid"
    return 1
  fi

  echo
  echo "Result: valid"
  return 0
}

main "$@"
