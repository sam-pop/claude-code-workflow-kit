#!/usr/bin/env bash
# Switch the kit's opt-in extras on and off, and say which are on.
# Usage: scripts/extras.sh <status | on <name> | off <name> | sync>
#   status   one line per extra (<name>: on | off | not installed), then a warn: line for each
#            half-enabled extra, a hook left behind, codex on without the codex CLI, and
#            CODEX_API_KEY in a workflow
#   on, off  move the extra's files between .claude/optional/ (off) and their active paths (on:
#            .claude/agents/<file>.md, scripts/<file>.sh), and add or remove its hook
#   sync     make every extra follow its first file: the rest of its files and its hook go on when
#            that file is active and off when it is dormant; when it is in neither place, only a hook
#            whose script is missing is removed (scripts/install.sh --upgrade runs this)
# Extras (docs/rollout.md, Extras):
#   codex          .claude/agents/codex-reviewer.md
#   profiles       scripts/set-models.sh, scripts/stuck-detect.sh and its line in scripts/check.sh
#   stop-warning   scripts/check-stamp.sh, a Stop hook, and the stamp lines in scripts/check.sh
#   verify-review  scripts/verify-review.sh
#   metrics        scripts/review-stats.sh
# An extra is on when its files are at their active paths; core scripts call an extra's script only
# when it is there. Files are moved, never deleted, so edits to them survive. Only the kit's own hook
# entry in .claude/settings.json is added or removed: the rest of the file is kept, but re-written with
# 2-space indentation. A tailored scripts/check.sh is never edited; status warns about a missing line.
# Environment: KIT_EXTRAS_REPO, the repo to act on (default: this script's parent directory). scripts/install.sh
# sets it to run the kit's copy of this script against a target; CLAUDE_PROJECT_DIR is for hooks and is ignored.
# Exit codes: 0 ok (status: no warnings), 1 refused or failed (status: warnings), 2 usage or unknown extra.
set -uo pipefail
cd "${KIT_EXTRAS_REPO:-$(dirname "$0")/..}" || exit 1
EXTRAS="codex profiles stop-warning verify-review metrics"
SETTINGS=.claude/settings.json

usage() {
  sed -n '3p' "$0" | sed 's/^# //' >&2
  echo "extras: $EXTRAS" >&2
  exit 2
}

# The extra's files, the first one deciding whether it is on.
files_of() {
  case "$1" in
    codex) echo codex-reviewer.md ;;
    profiles) echo set-models.sh stuck-detect.sh ;;
    stop-warning) echo check-stamp.sh ;;
    verify-review) echo verify-review.sh ;;
    metrics) echo review-stats.sh ;;
    *) return 1 ;;
  esac
}
# The extra's hook: event, script, argument, timeout.
hook_of() {
  case "$1" in
    stop-warning) echo "Stop check-stamp.sh hook 30" ;;
  esac
}
# A non-comment line scripts/check.sh needs while the extra is on: what it runs.
checkline_of() {
  case "$1" in
    profiles) echo 'scripts/stuck-detect.sh' ;;
    stop-warning) echo 'scripts/check-stamp.sh record' ;;
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
first() { echo "$1"; }

# Real location inside the repo (a symlinked directory on the way may lead out of it).
inside() {
  python3 -c 'import os, sys
r, t = os.path.realpath(sys.argv[1]), os.path.realpath(".")
sys.exit(0 if r == t or r.startswith(t + os.sep) else 1)' "$1"
}

# hooks <has|add|remove> <script> [<event> <argument> <timeout>]
# has: 0 present, 1 absent. add: 0 added, 1 already there. remove: 0 removed, 1 none there.
# Any: 3 settings.json missing, 4 not valid JSON or not the hooks layout, 5 its real path leaves the repo.
hooks() {
  python3 - "$SETTINGS" "$@" <<'PY'
import json, os, sys, tempfile
path, op, script = sys.argv[1:4]
if not os.path.isfile(path):
    sys.exit(3)
real, top = os.path.realpath(path), os.path.realpath(".")
if not real.startswith(top + os.sep):
    sys.exit(5)
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (OSError, ValueError):
    sys.exit(4)
if not isinstance(data, dict) or not isinstance(data.get("hooks", {}), dict):
    sys.exit(4)
for groups in data.get("hooks", {}).values():
    if not isinstance(groups, list) or not all(isinstance(g, dict) and isinstance(g.get("hooks", []), list) for g in groups):
        sys.exit(4)
needle = "scripts/" + script

def mine(h):
    return isinstance(h, dict) and needle in str(h.get("command", ""))

def present():
    return any(mine(h) for groups in data.get("hooks", {}).values() for g in groups for h in g.get("hooks", []))

def write():
    st = os.stat(path)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(real), prefix=".settings.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        os.chmod(tmp, st.st_mode & 0o7777)
        os.replace(tmp, real)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise

if op == "has":
    sys.exit(0 if present() else 1)
if op == "add":
    if present():
        sys.exit(1)
    event, arg, timeout = sys.argv[4:7]
    cmd = '"${CLAUDE_PROJECT_DIR}/scripts/' + script + '" ' + arg
    data.setdefault("hooks", {}).setdefault(event, []).append(
        {"hooks": [{"type": "command", "command": cmd, "timeout": int(timeout)}]})
    write()
    sys.exit(0)
if op == "remove":
    if not present():
        sys.exit(1)
    hooks = data["hooks"]
    for event in list(hooks):
        kept = []
        for g in hooks[event]:
            hs = g.get("hooks", [])
            left = [h for h in hs if not mine(h)]
            if hs and not left:
                continue  # a group that held only this hook goes with it
            if len(left) != len(hs):
                g["hooks"] = left
            kept.append(g)
        if hooks[event] and not kept:
            del hooks[event]
        else:
            hooks[event] = kept
    write()
    sys.exit(0)
sys.exit(2)
PY
}

hook_problem() { # rc of hooks -> message
  case "$1" in
    3) echo "$SETTINGS is missing" ;;
    4) echo "$SETTINGS is not valid JSON (or not the hooks layout)" ;;
    5) echo "$SETTINGS resolves outside the repo" ;;
    *) echo "editing $SETTINGS failed" ;;
  esac
}

move() { # from to
  mkdir -p "$(dirname "$2")" && mv "$1" "$2" && echo "moved: $1 -> $2"
}

switch() { # on|off name
  local want=$1 x=$2 files f p st h ev sc arg to rc changed=0 dst
  files=$(files_of "$x") || {
    echo "unknown extra: $x" >&2
    usage
  }
  # shellcheck disable=SC2086  # the file list splits on spaces on purpose
  p=$(first $files)
  st=$(where "$p")
  h=$(hook_of "$x")
  if [[ "$st" == none ]]; then
    if [[ "$want" == on ]]; then
      echo "refused: $x is not installed ($(dormant "$p") is missing); re-install it from the kit (scripts/install.sh --upgrade)" >&2
      return 1
    fi
    if [[ -n "$h" ]]; then
      read -r ev sc arg to <<<"$h"
      hooks remove "$sc" && echo "hook removed: $ev scripts/$sc ($SETTINGS)"
    fi
    echo "$x: not installed"
    return 0
  fi
  for f in $files; do
    if [[ $(where "$f") == both ]]; then
      echo "refused: both $(dormant "$f") and $(active "$f") exist; keep one, then run this again" >&2
      return 1
    fi
    if [[ "$want" == on ]]; then dst=$(active "$f"); else dst=$(dormant "$f"); fi
    if [[ $(where "$f") != "$want" && $(where "$f") != none ]] && ! inside "$dst"; then
      echo "refused: $dst resolves outside the repo (a symlink on the way?)" >&2
      return 1
    fi
  done
  if [[ -n "$h" ]]; then
    read -r ev sc arg to <<<"$h"
    hooks has "$sc"
    rc=$?
    if ((rc > 1)) && [[ "$want" == on || "$rc" != 3 ]]; then
      echo "refused: $(hook_problem "$rc"); nothing changed" >&2
      return 1
    fi
  fi
  for f in $files; do
    case "$want:$(where "$f")" in
      on:off)
        move "$(dormant "$f")" "$(active "$f")" || return 1
        changed=1
        ;;
      off:on)
        move "$(active "$f")" "$(dormant "$f")" || return 1
        changed=1
        ;;
      *:none) echo "warn: $f is missing from both $(dormant "$f") and $(active "$f"); re-install it from the kit" ;;
    esac
  done
  if [[ -n "$h" ]]; then
    if [[ "$want" == on ]]; then
      hooks add "$sc" "$ev" "$arg" "$to"
      rc=$?
      ((rc == 0)) && echo "hook added: $ev runs scripts/$sc $arg ($SETTINGS)" && changed=1
    else
      hooks remove "$sc"
      rc=$?
      ((rc == 0)) && echo "hook removed: $ev scripts/$sc ($SETTINGS)" && changed=1
    fi
    if ((rc > 1)) && [[ "$rc" != 3 || "$want" == on ]]; then
      echo "failed: $(hook_problem "$rc")" >&2
      return 1
    fi
  fi
  ((changed)) || echo "$x was already $want"
  echo "$x: $want. Record it in docs/decisions.md."
  if [[ "$want" == on ]]; then
    check_line "$x" || true
    if [[ "$x" == codex ]]; then
      command -v codex >/dev/null || echo "warn: Codex CLI not installed (see https://learn.chatgpt.com/docs/non-interactive-mode)"
      echo "Codex sees each High-risk diff and the release range, which leave for OpenAI. On client work, get the client's OK first and record it. Not available on Review-only."
    fi
  fi
  return 0
}

check_line() { # warn when scripts/check.sh lacks a line the extra needs
  local what
  what=$(checkline_of "$1")
  [[ -n "$what" ]] || return 0
  grep -qE "^[^#]*$what" scripts/check.sh 2>/dev/null && return 0
  echo "warn: $1 is on but scripts/check.sh does not run $what (a tailored check.sh: add it back; see scripts/check.sh in the kit)"
  return 1
}

sync() {
  local x files p st f h ev sc arg to rc fail=0
  for x in $EXTRAS; do
    files=$(files_of "$x")
    # shellcheck disable=SC2086  # the file list splits on spaces on purpose
    p=$(first $files)
    st=$(where "$p")
    h=$(hook_of "$x")
    if [[ "$st" == both ]]; then
      echo "warn: $x: both $(dormant "$p") and $(active "$p") exist; keep one, then run scripts/extras.sh sync" >&2
      fail=1
      continue
    fi
    for f in $files; do
      [[ "$f" == "$p" ]] && continue
      case "$st:$(where "$f")" in
        on:off)
          if inside "$(active "$f")"; then move "$(dormant "$f")" "$(active "$f")"; else
            echo "warn: $(active "$f") resolves outside the repo; not moved" >&2
            fail=1
          fi
          ;;
        off:on)
          if inside "$(dormant "$f")"; then move "$(active "$f")" "$(dormant "$f")"; else
            echo "warn: $(dormant "$f") resolves outside the repo; not moved" >&2
            fail=1
          fi
          ;;
        *:both)
          echo "warn: $x: both $(dormant "$f") and $(active "$f") exist; keep one" >&2
          fail=1
          ;;
      esac
    done
    [[ -n "$h" ]] || continue
    read -r ev sc arg to <<<"$h"
    if [[ "$st" == on ]]; then
      hooks add "$sc" "$ev" "$arg" "$to"
      rc=$?
      ((rc == 0)) && echo "hook added: $ev runs scripts/$sc $arg ($SETTINGS)"
    elif [[ "$st" == off ]] || ! there "scripts/$sc"; then
      hooks remove "$sc"
      rc=$?
      ((rc == 0)) && echo "hook removed: $ev scripts/$sc ($SETTINGS)"
      [[ "$rc" == 3 ]] && rc=1
    else
      rc=1
    fi
    if ((rc > 1)); then
      echo "warn: $x: $(hook_problem "$rc"); its hook was not changed" >&2
      fail=1
    fi
  done
  return $fail
}

status() {
  local x files p st f h ev sc arg to rc n=0 out
  for x in $EXTRAS; do
    files=$(files_of "$x")
    # shellcheck disable=SC2086  # the file list splits on spaces on purpose
    p=$(first $files)
    st=$(where "$p")
    case "$st" in
      on | both) echo "$x: on" ;;
      off) echo "$x: off" ;;
      *) echo "$x: not installed" ;;
    esac
  done
  for x in $EXTRAS; do
    files=$(files_of "$x")
    # shellcheck disable=SC2086  # the file list splits on spaces on purpose
    p=$(first $files)
    st=$(where "$p")
    for f in $files; do
      case "$st:$(where "$f")" in
        *:both) echo "warn: $x: both $(dormant "$f") and $(active "$f") exist; keep one" ;;
        on:off) echo "warn: $x is on but $(dormant "$f") is still off (run scripts/extras.sh sync)" ;;
        on:none) echo "warn: $x is on but $(active "$f") is missing; re-install it from the kit" ;;
        off:on) echo "warn: $x is off but $(active "$f") is on (run scripts/extras.sh sync)" ;;
        *) continue ;;
      esac
      n=$((n + 1))
    done
    h=$(hook_of "$x")
    if [[ -n "$h" ]]; then
      read -r ev sc arg to <<<"$h"
      hooks has "$sc"
      rc=$?
      if [[ "$rc" == 0 && "$st" != on && "$st" != both ]]; then
        echo "warn: $SETTINGS has a $ev hook for scripts/$sc but $x is off (run scripts/extras.sh sync)"
        n=$((n + 1))
      elif [[ "$rc" != 0 && ("$st" == on || "$st" == both) ]]; then
        if [[ "$rc" == 1 ]]; then
          echo "warn: $x is on but $SETTINGS has no $ev hook for scripts/$sc (run scripts/extras.sh sync)"
        else
          echo "warn: $x is on but $(hook_problem "$rc")"
        fi
        n=$((n + 1))
      fi
    fi
    if [[ "$st" == on || "$st" == both ]]; then
      out=$(check_line "$x") || {
        echo "$out"
        n=$((n + 1))
      }
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
  sync)
    [[ $# -eq 1 ]] || usage
    sync
    ;;
  on | off)
    [[ $# -eq 2 ]] || usage
    switch "$1" "$2"
    ;;
  *) usage ;;
esac
