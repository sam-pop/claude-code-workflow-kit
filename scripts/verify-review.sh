#!/usr/bin/env bash
# Checks a saved review report against the repository and prints a `### Verification` block.
# Usage: scripts/verify-review.sh <report.md>
#   status    complete, or incomplete with the required sections that are missing
#   quotes    each Standards or Spec finding `- [ ] [nn] path:line[-line]` (or `- [x] …`; a bold
#             label such as **Blocking** may come before the path) is followed by an indented
#             `> exact source text` line; the text (`…` or `...` for elisions; at least 12
#             non-space characters or 2 words) must appear within 3 lines of the cited lines in the
#             working-tree file, or, for a quote that starts with "(removed)", on a removed line of
#             `git diff <merge-base> -- path`. Paths outside the repository are not opened.
#             A `- [ ] [nn]` finding with no parsable path counts as unparsed, which is an issue.
#   coverage  every file changed against the merge-base with the base branch (plus untracked files,
#             minus docs/reviews/) is named, as an exact path, on the `read:` line of `### Coverage`;
#             files listed only under `not read (reason):` are reported as not read
# Exit codes: 0 complete and every quote verified, 1 issues found, 2 usage or unreadable report.
# Environment: BASE_BRANCH.
# Base branch as in scripts/check.sh: $BASE_BRANCH, else origin/HEAD, else main. No base: coverage
# is not checked. Needs python3 3.8+ (standard library only). Writes nothing; the caller appends.
set -uo pipefail
[[ $# -eq 1 && -f "$1" ]] || {
  sed -n '3,3p' "$0" >&2
  exit 2
}
command -v python3 >/dev/null || {
  echo "verify-review: python3 is required" >&2
  exit 2
}
report=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
cd "$(dirname "$0")/.." || exit 2

BASE_BRANCH="${BASE_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')}"
BASE_BRANCH="${BASE_BRANCH:-main}"

python3 - "$report" "$BASE_BRANCH" <<'PY'
import datetime, os, re, subprocess, sys

report, base = sys.argv[1], sys.argv[2]
SECTIONS = ["Summary", "Run", "Checks", "Standards", "Spec", "Considered, below threshold",
            "Not reviewed", "Coverage"]
CTX = 3


def git(*args):
    r = subprocess.run(["git", "-c", "core.hooksPath=/dev/null"] + list(args),
                       capture_output=True, text=True, errors="replace")
    return r.stdout if r.returncode == 0 else None


def norm(s):
    return " ".join(s.replace("`", "").split())


try:
    text = open(report, encoding="utf-8", errors="replace").read()
except OSError:
    sys.exit(2)
lines = text.split("\n")
codex = report.endswith("-codex.md") or text.lstrip().startswith("## Codex review:")

# Sections by "### " heading, outside fenced code. A previous Verification block is ignored.
sections, cur, fence = {}, None, False
for ln in lines:
    if ln.lstrip().startswith("```"):
        fence = not fence
    if not fence and ln.startswith("### "):
        cur = ln[4:].strip()
        sections.setdefault(cur, [])
        continue
    if cur is not None:
        sections[cur].append(ln)
need = [s for s in SECTIONS if not (codex and s == "Run")]
missing = [s for s in need if s not in sections]

# Base and changed files.
mb = None
for ref in ("origin/" + base, base):  # the remote-tracking copy first: a local branch may be stale
    if git("rev-parse", "--verify", "--quiet", ref + "^{commit}") is not None:
        out = git("merge-base", ref, "HEAD")
        if out:
            mb, base = out.strip(), ref
            break
changed = None
if mb:
    d = git("diff", "--no-ext-diff", "--no-renames", "--name-only", mb, "--")
    u = git("ls-files", "--others", "--exclude-standard")
    if d is not None and u is not None:
        changed = sorted({p for p in (d + u).split("\n") if p and not p.startswith("docs/reviews/")})

FIND = re.compile(r"^- \[[ xX]\] \[(\d+)\] (?:\*\*[^*]+\*\*\s*)?`?([^`\s:]+):(\d+)(?:-(\d+))?`?")
FINDING = re.compile(r"^- \[[ xX]\] \[\d+\]")
ROOT = os.path.realpath(".")


def inside(path):
    real = os.path.realpath(path)
    return not os.path.isabs(path) and (real == ROOT or real.startswith(ROOT + os.sep))


def resolve(path):
    if not inside(path):
        return None
    if os.path.isfile(path):
        return path
    cands = [c for c in (changed or []) if c == path or c.endswith("/" + path)]
    return cands[0] if len(cands) == 1 and inside(cands[0]) else None


def in_order(frags, hay):
    pos = 0
    for f in frags:
        i = hay.find(f, pos)
        if i < 0:
            return False
        pos = i + len(f)
    return True


def removed_lines(path):
    if not mb or not inside(path):
        return ""
    d = git("diff", "--no-ext-diff", "--no-color", "--no-textconv", mb, "--", path) or ""
    return " ".join(norm(l[1:]) for l in d.split("\n") if l.startswith("-") and not l.startswith("---"))


verified = unverified = unquoted = unparsed = 0
problems = []
for name in ("Standards", "Spec"):
    body = sections.get(name, [])
    for i, ln in enumerate(body):
        m = FIND.match(ln)
        if not m:
            if FINDING.match(ln):
                unparsed += 1
                problems.append("- unparsed: " + re.sub(r"[^ -~]", "?", ln.strip())[:80])
            continue
        score, path, start = m.group(1), m.group(2), int(m.group(3))
        end = int(m.group(4) or start)
        where = f"[{score}] {path}:{start}" + (f"-{end}" if end != start else "")
        quote = None
        for nxt in body[i + 1:]:
            if not nxt.strip():
                continue
            if not nxt[:1].isspace():
                break
            if nxt.strip().startswith("> "):
                quote = nxt.strip()[2:]
                break
        if quote is None:
            unquoted += 1
            problems.append(f"- unquoted {where}")
            continue
        removed = quote.strip().startswith("(removed)")
        q = norm(re.sub(r"^\(removed\)\s*", "", quote.strip()))
        frags = [f.strip() for f in re.split(r"…|\.\.\.", q) if f.strip()]
        body_text = " ".join(frags)
        if len(body_text.replace(" ", "")) < 12 and len(body_text.split()) < 2:
            unverified += 1
            problems.append(f"- unverified {where} — quote too short")
            continue
        real = resolve(path)
        ok = False
        if not inside(path):
            unverified += 1
            problems.append(f"- unverified {where} — path outside the repository")
            continue
        if frags and real and not removed:
            try:
                flines = open(real, encoding="utf-8", errors="replace").read().split("\n")
            except OSError:
                flines = []
            lo, hi = max(1, start - CTX), min(len(flines), end + CTX)
            ok = in_order(frags, norm(" ".join(flines[lo - 1:hi])))
        if frags and removed:
            ok = in_order(frags, removed_lines(real or path))
        if ok:
            verified += 1
        else:
            unverified += 1
            if removed:
                why = "not on a removed line of the diff"
            else:
                why = "file not found" if not real else f"quote not found within ±{CTX} lines"
            problems.append(f"- unverified {where} — {why}")

out = ["", "### Verification", ""]
when = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
out.append(f"checked: {when} · base: " + (f"{base}@{mb[:7]}" if mb else "none") + " · scripts/verify-review.sh")
out.append("status: complete" if not missing else
           "status: incomplete (missing: " + ", ".join("### " + s for s in missing) + ")")
out.append(f"quotes: {verified} verified, {unverified} unverified, {unquoted} unquoted"
           + (f", {unparsed} unparsed" if unparsed else ""))
out += problems
issues = bool(missing or unverified or unquoted or unparsed)
if changed is None:
    out.append("coverage: not checked (no base)")
else:
    read_text, on = [], False
    for ln in sections.get("Coverage", []):
        t = ln.strip()
        if t.startswith("read:"):
            on, t = True, t[len("read:"):]
        elif t.startswith("not read") or re.match(r"^[A-Za-z ()]+:", t):
            on = False
        if on:
            read_text.append(t)
    listed = {tok for tok in re.split(r"[,\s`]+", " ".join(read_text)) if tok}
    absent = [c for c in changed if c not in listed]
    out.append(f"coverage: {len(changed)} changed files, {len(absent)} not in ### Coverage"
               + (": " + ", ".join(absent[:20]) + (" …" if len(absent) > 20 else "") if absent else ""))
    issues = issues or bool(absent)
print("\n".join(out))
sys.exit(1 if issues else 0)
PY
