#!/usr/bin/env bash
# Switch every agent to a model profile.
# Usage: scripts/set-models.sh <standard|max>
#
#             planner  writer  reviewer  security-auditor
#   standard  opus     sonnet  opus      opus
#   max       opus     opus    fable     fable
#
# Aliases track the latest model of each family. Fable may bill usage credits depending on
# your plan; interactive sessions ask first, `claude -p` and SDK runs do not.
set -euo pipefail
cd "$(dirname "$0")/.."
profile="${1:-}"
case "$profile" in
  standard) planner=opus; writer=sonnet; reviewer=opus;  auditor=opus ;;
  max)      planner=opus; writer=opus;   reviewer=fable; auditor=fable ;;
  *) sed -n '2,10p' "$0"; exit 2 ;;
esac

set_model() {  # file model
  [[ -f "$1" ]] || return 0
  python3 - "$1" "$2" <<'PY'
import re, sys
path, model = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
head, sep, body = text.partition("\n---\n")
head = re.sub(r"(?m)^model:.*$", f"model: {model}", head) if re.search(r"(?m)^model:", head) else head + f"\nmodel: {model}"
open(path, "w", encoding="utf-8").write(head + sep + body)
PY
  echo "$(basename "$1" .md): $2"
}

set_model .claude/agents/planner.md "$planner"
set_model .claude/agents/writer.md "$writer"
set_model .claude/agents/reviewer.md "$reviewer"
set_model .claude/agents/security-auditor.md "$auditor"
echo "profile: $profile. Record it in docs/decisions.md."
