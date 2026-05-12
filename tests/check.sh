#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl quality checks
#
# Run from repository root:
#
#   sh tests/check.sh
#
# This script runs:
# - syntax checks
# - manifest-aware script syntax checks
# - ShellCheck if available
# - smoke tests
# ============================================================

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$ROOT_DIR"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf '%s\n' "PASS: $*"
}

fail() {
  FAIL=$((FAIL + 1))
  printf '%s\n' "FAIL: $*" >&2
}

section() {
  printf '\n'
  printf '%s\n' "$1"
  printf '%s\n' "------------------------"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_file_exists() {
  file=$1

  if [ -f "$file" ]; then
    pass "file exists: $file"
    return 0
  fi

  fail "file missing: $file"
  return 1
}

syntax_sh() {
  file=$1

  if sh -n "$file"; then
    pass "sh syntax: $file"
    return 0
  fi

  fail "sh syntax: $file"
  return 1
}

syntax_bash() {
  file=$1

  if ! have_cmd bash; then
    fail "bash not found for syntax check: $file"
    return 1
  fi

  if bash -n "$file"; then
    pass "bash syntax: $file"
    return 0
  fi

  fail "bash syntax: $file"
  return 1
}

syntax_by_shell() {
  shell_name=$1
  file=$2

  case "$shell_name" in
  sh)
    syntax_sh "$file"
    ;;
  bash)
    syntax_bash "$file"
    ;;
  *)
    fail "unsupported shell '$shell_name' for syntax check: $file"
    return 1
    ;;
  esac
}

check_core_syntax() {
  section "Core syntax checks"

  syntax_sh "sx-ctl.sh" || true
  syntax_sh "sx-ctl-basic.sh" || true
  syntax_sh "install.sh" || true
  syntax_sh "uninstall.sh" || true
  syntax_sh "lib/core.sh" || true

  if [ -f "lib/private.sh" ]; then
    syntax_sh "lib/private.sh" || true
  fi
}

check_manifest_script_syntax() {
  section "Manifest script syntax checks"

  if [ ! -f "manifest.txt" ]; then
    fail "manifest.txt missing"
    return 1
  fi

  line_no=0

  while IFS='|' read -r id source category label path description shell_name deps risk || [ -n "$id$source$category$label$path$description$shell_name$deps$risk" ]; do
    line_no=$((line_no + 1))

    if [ "$line_no" -eq 1 ]; then
      continue
    fi

    [ -z "$id" ] && continue

    if [ "$source" != "public" ]; then
      continue
    fi

    if [ -z "$path" ]; then
      fail "manifest line $line_no has empty path for tool $id"
      continue
    fi

    if ! check_file_exists "$path"; then
      continue
    fi

    syntax_by_shell "$shell_name" "$path" || true
  done <"manifest.txt"
}

check_unregistered_script_syntax() {
  section "Unregistered script syntax checks"

  registered_file="${TMPDIR:-/tmp}/sx-ctl-registered.$$"
  all_scripts_file="${TMPDIR:-/tmp}/sx-ctl-all-scripts.$$"

  : >"$registered_file"
  : >"$all_scripts_file"

  awk -F '|' 'NR > 1 && $2 == "public" { print $5 }' manifest.txt >"$registered_file"
  find scripts -type f -name '*.sh' | sort >"$all_scripts_file"

  while IFS= read -r script_file || [ -n "$script_file" ]; do
    [ -n "$script_file" ] || continue

    if grep "^$script_file$" "$registered_file" >/dev/null 2>&1; then
      continue
    fi

    syntax_sh "$script_file" || true
  done <"$all_scripts_file"

  rm -f "$registered_file" "$all_scripts_file"
}

check_templates_syntax() {
  section "Template syntax checks"

  if [ ! -d "templates" ]; then
    pass "templates directory not present"
    return 0
  fi

  found=0

  for file in templates/*.sh; do
    [ -f "$file" ] || continue
    found=1
    syntax_sh "$file" || true
  done

  if [ "$found" -eq 0 ]; then
    pass "no shell templates found"
  fi
}

run_shellcheck() {
  section "ShellCheck"

  if ! have_cmd shellcheck; then
    printf '%s\n' "SKIP: shellcheck not installed"
    return 0
  fi

  shellcheck sx-ctl.sh && pass "shellcheck sx-ctl.sh" || fail "shellcheck sx-ctl.sh"
  shellcheck sx-ctl-basic.sh && pass "shellcheck sx-ctl-basic.sh" || fail "shellcheck sx-ctl-basic.sh"
  shellcheck install.sh && pass "shellcheck install.sh" || fail "shellcheck install.sh"
  shellcheck uninstall.sh && pass "shellcheck uninstall.sh" || fail "shellcheck uninstall.sh"
  shellcheck lib/core.sh && pass "shellcheck lib/core.sh" || fail "shellcheck lib/core.sh"

  if [ -f "lib/private.sh" ]; then
    shellcheck lib/private.sh && pass "shellcheck lib/private.sh" || fail "shellcheck lib/private.sh"
  fi

  find scripts -type f -name '*.sh' | sort | while IFS= read -r file; do
    shellcheck "$file" && pass "shellcheck $file" || fail "shellcheck $file"
  done

  if [ -d "templates" ]; then
    find templates -type f -name '*.sh' | sort | while IFS= read -r file; do
      shellcheck "$file" && pass "shellcheck $file" || fail "shellcheck $file"
    done
  fi

  shellcheck tests/smoke.sh && pass "shellcheck tests/smoke.sh" || fail "shellcheck tests/smoke.sh"
}

run_smoke_tests() {
  section "Smoke tests"

  if sh tests/smoke.sh; then
    pass "smoke tests"
    return 0
  fi

  fail "smoke tests"
  return 1
}

main() {
  printf '%s\n' "sx-ctl quality checks"
  printf '%s\n' "====================="
  printf '%s\n' "Root: $ROOT_DIR"

  check_core_syntax
  check_manifest_script_syntax
  check_unregistered_script_syntax
  check_templates_syntax
  run_shellcheck
  run_smoke_tests || true

  printf '\n'
  printf '%s\n' "Summary"
  printf '%s\n' "-------"
  printf 'Passed: %s\n' "$PASS"
  printf 'Failed: %s\n' "$FAIL"

  if [ "$FAIL" -ne 0 ]; then
    printf '\n'
    printf '%s\n' "Result: failed"
    return 1
  fi

  printf '\n'
  printf '%s\n' "Result: passed"
  return 0
}

main "$@"
