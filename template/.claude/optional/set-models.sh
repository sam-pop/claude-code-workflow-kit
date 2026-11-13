#!/usr/bin/env bash
# Switch every agent to a model profile.
# Usage: scripts/set-models.sh <lite|standard|max> [--force]   (profiles extra: scripts/extras.sh on profiles)
#
#             planner      writer        reviewer     security-auditor
#   lite      sonnet/high  sonnet/high   opus/medium  opus/high
#   standard  opus/high    sonnet/high   opus/high    opus/xhigh
#   max       opus/high    opus/medium   fable/high   fable/high
#
#   The model that wrote the code never reviews it: writer and reviewer differ in every profile.
#   lite is for Pro ($20) plans; never set Sonnet below high (medium: -7 to -15 points). max is experimental.
#   Cross-model review (Codex) is its own extra: scripts/extras.sh on codex
#
# max is a hypothesis, not a measured gain: no comparative Fable-vs-Opus data exists for reviewing or
# security auditing (only within-model effort deltas), and Fable barely gains from effort.
# A seat whose model/effort is none of the profiles' values for that role was tailored by hand: the script
# refuses to overwrite it (exit 1, no file changed) and says role, current and target; --force overrides.
# Exit codes: 0 ok, 1 run from .claude/optional/ (the extra is off) or a tailored seat refused, 2 usage (--cross included).
# Each line is model/effort. Aliases track the latest model of each family. Fable bills usage credits on
# some plans; interactive sessions ask first, `claude -p` and SDK runs do not (see docs/rollout.md).
# The writer's effort is the first rung of the escalation ladder, which raises effort only and never
# changes the writer's model (docs/rollout.md, Extras, profiles).
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
force=0
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    lite | standard | max)
      [[ -z "$profile" ]] || {
        sed -n '2,12p' "$0"
        exit 2
      }
      profile="$a"
      ;;
    --cross)
      echo "cross-model review: scripts/extras.sh on codex" >&2
      exit 2
      ;;
    *)
      sed -n '2,12p' "$0"
      exit 2
      ;;
  esac
done
# The profile table: planner writer reviewer security-auditor, as model/effort.
profile_values() {
  case "$1" in
    lite) echo "sonnet/high sonnet/high opus/medium opus/high" ;;
    standard) echo "opus/high sonnet/high opus/high opus/xhigh" ;;
    max) echo "opus/high opus/medium fable/high fable/high" ;;
    *) return 1 ;;
  esac
}
# Values earlier kits' profiles wrote (1.4, 1.5), so re-applying a profile after an upgrade is not
# mistaken for overwriting a hand-tailored seat: 1.5 lite reviewer, 1.5 max planner, 1.5 standard writer.
LEGACY_VALUES="planner:fable/high reviewer:sonnet/high writer:opus/medium"

if ! values=$(profile_values "$profile"); then
  sed -n '2,12p' "$0"
  exit 2
fi
read -r planner writer reviewer auditor <<<"$values"

# Every value any profile (current or earlier) sets, per role, as "role:model/effort" words.
KNOWN_VALUES="$LEGACY_VALUES"
for p in lite standard max; do
  read -r a b c d <<<"$(profile_values "$p")"
  KNOWN_VALUES="$KNOWN_VALUES planner:$a writer:$b reviewer:$c security-auditor:$d"
done
export KNOWN_VALUES

# Prints "<model>/<effort>" when the seat in agent file $1 (role $2) is none of the values any profile,
# current or earlier, sets for that role (KNOWN_VALUES): a hand-tailored seat. A missing effort: line passes when the model is one a profile uses.
tailored_seat() {
  [[ -f "$1" ]] || return 0
  python3 -I - "$1" "$2" <<'PY'
import re, sys
path, role = sys.argv[1:3]
import os
pairs = [w.split(":", 1)[1] for w in os.environ["KNOWN_VALUES"].split() if w.split(":", 1)[0] == role]
head = open(path, encoding="utf-8", newline="").read().replace("\r\n", "\n").partition("\n---\n")[0]
m = re.search(r"^model:[ \t]*(\S+)", head, re.M)
if not m:
    sys.exit(0)
e = re.search(r"^effort:[ \t]*(\S+)", head, re.M)
model, effort = m.group(1), e.group(1) if e else None
if effort is None:
    ok = model in [p.split("/")[0] for p in pairs]
else:
    ok = model + "/" + effort in pairs
if not ok:
    print(model + "/" + (effort or "none"))
PY
}

refused=0
for pair in "planner:$planner" "writer:$writer" "reviewer:$reviewer" "security-auditor:$auditor"; do
  role=${pair%%:*}
  cur=$(tailored_seat ".claude/agents/$role.md" "$role") || cur=""
  if [[ -n "$cur" && $force -eq 0 ]]; then
    echo "refused: $role is $cur, none of the profiles' values for that role (a tailored seat); $profile would set it to ${pair#*:}. Run again with --force to overwrite it." >&2
    refused=1
  fi
done
((refused == 0)) || exit 1

set_model() { # file model/effort
  [[ -f "$1" ]] || return 0
  python3 -I - "$1" "${2%/*}" "${2#*/}" <<'PY'
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
  if [[ -n "$cv" ]] && python3 -I -c 'import sys; sys.exit(0 if tuple(map(int, sys.argv[1].split("."))) < (2, 1, 292) else 1)' "$cv"; then
    echo "warn: Claude Code $cv is older than 2.1.292: Agent tool per-call effort unavailable; ladder and risk tiers won't apply"
  fi
fi
# Warn only when a top-level effortLevel is set and modelSettings gives Opus 5.5 none of its own.
if [[ -f "$HOME/.claude/settings.json" ]] && python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
opus = ((d.get("modelSettings") or {}).get("claude-opus-5-5") or {}).get("effortLevel")
sys.exit(0 if d.get("effortLevel") and not opus else 1)' "$HOME/.claude/settings.json" 2>/dev/null; then
  echo "warn: effortLevel in ~/.claude/settings.json is ignored for Opus 5.5; use modelSettings or /effort"
fi
if [[ "$profile" == max ]]; then
  echo "note: max uses model: fable. Fable bills usage credits on Pro and standard Team plans from the first request; \`claude -p\` bills without asking; background and Remote sessions drop the turn after 5 minutes waiting for consent. Set a cap in /usage-credits."
fi
