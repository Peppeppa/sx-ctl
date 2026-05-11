#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# sx-ctl script
# ID:          misc.hello
# Name:        Hello Demo
# Description: Ein simples Bash-Testscript
# Dependencies: bash
# Risk:        low
# ============================================================

main() {
  local name="${1:-sx-ctl}"

  echo "Hello from $name!"
  echo "This script is running with Bash."
}

main "$@"
