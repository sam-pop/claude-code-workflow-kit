#!/usr/bin/env bash
# Switch the kit's opt-in extras on and off, and say which are on.
# Usage: scripts/extras.sh <status | on <name> | off <name>>
#   status   one line per extra (<name>: on | off | not installed), then a warn: line for each
#            extra with a copy in both places, codex on without the codex CLI, and CODEX_API_KEY in
#            a workflow
#   on, off  move the extra's file between .claude/optional/ (off) and its active path (on:
#            .claude/agents/<file>.md, scripts/<file>.sh)
# Extras (docs/rollout.md, Extras), one file each:
#   codex          .claude/agents/codex-reviewer.md
#   profiles       scripts/set-models.sh
#   verify-review  scripts/verify-review.sh
#   metrics        scripts/review-stats.sh
# An extra is on when its file is at its active path; core scripts call an extra's script only when
# it is there. Files are moved, never deleted, so edits to them survive. Nothing here edits
# .claude/settings.json or scripts/check.sh. stop-warning was retired in 1.8: `on` refuses (exit 1)
# and `off` has nothing to do (exit 0); a repo's own check-stamp.sh, Stop hook and stamp lines are
# left as they are.
# Environment: KIT_EXTRAS_REPO, the repo to act on (default: this script's parent directory);
# CLAUDE_PROJECT_DIR is for hooks and is ignored.
# Exit codes: 0 ok (status: no warnings), 1 refused or failed (status: warnings), 2 usage or unknown extra.
set -uo pipefail
cd "${KIT_EXTRAS_REPO:-$(dirname "$0")/..}" || exit 1
EXTRAS="codex profiles verify-review metrics"

usage() {
  sed -n '3p' "$0" | sed 's/^# //' >&2
  echo "extras: $EXTRAS" >&2
  exit 2
}

# The extra's file.
file_of() {
  case "$1" in
    codex) echo codex-reviewer.md ;;
    profiles) echo set-models.sh ;;
    verify-review) echo verify-review.sh ;;
    metrics) echo review-stats.sh ;;
    *) return 1 ;;
  esac
}

dormant() { echo ".claude/optional/$1"; }
active() { case "$1" in *.md) echo ".claude/agents/$1" ;; *) echo "scripts/$1" ;; esac }
there() { [[ -e "$1" || -L "$1" ]]; }
where() { # on | off | both | none
  local a d
  a=$(active "$1")
  d=$(dormant "$1")
  if there "$a" && there "$d"; then
    echo both
  elif there "$a"; then
    echo on
  elif there "$d"; then
    echo off
  else
    echo none
  fi
}

# Real location inside the repo (a symlinked directory on the way may lead out of it).
inside() {
  python3 -I -c 'import os, sys
r, t = os.path.realpath(sys.argv[1]), os.path.realpath(".")
sys.exit(0 if r == t or r.startswith(t + os.sep) else 1)' "$1"
}

move() { # from to
  mkdir -p "$(dirname "$2")" && mv "$1" "$2" && echo "moved: $1 -> $2"
}

switch() { # on|off name
  local want=$1 x=$2 f st src dst moving
  if [[ "$x" == stop-warning ]]; then
    echo "stop-warning was retired in 1.8: nothing to switch. Its files (scripts/check-stamp.sh, the Stop hook in .claude/settings.json, the stamp lines in scripts/check.sh) are yours to keep or delete."
    [[ "$want" == off ]]
    return
  fi
  f=$(file_of "$x") || {
    echo "unknown extra: $x" >&2
    usage
  }
  st=$(where "$f")
  if [[ "$st" == none ]]; then
    if [[ "$want" == on ]]; then
      echo "refused: $x is not installed ($(dormant "$f") is missing); re-install it from the kit (scripts/install.sh --upgrade)" >&2
      return 1
    fi
    echo "$x: not installed"
    return 0
  fi
  if [[ "$st" == both ]]; then
    echo "refused: both $(dormant "$f") and $(active "$f") exist; keep one, then run this again" >&2
    return 1
  fi
  if [[ "$st" != "$want" ]]; then
    if [[ "$want" == on ]]; then
      src=$(dormant "$f")
      dst=$(active "$f")
    else
      src=$(active "$f")
      dst=$(dormant "$f")
    fi
    for moving in "$src" "$dst"; do
      if ! inside "$moving"; then
        echo "refused: $moving resolves outside the repo (a symlink on the way?)" >&2
        return 1
      fi
    done
    move "$src" "$dst" || return 1
  else
    echo "$x was already $want"
  fi
  echo "$x: $want. Record it in docs/decisions.md."
  if [[ "$want" == on && "$x" == codex ]]; then
    command -v codex >/dev/null || echo "warn: Codex CLI not installed (see https://learn.chatgpt.com/docs/non-interactive-mode)"
    echo "Codex sees each High-risk diff and the release range, which leave for OpenAI. On client work, get the client's OK first and record it. Not available on Review-only."
  fi
  return 0
}

status() {
  local x f st n=0
  for x in $EXTRAS; do
    f=$(file_of "$x")
    st=$(where "$f")
    case "$st" in
      on | both) echo "$x: on" ;;
      off) echo "$x: off" ;;
      *) echo "$x: not installed" ;;
    esac
  done
  for x in $EXTRAS; do
    f=$(file_of "$x")
    if [[ $(where "$f") == both ]]; then
      echo "warn: $x: both $(dormant "$f") and $(active "$f") exist; keep one"
      n=$((n + 1))
    fi
  done
  if [[ $(where codex-reviewer.md) != off && $(where codex-reviewer.md) != none ]] && ! command -v codex >/dev/null; then
    echo "warn: codex is on but the codex CLI is not installed"
    n=$((n + 1))
  fi
  if compgen -G ".github/workflows/*.y*ml" >/dev/null && grep -lE 'CODEX_API_KEY' .github/workflows/*.y*ml >/dev/null 2>&1; then
    echo "warn: CODEX_API_KEY in .github/workflows: OpenAI warns against a job-level CODEX_API_KEY where repo code runs"
    n=$((n + 1))
  fi
  ((n == 0))
}

command -v python3 >/dev/null || {
  echo "extras.sh: python3 is required" >&2
  exit 1
}
case "${1:-}" in
  status)
    [[ $# -eq 1 ]] || usage
    status
    ;;
  on | off)
    [[ $# -eq 2 ]] || usage
    switch "$1" "$2"
    ;;
  *) usage ;;
esac
