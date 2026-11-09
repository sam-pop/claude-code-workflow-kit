#!/usr/bin/env bash
# Check stamp: remembers the working tree on which `scripts/check.sh all` last passed, so the Stop
# hook can say when files changed after the last passing run.
# Usage: scripts/check-stamp.sh <tree | record <tree> | hook>
#   tree           print a fingerprint of the working tree (tracked and untracked, non-ignored files;
#                  docs/reviews/ left out). It does not depend on commits: committing changes nothing.
#   record <tree>  save "<tree> <UTC date>" as the last passing run, in
#                  $(git rev-parse --git-path kit/check-passed) (per worktree, never committed)
#   hook           Stop hook: prints {"systemMessage": ...} naming the changed files when the tree
#                  differs from both HEAD and the last passing run; silent otherwise
# Exit codes: tree and record 0 ok, 1 failed; hook always 0 and silent on its own errors.
# The hook stays quiet until the kit is tailored (scripts/check.sh has no NOT CONFIGURED check and
# calls check-stamp), outside a git repo, and without python3.
set -uo pipefail
unset GIT_INDEX_FILE

tree() {
  local idx tmp out
  idx=$(git rev-parse --git-path index) || return 1
  tmp=$(mktemp -d) || return 1
  # A copy of the real index keeps git's stat cache, so only modified files are hashed again.
  [[ -f "$idx" ]] && cp "$idx" "$tmp/index"
  if GIT_INDEX_FILE="$tmp/index" git -c core.hooksPath=/dev/null -c filter.lfs.clean= -c filter.lfs.process= \
    -c filter.lfs.required=false add -A -- . ':(exclude)docs/reviews' >/dev/null 2>&1; then
    out=$(GIT_INDEX_FILE="$tmp/index" git write-tree 2>/dev/null)
  fi
  rm -rf "$tmp"
  [[ -n "${out:-}" ]] || return 1
  echo "$out"
}

stamp_path() { git rev-parse --git-path kit/check-passed; }

record() {
  local p
  [[ "${1:-}" =~ ^[0-9a-f]{40,64}$ ]] || {
    echo "check-stamp: record needs a tree id" >&2
    return 1
  }
  p=$(stamp_path) || return 1
  mkdir -p "$(dirname "$p")" || return 1
  echo "$1 $(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$p"
}

list() { # at most 8 paths, comma-separated, then (+N more)
  awk 'NF { n++; if (n <= 8) out = out (n > 1 ? ", " : "") $0 }
    END { if (n > 8) out = out " (+" (n - 8) " more)"; print out }'
}

hook() {
  local now head st="" p files msg
  cat >/dev/null
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  [[ -f scripts/check.sh ]] || return 0
  grep -qE '^[[:space:]]*not_configured "' scripts/check.sh && return 0
  grep -q 'check-stamp' scripts/check.sh || return 0
  command -v python3 >/dev/null || return 0
  now=$(tree) || return 0
  head=$(git rev-parse -q --verify 'HEAD^{tree}' 2>/dev/null) || head=""
  [[ "$now" == "$head" ]] && return 0
  p=$(stamp_path) || return 0
  [[ -f "$p" ]] && st=$(awk '{print $1; exit}' "$p")
  [[ -n "$st" && "$now" == "$st" ]] && return 0
  if [[ -n "$st" ]] && git cat-file -e "$st^{tree}" 2>/dev/null; then
    files=$(git -c core.hooksPath=/dev/null diff --no-ext-diff --no-renames --name-only "$st" "$now" 2>/dev/null | list) || return 0
    msg="scripts/check.sh all has not passed since these changes: $files"
  else
    [[ -n "$head" ]] || return 0
    files=$(git -c core.hooksPath=/dev/null diff --no-ext-diff --no-renames --name-only "$head" "$now" 2>/dev/null | list) || return 0
    msg="scripts/check.sh all: no passing run recorded for these changes: $files"
  fi
  [[ -n "$files" ]] || return 0
  python3 -c 'import json, sys; print(json.dumps({"systemMessage": sys.argv[1]}))' "$msg" 2>/dev/null
  return 0
}

case "${1:-}" in
  tree)
    cd "$(dirname "$0")/.." || exit 1
    tree
    ;;
  record)
    cd "$(dirname "$0")/.." || exit 1
    record "${2:-}"
    ;;
  hook)
    cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" 2>/dev/null || exit 0
    hook 2>/dev/null
    exit 0
    ;;
  *)
    sed -n '4,4p' "$0" >&2
    exit 2
    ;;
esac
