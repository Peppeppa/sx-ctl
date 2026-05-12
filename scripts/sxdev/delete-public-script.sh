#!/usr/bin/env sh
set -eu

PUBLIC_ROOT="${SX_PUBLIC_ROOT:-${SX_LOCAL_ROOT:-$(pwd)}}"
PUBLIC_MANIFEST="$PUBLIC_ROOT/manifest.txt"

err() { printf '%s\n' "sxdev.delete-public-script: $*" >&2; }
die() {
  err "$@"
  exit 1
}
have_cmd() { command -v "$1" >/dev/null 2>&1; }
need_cmd() { have_cmd "$1" || die "Required command not found: $1"; }

make_temp_file() {
  if have_cmd mktemp; then
    mktemp "${TMPDIR:-/tmp}/sx-ctl-delete-public.XXXXXX"
  else
    tmp="${TMPDIR:-/tmp}/sx-ctl-delete-public.$$"
    : >"$tmp" || return 1
    printf '%s\n' "$tmp"
  fi
}

ensure_public_root() {
  [ -f "$PUBLIC_ROOT/sx-ctl.sh" ] || die "Public root is not an sx-ctl repo. Set SX_PUBLIC_ROOT."
  [ -f "$PUBLIC_MANIFEST" ] || die "Public manifest not found: $PUBLIC_MANIFEST"
}

choose_tool() {
  entries_file=$(make_temp_file) || die "Could not create temporary file."

  awk -F '|' 'NR > 1 && $2 == "public" {
    print $1 "|" $3 "|" $4 "|" $5
  }' "$PUBLIC_MANIFEST" >"$entries_file"

  [ -s "$entries_file" ] || {
    rm -f "$entries_file"
    die "No public tools found."
  }

  echo "Wähle ein Public Tool zum Löschen:" >&2
  echo >&2

  count=0
  while IFS='|' read -r id category label path; do
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
  while IFS='|' read -r id category label path; do
    count=$((count + 1))
    if [ "$count" -eq "$choice" ] 2>/dev/null; then
      selected="$id|$path"
      break
    fi
  done <"$entries_file"

  rm -f "$entries_file"

  [ -n "$selected" ] || die "Selection out of range."
  printf '%s\n' "$selected"
}

main() {
  need_cmd awk
  need_cmd rm
  ensure_public_root

  selected=$(choose_tool)
  tool_id=$(printf '%s\n' "$selected" | cut -d '|' -f 1)
  path=$(printf '%s\n' "$selected" | cut -d '|' -f 2)
  script_file="$PUBLIC_ROOT/$path"

  echo
  echo "This will delete:"
  echo "  Tool: $tool_id"
  echo "  File: $script_file"
  echo
  printf '%s' "Type 'yes' to continue: " >&2
  IFS= read -r answer

  if [ "$answer" != "yes" ]; then
    echo "Aborted."
    return 0
  fi

  if [ -f "$script_file" ]; then
    rm -f "$script_file"
  fi

  tmp_manifest=$(make_temp_file) || die "Could not create temporary file."

  awk -F '|' -v tool_id="$tool_id" '
    NR == 1 { print; next }
    $1 != tool_id { print }
  ' "$PUBLIC_MANIFEST" >"$tmp_manifest"

  mv "$tmp_manifest" "$PUBLIC_MANIFEST"

  echo
  echo "Public script deleted:"
  echo "  $tool_id"
}

main "$@"
