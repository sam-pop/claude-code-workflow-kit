#!/usr/bin/env bash
# SubagentStop hook: save the reviewer's or security auditor's final report to docs/reviews/.
# Reads the hook's JSON on stdin. Tolerant of missing fields: exits 0 and writes nothing when
# it cannot find a report that starts with "## Review:" or "## Security audit:".
set -uo pipefail
cd "$(dirname "$0")/.."
command -v python3 >/dev/null || exit 0

python3 - <<'PY'
import json, sys, os, re, datetime, subprocess

try:
    hook = json.load(sys.stdin)
except Exception:
    sys.exit(0)

transcript = hook.get("transcript_path") or hook.get("agent_transcript_path")
if not transcript or not os.path.exists(transcript):
    sys.exit(0)

# Last assistant text block in the transcript (JSONL of messages).
report = None
with open(transcript, encoding="utf-8", errors="ignore") as f:
    for line in f:
        try:
            msg = json.loads(line)
        except Exception:
            continue
        m = msg.get("message", msg)
        if m.get("role") != "assistant":
            continue
        content = m.get("content")
        if isinstance(content, str):
            text = content
        else:
            text = "\n".join(b.get("text", "") for b in content or [] if isinstance(b, dict) and b.get("type") == "text")
        if text.strip():
            report = text

if not report:
    sys.exit(0)
head = report.lstrip()[:40]
if not (head.startswith("## Review:") or head.startswith("## Security audit:")):
    sys.exit(0)

kind = "review" if head.startswith("## Review:") else "security"
try:
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip() or "nogit"
except Exception:
    sha = "nogit"
stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
os.makedirs("docs/reviews", exist_ok=True)
path = f"docs/reviews/{stamp}-{sha}-{kind}.md"
with open(path, "w", encoding="utf-8") as f:
    f.write(report.rstrip() + "\n")
print(f"saved {path}")
PY
exit 0
