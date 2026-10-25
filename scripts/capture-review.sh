#!/usr/bin/env bash
# Save reviewer and security-auditor reports to docs/reviews/.
#   stop      SubagentStop hook (matcher: reviewer|security-auditor); report is in last_assistant_message
#   handback  PostToolUse hook on SubagentHandback; report is in tool_input.message
# Only text starting with "## Review:" or "## Security audit:" is saved, so a handback from any
# other agent is ignored. Always exits 0: capture never blocks the work.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0
command -v python3 >/dev/null || exit 0
MODE="${1:-stop}" python3 -c '
import json, os, sys, datetime, subprocess
try:
    h = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if os.environ["MODE"] == "handback":
    text = (h.get("tool_input") or {}).get("message") or ""
else:
    text = h.get("last_assistant_message") or ""
t = text.lstrip()
if t.startswith("## Review:"):
    kind = "review"
elif t.startswith("## Security audit:"):
    kind = "security"
else:
    sys.exit(0)
sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip() or "nogit"
os.makedirs("docs/reviews", exist_ok=True)
path = "docs/reviews/%s-%s-%s.md" % (datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S"), sha, kind)
open(path, "w", encoding="utf-8").write(t.rstrip() + "\n")
'
exit 0
