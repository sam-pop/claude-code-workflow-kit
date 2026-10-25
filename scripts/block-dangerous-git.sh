#!/usr/bin/env bash
# PreToolUse hook on Bash: refuse git commands that destroy work or publish without a human.
# Exit 2 blocks the call and shows the message to Claude. Adapted from mattpocock/skills (MIT).
set -uo pipefail
command -v python3 >/dev/null || exit 0
cmd=$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: print("")')
[[ -z "$cmd" ]] && exit 0

patterns=(
  'git push'
  'git reset --hard'
  'git clean -f'
  'git branch -D'
  'git checkout \.'
  'git restore \.'
  'git stash drop'
  'git rebase -i'
)
for p in "${patterns[@]}"; do
  if grep -qE "$p" <<<"$cmd"; then
    echo "BLOCKED: '$cmd' matches '$p'. Pushing and destructive git operations are done by the owner, not by the agent. Stop and tell them what you would have run." >&2
    exit 2
  fi
done
exit 0
