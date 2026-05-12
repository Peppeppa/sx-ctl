#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl quality checks
#
# Runs syntax checks, ShellCheck if available and smoke tests.
# ============================================================

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$ROOT_DIR"

echo "sx-ctl quality checks"
echo "====================="
echo

echo "Syntax checks"
echo "-------------"

sh -n sx-ctl.sh
sh -n sx-ctl-basic.sh
sh -n install.sh
sh -n uninstall.sh
sh -n lib/core.sh

if [ -f lib/private.sh ]; then
  sh -n lib/private.sh
fi

find scripts -type f -name '*.sh' -exec sh -n {} \;
find templates -type f -name '*.sh' -exec sh -n {} \;
sh -n tests/smoke.sh

echo "OK: syntax checks passed"
echo

if command -v shellcheck >/dev/null 2>&1; then
  echo "ShellCheck"
  echo "----------"

  shellcheck sx-ctl.sh
  shellcheck sx-ctl-basic.sh
  shellcheck install.sh
  shellcheck uninstall.sh
  shellcheck lib/core.sh

  if [ -f lib/private.sh ]; then
    shellcheck lib/private.sh
  fi

  find scripts -type f -name '*.sh' -exec shellcheck {} +
  find templates -type f -name '*.sh' -exec shellcheck {} +
  shellcheck tests/smoke.sh

  echo "OK: ShellCheck passed"
else
  echo "ShellCheck"
  echo "----------"
  echo "SKIP: shellcheck not installed"
fi

echo
echo "Smoke tests"
echo "-----------"

sh tests/smoke.sh
