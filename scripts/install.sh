#!/usr/bin/env bash
# Installs or upgrades the kit without overwriting tailored files.
# Usage: scripts/install.sh [--upgrade [--force]] [--dry-run] /path/to/repo
#   (none)      fresh install: copy what is missing; a file that already differs is kept and the
#               kit's copy is saved beside it as <file>.kit
#   --upgrade   re-run on a repo that has the kit: classify every kit file (replaced, current,
#               tailored, tailored (kit unchanged), new, skipped, never re-added, retired) and
#               write .claude/kit-upgrade.md, the prompt for the merge session
# Copies template/ as is: kit files are what `git ls-files -- template/` lists in the kit checkout
# (a plain walk of template/ if it is not one), installed at the same path minus the template/ prefix.
# Reads CHANGELOG.md and scripts/kit-upgrade-prompt.md; never writes to the kit.
#   --force     upgrade even though a previous merge is unfinished (.claude/kit-upgrade.md or a .kit
#               file is still there); files with a .kit sibling stay tailored
#   --dry-run   print the classification and write nothing
# State in the target: .claude/kit-version and .claude/kit-manifest (sha256 of each kit file as
# installed). An unmodified file is replaced in place on upgrade; a modified one gets a .kit sibling.
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$KIT/template"
MODE=install; DRY=0; FORCE=0; TARGET=""
for a in "$@"; do
  case "$a" in
    --upgrade) MODE=upgrade ;;
    --dry-run) DRY=1 ;;
    --force) FORCE=1 ;;
    -*) echo "unknown option: $a"; sed -n '2,3p' "$0"; exit 2 ;;
    *) TARGET="$a" ;;
  esac
done
[[ -n "$TARGET" ]] || { echo "usage: install.sh [--upgrade [--force]] [--dry-run] /path/to/repo"; exit 2; }
[[ -d "$TARGET" ]] || { echo "not a directory: $TARGET"; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }
[[ -d "$TPL" ]] || { echo "the kit has no template/ directory: $TPL"; exit 1; }
TARGET="$(cd "$TARGET" && pwd -P)"
TPL="$(cd "$TPL" && pwd -P)"
case "$TARGET/" in
  "$TPL"/*) echo "refusing to install into the kit's own template/: $TARGET"; exit 1 ;;
esac

if git -C "$KIT" rev-parse --git-dir >/dev/null 2>&1; then
  n=$(git -C "$KIT" status --porcelain -- template/ CHANGELOG.md scripts/kit-upgrade-prompt.md 2>/dev/null | wc -l | tr -d ' ')
  [[ "$n" == 0 ]] || echo "warn: the kit checkout has $n uncommitted path(s) under template/, CHANGELOG.md or scripts/kit-upgrade-prompt.md: untracked files are not installed until committed; modified tracked files are installed as they are now" >&2
fi

python3 - "$KIT" "$TPL" "$TARGET" "$MODE" "$DRY" "$FORCE" <<'PY' || exit $?
import datetime, hashlib, os, re, shutil, subprocess, sys

kit, tpl, target, mode, dry, force = sys.argv[1:7]
upgrade, dry, force = mode == "upgrade", dry == "1", force == "1"
today = datetime.date.today().isoformat()

NEVER_READD = {"TAILOR.md", "HOW-TO-USE.md"}
# A repo with cross-model review on has this file under agents/, not optional/.
ALIAS = {".claude/optional/codex-reviewer.md": ".claude/agents/codex-reviewer.md"}

def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()

def kit_files():
    """Paths relative to template/ (and so to the target root)."""
    listed = None
    try:
        r = subprocess.run(["git", "-C", kit, "ls-files", "-z", "--", "template/"], capture_output=True)
        if r.returncode == 0:
            listed = [p[len("template/"):] for p in r.stdout.decode("utf-8").split("\0")
                      if p.startswith("template/")]
    except OSError:
        pass
    if not listed:  # not a git checkout, or template/ is not tracked there: walk template/
        listed = []
        for root, dirs, files in os.walk(tpl):
            dirs[:] = [d for d in dirs if d != ".git"]
            listed += [os.path.relpath(os.path.join(root, n), tpl).replace(os.sep, "/") for n in files]
    return sorted({rel for rel in listed if rel and os.path.isfile(os.path.join(tpl, rel))})

def changelog():
    p = os.path.join(kit, "CHANGELOG.md")
    return open(p, encoding="utf-8").read() if os.path.isfile(p) else ""

def vkey(v):
    return tuple(int(x) for x in re.findall(r"\d+", v))

cl = changelog()
m = re.search(r"(?m)^## \[(\d+(?:\.\d+)*)\]", cl)
version = m.group(1) if m else "unknown"
try:
    commit = subprocess.run(["git", "-C", kit, "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip() or "unknown"
except OSError:
    commit = "unknown"

manifest_path = os.path.join(target, ".claude", "kit-manifest")
version_path = os.path.join(target, ".claude", "kit-version")
old = {}
if os.path.isfile(manifest_path):
    if not upgrade:
        print("this repo already has .claude/kit-manifest; use --upgrade")
        sys.exit(1)
    for line in open(manifest_path, encoding="utf-8"):
        parts = line.rstrip("\n").split(None, 1)
        if len(parts) == 2:
            old[parts[1].strip()] = parts[0]
old_info = {}
if os.path.isfile(version_path):
    for tok in open(version_path, encoding="utf-8").read().split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            old_info[k] = v
from_version = old_info.get("version", "unknown")

files = kit_files()
kit_hash = {rel: sha(os.path.join(tpl, rel)) for rel in files}

def dst_of(rel):
    if not os.path.exists(os.path.join(target, rel)) and rel in ALIAS \
            and os.path.exists(os.path.join(target, ALIAS[rel])):
        return ALIAS[rel]
    return rel

# A previous merge is unfinished while .claude/kit-upgrade.md or a kit file's .kit sibling exists.
upgrade_md = os.path.join(target, ".claude", "kit-upgrade.md")
pending = [dst_of(r) + ".kit" for r in files if os.path.exists(os.path.join(target, dst_of(r) + ".kit"))]
if os.path.isfile(upgrade_md):
    pending.insert(0, ".claude/kit-upgrade.md")
if upgrade and pending:
    if not force and not dry:
        print("the previous kit merge is not finished: " + ", ".join(pending[:5])
              + (" …" if len(pending) > 5 else ""))
        print("finish it (open Claude Code and say: Read .claude/kit-upgrade.md), or re-run with --force")
        sys.exit(1)
    if "upgraded_from" in old_info:  # the unfinished merge started from there
        from_version = old_info["upgraded_from"]

def classify(rel):
    """Return (class, path of the target file, relative)."""
    dst = dst_of(rel)
    path = os.path.join(target, dst)
    if not os.path.exists(path):
        if upgrade and rel in NEVER_READD:
            return "never re-added", dst
        if upgrade and rel in old:
            return "skipped", dst
        return "new", dst
    have = sha(path)
    if have == kit_hash[rel]:
        return "current", dst
    if upgrade and os.path.exists(path + ".kit"):  # still unmerged from the last upgrade (--force)
        return "tailored", dst
    if upgrade and old.get(rel) == have:
        return "replaced", dst
    if upgrade and old.get(rel) == kit_hash[rel]:
        return "tailored (kit unchanged)", dst
    return "tailored", dst

NOTE = {
    "tailored": "(kit copy saved as {dst}.kit)",
    "skipped": "(you deleted it)",
    "tailored (kit unchanged)": "(kept as is; nothing to merge)",
    "retired": "(no longer in the kit; not deleted)",
}
ORDER = ["replaced", "current", "tailored", "tailored (kit unchanged)", "new", "skipped",
         "never re-added", "retired"]
groups = {c: [] for c in ORDER}

if dry:
    print("dry run: nothing is written")
for rel in files:
    cls, dst = classify(rel)
    groups[cls].append(dst)
    note = NOTE.get(cls, "").format(dst=dst)
    src, out = os.path.join(tpl, rel), os.path.join(target, dst)
    if upgrade and cls == "current" and os.path.exists(out + ".kit"):  # left over from --force
        note = f"(stale {dst}.kit {'would be ' if dry else ''}deleted: the file now matches the kit)"
        if not dry:
            os.remove(out + ".kit")
    print(f"{cls + ':':<26}{dst}{'   ' + note if note else ''}")
    if dry:
        continue
    if cls == "new":
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copyfile(src, out)
        shutil.copymode(src, out)
    elif cls == "replaced":
        with open(src, "rb") as f, open(out, "wb") as g:  # same inode: the file's mode is kept
            g.write(f.read())
    elif cls == "tailored":
        shutil.copyfile(src, out + ".kit")
if upgrade:
    for rel in sorted(set(old) - set(files)):
        groups["retired"].append(rel)
        print(f"{'retired:':<26}{rel}   {NOTE['retired']}")

print()
print("  ".join(f"{c} {len(groups[c])}" for c in ORDER if upgrade or c in ("current", "tailored", "new")))
if dry:
    sys.exit(0)

os.makedirs(os.path.join(target, ".claude"), exist_ok=True)
with open(manifest_path, "w", encoding="utf-8") as f:
    for rel in files:
        f.write(f"{kit_hash[rel]}  {rel}\n")
info = f"version={version} commit={commit} installed={old_info.get('installed', today) if upgrade else today}"
if upgrade:
    info += f" upgraded={today} upgraded_from={from_version}"
with open(version_path, "w", encoding="utf-8") as f:
    f.write(info + "\n")

if upgrade:
    sections = re.split(r"(?m)^(?=## \[)", cl)
    keep = []
    for s in sections:
        mm = re.match(r"## \[(\d+(?:\.\d+)*)\]", s)
        if mm and (from_version == "unknown" or vkey(mm.group(1)) > vkey(from_version)):
            keep.append(s.rstrip() + "\n")
    prompt = open(os.path.join(kit, "scripts", "kit-upgrade-prompt.md"), encoding="utf-8").read().rstrip()
    lines = [prompt, "", f"# Kit upgrade: {from_version} to {version}", "",
             f"Written by scripts/install.sh --upgrade on {today} from kit commit {commit}.", ""]
    heads = {"tailored": "tailored: merge each file with its .kit sibling",
             "new": "new: installed; delete what this repo's tier does not use",
             "replaced": "replaced: unmodified files, updated in place",
             "current": "current: already match the kit",
             "tailored (kit unchanged)": "tailored (kit unchanged): yours differ, the kit's did not change; nothing to do",
             "skipped": "skipped: you deleted these earlier; not re-added",
             "never re-added": "never re-added: one-time files",
             "retired": "retired: no longer in the kit; delete by hand if unused"}
    for c in ORDER:
        lines += [f"## {heads[c]}", ""]
        lines += [f"- `{p}`" + (f" (`{p}.kit`)" if c == "tailored" else "") for p in groups[c]] or ["(none)"]
        lines.append("")
    lines += [f"## Changes since {from_version}" if from_version != "unknown"
              else "## Changes (previous version unknown, all shown)", ""]
    if keep:
        lines += keep
    elif cl:
        lines.append(f"No changes since {from_version}.")
    else:
        lines.append("(no CHANGELOG.md in the kit)")
    with open(os.path.join(target, ".claude", "kit-upgrade.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip() + "\n")
PY

[[ "$DRY" == 1 ]] && exit 0
chmod +x "$TARGET"/scripts/*.sh
echo
if [[ "$MODE" == upgrade ]]; then
  echo "Next: open Claude Code in $TARGET and say: Read .claude/kit-upgrade.md"
  echo "Any *.kit files are the kit's version of a file you tailored; the merge session folds them in."
else
  echo "Next: open Claude Code in $TARGET and say: Read TAILOR.md and tailor the kit to this repo."
  echo "Any *.kit files are the kit's version of a file you already had; merge by hand, then delete them."
fi
