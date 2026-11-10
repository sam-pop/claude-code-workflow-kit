#!/usr/bin/env bash
# Stuck detector (profiles extra): runs scripts/check.sh and counts identical failures, so a writer
# that keeps hitting the same failure sees it said plainly. scripts/check.sh hands every run to this
# script while it is at scripts/stuck-detect.sh; while the extra is off the file is absent and
# check.sh keeps no state.
# Usage: scripts/stuck-detect.sh <check.sh arguments>   (normally called by scripts/check.sh)
# Runs `KIT_STUCK_INNER=1 bash scripts/check.sh <arguments>` with its output shown as it comes
# (stderr merged into stdout) and exits with its exit code.
#   exit 0  clears the count for these arguments
#   exit 1  hashes the last 40 lines of output, after removing colour codes and normalising
#           durations, clock and ISO times, 0x addresses and temporary paths: the same hash adds
#           one, a different one starts again at 1; from 3 on, the last line printed is
#           `same failure N times: <arguments>`, the writer's first stop rule
#   other   (2 is NOT CONFIGURED or usage) never counted, count kept
# Passes straight through (exec, stdout and stderr kept apart, no state) for --changed, outside a git
# repo, and without python3.
# State: $(git rev-parse --git-path kit/failures), one `<arguments>\t<hash>\t<count>` line per argument
# list (a hash, never output); written through a temporary file, last writer wins.
# Environment: KIT_STUCK_INNER, set for the inner run so check.sh does not hand it back here.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

through() { KIT_STUCK_INNER=1 exec bash scripts/check.sh "$@"; }
for a in "$@"; do [[ "$a" == --changed ]] && through "$@"; done
git rev-parse --git-dir >/dev/null 2>&1 || through "$@"
command -v python3 >/dev/null || through "$@"
state=$(git rev-parse --git-path kit/failures 2>/dev/null) || through "$@"
out=$(mktemp 2>/dev/null) || through "$@"
trap 'rm -f "$out"' EXIT

KIT_STUCK_INNER=1 bash scripts/check.sh "$@" 2>&1 | tee "$out"
rc=${PIPESTATUS[0]}

python3 -I - "$state" "$rc" "$out" "$*" 2>/dev/null <<'PY' || true
import hashlib, os, re, sys, tempfile
state, rc, out, args = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
args = re.sub(r"[\t\r\n]", " ", args) or "(none)"
if rc not in (0, 1):
    sys.exit(0)
rows = {}
try:
    with open(state, encoding="utf-8") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) == 3 and p[2].isdigit():
                rows[p[0]] = (p[1], int(p[2]))
except OSError:
    pass
if rc == 0:
    if args not in rows:
        sys.exit(0)
    del rows[args]
    n = 0
else:
    text = open(out, encoding="utf-8", errors="replace").read()
    text = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)
    text = re.sub(r"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2})?(\.\d+)?(Z|[+-]\d{2}:?\d{2})?", "<time>", text)
    text = re.sub(r"(?<![\w:./-])\d{1,2}:\d{2}(:\d{2})?(\.\d+)?\s*([AaPp][Mm])?", "<time>", text)
    text = re.sub(r"\d+(\.\d+)?\s*(ms|s|sec|seconds|m)\b", "<duration>", text)
    text = re.sub(r"0x[0-9a-fA-F]+", "0x", text)
    text = re.sub(r"(/tmp|/private/var/folders|/var/folders)/[^\s'\":]*", "<tmp>", text)
    lines = [l.rstrip() for l in text.split("\n")]
    while lines and not lines[-1]:
        lines.pop()
    h = hashlib.sha256("\n".join(lines[-40:]).encode("utf-8", "replace")).hexdigest()[:16]
    old = rows.get(args)
    n = old[1] + 1 if old and old[0] == h else 1
    rows[args] = (h, n)
d = os.path.dirname(state)
try:
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".failures.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        for k in sorted(rows):
            f.write(f"{k}\t{rows[k][0]}\t{rows[k][1]}\n")
    os.replace(tmp, state)
except OSError:
    sys.exit(0)  # a state directory that cannot be written: no count, no noise
if n >= 3:
    print(f"same failure {n} times: {args}")
PY
exit "$rc"
