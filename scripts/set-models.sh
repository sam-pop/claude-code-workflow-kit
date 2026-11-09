#!/usr/bin/env bash
# Switch every agent to a model profile.
# Usage: scripts/set-models.sh <lite|standard|max>   (profiles extra: scripts/extras.sh on profiles)
#
#             planner      writer        reviewer     security-auditor
#   lite      sonnet/high  sonnet/high   sonnet/high  opus/high
#   standard  opus/high    opus/medium   opus/high    opus/xhigh
#   max       fable/high   opus/medium   opus/high    fable/high
#
#   lite is for Pro ($20) plans; never set Sonnet below high (medium: -7 to -15 points). max is experimental.
#   Cross-model review (Codex) is its own extra: scripts/extras.sh on codex
#
# max is a hypothesis, not a measured gain: no comparative Fable-vs-Opus data exists for planning or
# security auditing (only within-model effort deltas), and Fable barely gains from effort.
# Exit codes: 0 ok, 1 run from .claude/optional/ (the extra is off), 2 usage (--cross included).
# Each line is model/effort. Aliases track the latest model of each family. Fable bills usage credits on
# some plans; interactive sessions ask first, `claude -p` and SDK runs do not (see docs/rollout.md).
# The writer's effort is the first rung of the escalation ladder (docs/rollout.md, Extras, profiles).
# Also warns on a Claude Code older than 2.1.292 (no per-call Agent effort, so no ladder or risk tiers)
# and on effortLevel in ~/.claude/settings.json, and notes Fable billing on the max profile.
set -euo pipefail
case "$(basename "$(cd "$(dirname "$0")" && pwd)")" in
  scripts) ;;
  *)
    echo "the profiles extra is off: run scripts/extras.sh on profiles, then scripts/set-models.sh <profile>" >&2
    exit 1
    ;;
esac
cd "$(dirname "$0")/.."
profile=""
for a in "$@"; do
  case "$a" in
    lite | standard | max)
      [[ -z "$profile" ]] || {
        sed -n '2,11p' "$0"
        exit 2
      }
      profile="$a"
      ;;
    --cross)
      echo "cross-model review: scripts/extras.sh on codex" >&2
      exit 2
      ;;
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

echo "profile: $profile. Record the profile in docs/decisions.md."
if command -v claude >/dev/null; then
  cv=$(claude --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1) || cv=""
  if [[ -n "$cv" ]] && python3 -c 'import sys; sys.exit(0 if tuple(map(int, sys.argv[1].split("."))) < (2, 1, 292) else 1)' "$cv"; then
    echo "warn: Claude Code $cv is older than 2.1.292: Agent tool per-call effort unavailable; ladder and risk tiers won't apply"
  fi
fi
if [[ -f "$HOME/.claude/settings.json" ]] && grep -q '"effortLevel"' "$HOME/.claude/settings.json"; then
  echo "warn: effortLevel in ~/.claude/settings.json is ignored for Opus 5.5; use modelSettings or /effort"
fi
if [[ "$profile" == max ]]; then
  echo "note: max uses model: fable. Fable bills usage credits on Pro and standard Team plans from the first request; \`claude -p\` bills without asking; background and Remote sessions drop the turn after 5 minutes waiting for consent. Set a cap in /usage-credits."
fi
