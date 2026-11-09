#!/usr/bin/env bash
# Switch every agent to a model profile.
# Usage: scripts/set-models.sh <lite|standard|max> [--cross]
#
#             planner      writer        reviewer     security-auditor
#   lite      sonnet/high  sonnet/high   sonnet/high  opus/high
#   standard  opus/high    opus/medium   opus/high    opus/xhigh
#   max       fable/high   opus/medium   opus/high    fable/high
#
#   lite is for Pro ($20) plans; never set Sonnet below high (medium drops ~15 points).
#   --cross: enable codex-reviewer (Codex second opinion, off by default)
#
# Each line is model/effort. Aliases track the latest model of each family. Fable bills usage credits on
# some plans; interactive sessions ask first, `claude -p` and SDK runs do not (see docs/rollout.md).
# The writer's effort is the first rung of the escalation ladder in CLAUDE.md (Workflow).
set -euo pipefail
cd "$(dirname "$0")/.."
profile=""
cross=0
for a in "$@"; do
  case "$a" in
    lite | standard | max)
      [[ -z "$profile" ]] || {
        sed -n '2,11p' "$0"
        exit 2
      }
      profile="$a"
      ;;
    --cross) cross=1 ;;
    *)
      sed -n '2,11p' "$0"
      exit 2
      ;;
  esac
done
case "$profile" in
  lite)
    planner=sonnet/high
    writer=sonnet/high
    reviewer=sonnet/high
    auditor=opus/high
    ;;
  standard)
    planner=opus/high
    writer=opus/medium
    reviewer=opus/high
    auditor=opus/xhigh
    ;;
  max)
    planner=fable/high
    writer=opus/medium
    reviewer=opus/high
    auditor=fable/high
    ;;
  *)
    sed -n '2,11p' "$0"
    exit 2
    ;;
esac

# codex-reviewer is on when its file is in .claude/agents/, off when it is in .claude/optional/.
# Either way the file is moved, never deleted, so edits to it survive.
on=.claude/agents/codex-reviewer.md
off=.claude/optional/codex-reviewer.md
if [[ $cross -eq 1 && ! -f "$off" && ! -f "$on" ]]; then
  echo "error: --cross needs $off (or $on); neither exists. Re-install it from the kit." >&2
  exit 1
fi

set_model() { # file model/effort
  [[ -f "$1" ]] || return 0
  python3 - "$1" "${2%/*}" "${2#*/}" <<'PY'
import re, sys
path, model, effort = sys.argv[1:4]
raw = open(path, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
text = raw.replace("\r\n", "\n") if crlf else raw
head, sep, body = text.partition("\n---\n")
lines = [l for l in head.split("\n") if not re.match(r"effort:", l)]
if any(re.match(r"model:", l) for l in lines):
    lines = [f"model: {model}" if re.match(r"model:", l) else l for l in lines]
else:
    lines.append(f"model: {model}")
i = next(n for n, l in enumerate(lines) if l.startswith("model:"))
lines.insert(i + 1, f"effort: {effort}")
out = "\n".join(lines) + sep + body
open(path, "w", encoding="utf-8", newline="").write(out.replace("\n", "\r\n") if crlf else out)
PY
  echo "$(basename "$1" .md): $2"
}

set_model .claude/agents/planner.md "$planner"
set_model .claude/agents/writer.md "$writer"
set_model .claude/agents/reviewer.md "$reviewer"
set_model .claude/agents/security-auditor.md "$auditor"

if [[ $cross -eq 1 ]]; then
  if [[ -f "$off" && ! -f "$on" ]]; then mv "$off" "$on"; fi
  command -v codex >/dev/null || echo "warn: Codex CLI not installed (see https://learn.chatgpt.com/docs/non-interactive-mode)"
elif [[ -f "$on" ]]; then
  mkdir -p .claude/optional
  mv -f "$on" "$off"
fi
if [[ -f "$on" ]]; then echo "cross-model review: on"; else echo "cross-model review: off"; fi
echo "profile: $profile. Record the profile in docs/decisions.md."
if [[ -f "$on" ]]; then
  echo "Codex sees each High-risk diff and the release range, which leave for OpenAI. On client work, get the client's OK first and record it. Not available on Review-only."
fi
