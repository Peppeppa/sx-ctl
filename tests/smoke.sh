#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl smoke tests
#
# Minimal test script without external test framework.
# Run from repository root:
#
#   sh tests/smoke.sh
# ============================================================

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SX_CTL="$ROOT_DIR/sx-ctl.sh"

TMP_PRIVATE_ROOT="$ROOT_DIR/.tmp-smoke-private"

PASS=0
FAIL=0

log() {
  printf '%s\n' "$*"
}

pass() {
  PASS=$((PASS + 1))
  printf '%s\n' "PASS: $*"
}

fail() {
  FAIL=$((FAIL + 1))
  printf '%s\n' "FAIL: $*"
}

run_test() {
  name=$1
  shift

  if "$@" >/tmp/sx-ctl-smoke.out 2>/tmp/sx-ctl-smoke.err; then
    pass "$name"
    return 0
  fi

  fail "$name"
  printf '%s\n' "stdout:"
  sed 's/^/  /' /tmp/sx-ctl-smoke.out 2>/dev/null || true
  printf '%s\n' "stderr:"
  sed 's/^/  /' /tmp/sx-ctl-smoke.err 2>/dev/null || true
  return 1
}

cleanup() {
  rm -rf "$TMP_PRIVATE_ROOT"
  rm -f /tmp/sx-ctl-smoke.out /tmp/sx-ctl-smoke.err
}

trap cleanup EXIT HUP INT TERM

assert_contains() {
  name=$1
  needle=$2
  file=$3

  if grep "$needle" "$file" >/dev/null 2>&1; then
    pass "$name"
    return 0
  fi

  fail "$name"
  printf '%s\n' "Expected to find:"
  printf '%s\n' "  $needle"
  printf '%s\n' "In file:"
  printf '%s\n' "  $file"
  printf '%s\n' "Actual content:"
  sed 's/^/  /' "$file" 2>/dev/null || true
  return 1
}

syntax_checks() {
  log
  log "Syntax checks"
  log "-------------"

  run_test "syntax sx-ctl.sh" sh -n "$ROOT_DIR/sx-ctl.sh" || true
  run_test "syntax sx-ctl-basic.sh" sh -n "$ROOT_DIR/sx-ctl-basic.sh" || true
  run_test "syntax install.sh" sh -n "$ROOT_DIR/install.sh" || true
  run_test "syntax uninstall.sh" sh -n "$ROOT_DIR/uninstall.sh" || true
  run_test "syntax lib/core.sh" sh -n "$ROOT_DIR/lib/core.sh" || true

  for file in "$ROOT_DIR"/scripts/*/*.sh; do
    [ -f "$file" ] || continue
    run_test "syntax ${file#$ROOT_DIR/}" sh -n "$file" || true
  done

  if [ -f "$ROOT_DIR/templates/script-template.sh" ]; then
    run_test "syntax templates/script-template.sh" sh -n "$ROOT_DIR/templates/script-template.sh" || true
  fi
}

basic_command_checks() {
  log
  log "Basic command checks"
  log "--------------------"

  run_test "sx-ctl help" "$SX_CTL" -h || true
  run_test "sx-ctl version" "$SX_CTL" -v || true
  run_test "sx-ctl compact list" "$SX_CTL" -ls || true
  run_test "sx-ctl detailed list" "$SX_CTL" -la || true
  run_test "sx-ctl validate manifest" "$SX_CTL" admin.validate-manifest || true
  run_test "sx-ctl doctor" "$SX_CTL" admin.doctor || true
}

public_script_checks() {
  log
  log "Public script checks"
  log "--------------------"

  run_test "run system.info" "$SX_CTL" system.info || true

  if run_test "run misc.hello with arg" "$SX_CTL" misc.hello SmokeTest; then
    assert_contains "misc.hello output contains argument" "SmokeTest" /tmp/sx-ctl-smoke.out || true
  fi
}

private_overlay_checks() {
  log
  log "Private overlay checks"
  log "----------------------"

  rm -rf "$TMP_PRIVATE_ROOT"

  run_test \
    "init temporary private overlay" \
    env SX_PRIVATE_ROOT="$TMP_PRIVATE_ROOT" "$SX_CTL" admin.private-init || true

  run_test \
    "temporary private status" \
    env SX_PRIVATE_ROOT="$TMP_PRIVATE_ROOT" "$SX_CTL" admin.private-status || true

  run_test \
    "temporary private appears in list" \
    env SX_PRIVATE_ROOT="$TMP_PRIVATE_ROOT" "$SX_CTL" -la || true

  if run_test \
    "run temporary private hello" \
    env SX_PRIVATE_ROOT="$TMP_PRIVATE_ROOT" "$SX_CTL" private.personal.hello SmokePrivate; then
    assert_contains "private hello output contains argument" "SmokePrivate" /tmp/sx-ctl-smoke.out || true
  fi

  run_test \
    "validate with temporary private overlay" \
    env SX_PRIVATE_ROOT="$TMP_PRIVATE_ROOT" "$SX_CTL" admin.validate-manifest || true
}

main() {
  cd "$ROOT_DIR"

  log "sx-ctl smoke tests"
  log "=================="
  log "Root: $ROOT_DIR"

  syntax_checks
  basic_command_checks
  public_script_checks
  private_overlay_checks

  log
  log "Summary"
  log "-------"
  log "Passed: $PASS"
  log "Failed: $FAIL"

  if [ "$FAIL" -ne 0 ]; then
    log
    log "Result: failed"
    return 1
  fi

  log
  log "Result: passed"
  return 0
}

main "$@"
