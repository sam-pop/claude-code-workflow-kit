#!/usr/bin/env bash
# Save agent reports to docs/reviews/, named by kind.
#   stop      SubagentStop hook (matcher: reviewer|security-auditor|codex-reviewer|writer);
#             report is in last_assistant_message
#   handback  PostToolUse hook on SubagentHandback; report is in tool_input.message
# Saved by the first line: "## Review:" -> review, "## Security audit:" -> security,
# "## Codex review:" -> codex, "## STUCK:" -> stuck (a writer that hit a stop rule). Anything else
# is ignored, so a normal writer report or a handback from any other agent is never saved.
# When the verify-review extra is on (scripts/verify-review.sh exists), review and codex reports are
# then checked by it, and its `### Verification`
# block is appended to the saved file; when it finds issues (an incomplete report, a quote not in
# the code, a changed file not in ### Coverage) the hook prints a systemMessage with its summary
# (counts only: file names stay in the report). When verify-review times out (25 s) or fails, the
# block says "not run (timeout|error)" and the hook says so too.
# Files: docs/reviews/<date>-<time>-<sha>-<kind>.md; a second report in the same second gets -2, -3, …
# before the kind, and an existing file is never overwritten.
# Usage: capture-review.sh <stop|handback> with the hook JSON on stdin; CLAUDE_PROJECT_DIR is the repo.
# Always exits 0: capture never blocks the work.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0
command -v python3 >/dev/null || exit 0
MODE="${1:-stop}" python3 -c '
import json, os, re, sys, datetime, subprocess
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
stem = "docs/reviews/%s-%s" % (datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S"), sha)
for n in range(1, 100):
    path = "%s%s-%s.md" % (stem, "" if n == 1 else "-%d" % n, kind)
    try:
        with open(path, "x", encoding="utf-8") as f:
            f.write(t.rstrip() + "\n")
        break
    except FileExistsError:
        continue
else:
    sys.exit(0)

def safe(line):  # printable ASCII only: the message reaches the session with more authority than a file
    return re.sub(r"[^ -~]", "?", line)[:300]

if kind in ("review", "codex") and os.path.isfile("scripts/verify-review.sh"):
    why = None
    try:
        r = subprocess.run(["bash", "scripts/verify-review.sh", path], capture_output=True, text=True,
                           errors="replace", timeout=25)
        if r.returncode not in (0, 1) or not r.stdout.strip():
            why = "error"
    except subprocess.TimeoutExpired:
        why = "timeout"
    except Exception:
        why = "error"
    if why:
        open(path, "a", encoding="utf-8").write("\n### Verification\n\nnot run (%s)\n" % why)
        print(json.dumps({"systemMessage": "Review saved to %s: verification not run (%s); check the report by hand" % (path, why)}))
        sys.exit(0)
    open(path, "a", encoding="utf-8").write(r.stdout.rstrip() + "\n")
    if r.returncode == 1:
        keep = [l for l in r.stdout.split("\n") if l.startswith(("status:", "quotes:", "coverage:"))]
        keep = [safe(re.sub(r"(not in ### Coverage): .*", r"\1 (named in the report)", l)) for l in keep]
        print(json.dumps({"systemMessage": "Review saved to %s: %s" % (path, "; ".join(keep))}))
'
exit 0
