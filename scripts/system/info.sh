#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl script
# ID:          system.info
# Name:        Systeminformationen
# Description: Zeigt grundlegende Systeminformationen an
# Dependencies: sh, uname, df
# Risk:        low
# ============================================================

main() {
  echo "Systeminformationen"
  echo "==================="
  echo

  echo "Hostname:"
  hostname 2>/dev/null || echo "Nicht verfügbar"
  echo

  echo "Kernel / OS:"
  uname -a
  echo

  echo "Speicherplatz:"
  df -h
}

main "$@"
