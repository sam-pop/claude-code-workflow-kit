#!/usr/bin/env bash
# Save agent reports to docs/reviews/, named by kind.
#   stop      SubagentStop hook (matcher: reviewer|security-auditor|codex-reviewer|writer);
#             report is in last_assistant_message
#   handback  PostToolUse hook on SubagentHandback; report is in tool_input.message
# Saved by the first line: "## Review:" -> review, "## Security audit:" -> security,
# "## Codex review:" -> codex, "## STUCK:" -> stuck (a writer that hit a stop rule). Anything else
# is ignored, so a normal writer report or a handback from any other agent is never saved.
# Always exits 0: capture never blocks the work.
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
elif t.startswith("## Codex review:"):
    kind = "codex"
elif t.startswith("## STUCK:"):
    kind = "stuck"
else:
    sys.exit(0)
sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip() or "nogit"
os.makedirs("docs/reviews", exist_ok=True)
path = "docs/reviews/%s-%s-%s.md" % (datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S"), sha, kind)
open(path, "w", encoding="utf-8").write(t.rstrip() + "\n")
'
exit 0
