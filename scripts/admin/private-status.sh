#!/usr/bin/env sh
set -eu

# ============================================================
# sx-ctl public admin script
# ID:          admin.private-status
# Name:        Private Overlay Status
# Description: Zeigt Status des privaten Overlays an
# Dependencies: sh, git
# Risk:        low
# ============================================================

PRIVATE_ROOT="${SX_PRIVATE_ROOT:-$HOME/.config/sx-ctl/overlays/private}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

print_yes_no_file() {
  label=$1
  path=$2

  if [ -f "$path" ]; then
    printf '  %-14s yes\n' "$label:"
  else
    printf '  %-14s no\n' "$label:"
  fi
}

main() {
  echo "Private Overlay Status"
  echo "======================"
  echo
  echo "Root:"
  echo "  $PRIVATE_ROOT"
  echo

  if [ ! -e "$PRIVATE_ROOT" ]; then
    echo "Status:"
    echo "  Private overlay does not exist."
    echo
    echo "Create it with:"
    echo "  sx-ctl admin.private-init"
    echo
    echo "Or clone an existing private repository with:"
    echo "  sx-ctl admin.private-clone <git-ssh-url>"
    return 0
  fi

  if [ ! -d "$PRIVATE_ROOT" ]; then
    echo "Status:"
    echo "  Path exists, but is not a directory."
    return 1
  fi

  echo "Files:"
  print_yes_no_file "manifest.txt" "$PRIVATE_ROOT/manifest.txt"
  print_yes_no_file "env" "$PRIVATE_ROOT/env"
  echo

  echo "Directories:"
  if [ -d "$PRIVATE_ROOT/scripts" ]; then
    echo "  scripts:       yes"
  else
    echo "  scripts:       no"
  fi

  if [ -d "$PRIVATE_ROOT/templates" ]; then
    echo "  templates:     yes"
  else
    echo "  templates:     no"
  fi

  echo

  echo "Git:"
  if [ -d "$PRIVATE_ROOT/.git" ]; then
    echo "  repository:    yes"

    if have_cmd git; then
      (
        cd "$PRIVATE_ROOT"

        remote="$(git remote get-url origin 2>/dev/null || true)"
        branch="$(git branch --show-current 2>/dev/null || true)"

        if [ -n "$remote" ]; then
          echo "  remote:        $remote"
        else
          echo "  remote:        none"
        fi

        if [ -n "$branch" ]; then
          echo "  branch:        $branch"
        else
          echo "  branch:        unknown"
        fi

        if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
          echo "  changes:       clean"
        else
          echo "  changes:       uncommitted"
        fi
      )
    else
      echo "  git command:   missing"
    fi
  else
    echo "  repository:    no"
  fi

  echo

  echo "Registered private tools:"
  if [ -f "$PRIVATE_ROOT/manifest.txt" ]; then
    awk -F '|' '
      NR > 1 && $2 == "private" {
        printf "  %s (%s)\n", $1, $3
        found = 1
      }
      END {
        if (found != 1) {
          print "  none"
        }
      }
    ' "$PRIVATE_ROOT/manifest.txt"
  else
    echo "  none"
  fi
}

main "$@"
