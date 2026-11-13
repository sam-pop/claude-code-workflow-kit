#!/usr/bin/env bash
# Installs or upgrades the kit without overwriting tailored files.
# Usage: scripts/install.sh [--upgrade [--force] [--base <commit>]] [--dry-run] /path/to/repo
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
#   --base <commit>   upgrade only: the kit commit the repo was installed from (7 to 40 hex digits),
#               for a repo whose .claude/kit-version has no usable commit= (installed before 1.4)
#   --dry-run   print the classification and write nothing
# Three-way merge: for each tailored file the installer also writes <file>.kit-base, the kit's copy
# at the commit the repo was installed from (commit= in .claude/kit-version, or --base), read from
# the kit's git history. It is written only when its sha256 equals the manifest's hash for that file
# (so a kit that was dirty at install time never gives a wrong base), and never on a --force run over
# an unfinished merge. With no manifest a base is written only with --base, unchecked: that commit
# must be the one the repo was installed from. Without a base the merge session merges two-way, and kit-upgrade.md says why.
# State in the target: .claude/kit-version and .claude/kit-manifest (sha256 of each kit file as
# installed). An unmodified file is replaced in place on upgrade; a modified one gets a .kit sibling.
# Extras: a file under template/.claude/optional/ is an extra's, off there; on, it lives at its active
# path (.claude/agents/<f>.md, scripts/<f>.sh). An upgrade updates it where it is, so an extra stays
# on or off as the repo had it; the manifest keys it by its .claude/optional/ path. A fresh install
# puts every extra off. An extra the kit no longer ships is listed as retired, at the path where the
# repo has the file (its active path when the extra was on), and is never deleted.
# Writes only inside the target: a destination, .kit sibling or state file whose real path leaves it
# (a symlinked directory or a symlink) refuses the whole run before anything is written. Only files
# this run writes get their mode set: executable when the kit's copy is, and every .sh.
# Exit codes: 0 ok, 1 refused or failed, 2 usage.
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$KIT/template"
MODE=install
DRY=0
FORCE=0
TARGET=""
BASE=""
HAVE_BASE=0
while [[ $# -gt 0 ]]; do
  a="$1"
  shift
  case "$a" in
    --upgrade) MODE=upgrade ;;
    --dry-run) DRY=1 ;;
    --force) FORCE=1 ;;
    --base)
      [[ $# -gt 0 ]] || {
        echo "--base needs a kit commit (7 to 40 hex digits)"
        exit 2
      }
      BASE="$1"
      HAVE_BASE=1
      shift
      ;;
    -*)
      echo "unknown option: $a"
      sed -n '2,3p' "$0"
      exit 2
      ;;
    *)
      [[ -z "$TARGET" ]] || {
        echo "one target directory only; got '$TARGET' and '$a'"
        exit 2
      }
      TARGET="$a"
      ;;
  esac
done
[[ -n "$TARGET" ]] || {
  echo "usage: install.sh [--upgrade [--force] [--base <commit>]] [--dry-run] /path/to/repo"
  exit 2
}
if [[ "$HAVE_BASE" == 1 ]]; then
  [[ "$MODE" == upgrade ]] || {
    echo "--base is valid only with --upgrade"
    exit 2
  }
  [[ "$BASE" =~ ^[0-9a-f]{7,40}$ ]] || {
    echo "--base needs a kit commit: 7 to 40 lowercase hex digits"
    exit 2
  }
fi
[[ -d "$TARGET" ]] || {
  echo "not a directory: $TARGET"
  exit 1
}
command -v python3 >/dev/null || {
  echo "python3 is required"
  exit 1
}
[[ -d "$TPL" ]] || {
  echo "the kit has no template/ directory: $TPL"
  exit 1
}
TARGET="$(cd "$TARGET" && pwd -P)"
TPL="$(cd "$TPL" && pwd -P)"
case "$TARGET/" in
  "$TPL"/*)
    echo "refusing to install into the kit's own template/: $TARGET"
    exit 1
    ;;
esac

if git -C "$KIT" rev-parse --git-dir >/dev/null 2>&1; then
  n=$(git -C "$KIT" status --porcelain -- template/ CHANGELOG.md scripts/kit-upgrade-prompt.md 2>/dev/null | wc -l | tr -d ' ')
  [[ "$n" == 0 ]] || echo "warn: the kit checkout has $n uncommitted path(s) under template/, CHANGELOG.md or scripts/kit-upgrade-prompt.md: untracked files are not installed until committed; modified tracked files are installed as they are now" >&2
fi

python3 -I - "$KIT" "$TPL" "$TARGET" "$MODE" "$DRY" "$FORCE" "$BASE" <<'PY' || exit $?
import datetime, hashlib, os, re, shutil, subprocess, sys

kit, tpl, target, mode, dry, force, base_arg = sys.argv[1:8]
upgrade, dry, force = mode == "upgrade", dry == "1", force == "1"
today = datetime.date.today().isoformat()

NEVER_READD = {"TAILOR.md", "HOW-TO-USE.md"}
# Extras that older kits ran as core: on upgrade from a manifest without them they arrive on.
ON_FOR_OLDER = {".claude/optional/review-stats.sh"}  # doctor.sh printed the review stats before 1.6

def active_path(rel):
    """Where an extra's file lives while the extra is on; None for a core file."""
    head, _, name = rel.rpartition("/")
    if head != ".claude/optional":
        return None
    if name.endswith(".md"):
        return ".claude/agents/" + name
    if name.endswith(".sh"):
        return "scripts/" + name
    return None

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

def clean_version(v):
    """A version read from the target is untrusted: digits and dots only, else unknown."""
    return v if re.fullmatch(r"\d+(\.\d+)*", v) else "unknown"

def agent_seats():
    """Each agent's model/effort before the upgrade. A clean merge can move a seat silently: a seat
    equal to the old kit default takes the new default. Read from the target, so values are untrusted:
    names and values that are not plain words are left out."""
    seats, d = [], os.path.join(target, ".claude", "agents")
    if not os.path.isdir(d):
        return seats
    for f in sorted(os.listdir(d)):
        p = os.path.join(d, f)
        if not f.endswith(".md") or os.path.islink(p) or not os.path.isfile(p):
            continue
        head = open(p, encoding="utf-8", errors="replace").read().split("\n---", 1)[0]
        kv = dict(m.groups() for m in re.finditer(r"(?m)^(model|effort):[ \t]*(\S+)[ \t]*$", head))
        name, word = f[:-3], re.compile(r"[A-Za-z0-9._-]{1,40}")
        if word.fullmatch(name) and kv.get("model") and all(word.fullmatch(v) for v in kv.values()):
            seats.append(f"- `{name}`: {kv['model']}/{kv.get('effort', 'default')}")
    return seats

seats_before = agent_seats() if upgrade else []

from_version = clean_version(old_info.get("version", "unknown"))

files = kit_files()
kit_hash = {rel: sha(os.path.join(tpl, rel)) for rel in files}

def present(p):
    return os.path.lexists(os.path.join(target, p))

def dst_of(rel):
    """Upgrade only: an extra's file is where the repo keeps it (active when on). A fresh install
    never looks at the active path, so a repo's own scripts/set-models.sh is left alone."""
    act = active_path(rel)
    if not upgrade or act is None or present(rel):
        return rel
    if present(act):
        return act
    if rel in ON_FOR_OLDER and rel not in old and act not in old:
        return act
    return rel

def prev_hash(rel, dst):
    return old[rel] if rel in old else old.get(dst)

# A previous merge is unfinished while .claude/kit-upgrade.md or a kit file's .kit sibling exists.
upgrade_md = os.path.join(target, ".claude", "kit-upgrade.md")
pending = [dst_of(r) + sfx for r in files for sfx in (".kit", ".kit-base")
           if os.path.exists(os.path.join(target, dst_of(r) + sfx))]
if os.path.isfile(upgrade_md):
    pending.insert(0, ".claude/kit-upgrade.md")
if upgrade and pending:
    if not force and not dry:
        print("the previous kit merge is not finished: " + ", ".join(pending[:5])
              + (" …" if len(pending) > 5 else ""))
        print("finish it (open Claude Code and say: Read .claude/kit-upgrade.md), or re-run with --force")
        sys.exit(1)
    if "upgraded_from" in old_info:  # the unfinished merge started from there
        from_version = clean_version(old_info["upgraded_from"])
continuing = bool(upgrade and pending and force)  # a --force run over an unfinished merge

# The base of the three-way merge: the kit commit the repo was installed from. Both the --base value
# and commit= in .kit-version are checked as hex before git sees them (a value such as
# --output=/x would otherwise be read as an option); commit= comes from the target, so it is untrusted.
HEXC = re.compile(r"[0-9a-f]{7,40}")
def git_out(*args):
    try:
        return subprocess.run(["git", "-C", kit] + list(args), capture_output=True)
    except OSError:
        return None

base_sha, base_prefix, base_why = None, "", "no kit commit recorded"
if upgrade:
    cand = base_arg if base_arg else old_info.get("commit", "")
    if cand and HEXC.fullmatch(cand):
        r = git_out("rev-parse", "--verify", "--quiet", cand + "^{commit}")
        full = r.stdout.decode("utf-8", "replace").strip() if r is not None and r.returncode == 0 else ""
        if re.fullmatch(r"[0-9a-f]{40,64}", full):
            base_sha = full
            r = git_out("cat-file", "-e", base_sha + ":template")
            base_prefix = "template/" if r is not None and r.returncode == 0 else ""  # kits before 1.5
        elif base_arg:
            print(f"--base {base_arg}: not a commit in this kit checkout (a shallow clone, or not a git checkout?)")
            sys.exit(1)
        else:
            base_why = "commit not in this kit checkout"

def kit_base_copy(rel, dst):
    """The kit's copy of this file at the install commit as bytes, or (None, reason). With a manifest
    hash for the file the copy must match it; without a manifest, only with --base (the commit the
    user names), the first candidate that exists, unchecked."""
    if base_sha is None:
        return None, base_why
    want = prev_hash(rel, dst)
    if old and want is None:
        return None, "base copy does not match the manifest"
    if not old and not base_arg:
        return None, "no manifest; pass --base <kit commit you installed from>"
    found = False
    for cand in [rel] + ([active_path(rel)] if active_path(rel) else []):
        r = git_out("cat-file", "blob", base_sha + ":" + base_prefix + cand)
        if r is None or r.returncode != 0:
            continue
        found = True
        if want is None or hashlib.sha256(r.stdout).hexdigest() == want:
            return r.stdout, ""
    return None, "base copy does not match the manifest" if (found or old) else "file not in the base commit"

def classify(rel):
    """Return (class, path of the target file, relative)."""
    dst = dst_of(rel)
    path = os.path.join(target, dst)
    if not os.path.exists(path):
        if upgrade and rel in NEVER_READD:
            return "never re-added", dst
        if upgrade and (rel in old or active_path(rel) in old):
            return "skipped", dst
        return "new", dst
    have = sha(path)
    if have == kit_hash[rel]:
        return "current", dst
    if upgrade and os.path.exists(path + ".kit"):  # still unmerged from the last upgrade (--force)
        return "tailored", dst
    if upgrade and prev_hash(rel, dst) == have:
        return "replaced", dst
    if upgrade and prev_hash(rel, dst) == kit_hash[rel]:
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
base_note = {}  # tailored file -> "" when its .kit-base is there, else why there is none

# Every path this run could write (each file, its .kit sibling, the state files) must resolve inside
# the target: a symlinked directory or a symlink, dangling or not, that leads out of it refuses the run.
outside = []
for p in [d for rel in files for d in (dst_of(rel), dst_of(rel) + ".kit", dst_of(rel) + ".kit-base")] \
        + [".claude/kit-manifest", ".claude/kit-version", ".claude/kit-upgrade.md"]:
    real = os.path.realpath(os.path.join(target, p))
    if real != target and not real.startswith(target + os.sep):
        outside.append(p)
if outside:
    print("refusing: these paths resolve outside the target (a symlink on the way?): "
          + ", ".join(outside[:5]) + (" …" if len(outside) > 5 else ""))
    sys.exit(1)

SAFE_PATH = re.compile(r"[A-Za-z0-9._/@+-]+")

def exec_bits(rel, src, out):  # on a file this run wrote: executable if the kit's copy is, or a .sh
    if os.stat(src).st_mode & 0o111 or rel.endswith(".sh"):  # (a kit copy that lost its modes)
        m = os.stat(out).st_mode
        os.chmod(out, m | (m & 0o444) >> 2)

if dry:
    print("dry run: nothing is written")
for rel in files:
    cls, dst = classify(rel)
    groups[cls].append(dst)
    note = NOTE.get(cls, "").format(dst=dst)
    src, out = os.path.join(tpl, rel), os.path.join(target, dst)
    stale = [dst + sfx for sfx in (".kit", ".kit-base") if os.path.exists(out + sfx)]
    if upgrade and cls == "current" and stale:  # left over from --force
        note = (f"(stale {stale[0]} {'would be ' if dry else ''}deleted: the file now matches the kit"
                + (f"; {stale[1]} too)" if len(stale) > 1 else ")"))
        if not dry:
            for sfx in (".kit", ".kit-base"):
                if os.path.exists(out + sfx):
                    os.remove(out + sfx)
    print(f"{cls + ':':<26}{dst}{'   ' + note if note else ''}")
    if dry:
        continue
    if cls == "new":
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copyfile(src, out)
        exec_bits(rel, src, out)
    elif cls == "replaced":
        with open(src, "rb") as f, open(out, "wb") as g:  # same inode: the file's mode is kept
            g.write(f.read())
        exec_bits(rel, src, out)
    elif cls == "tailored":
        shutil.copyfile(src, out + ".kit")
        if not upgrade:
            continue
        if continuing:  # the manifest and commit= already describe the new kit: a base from them would equal .kit
            base_note[dst] = "" if os.path.exists(out + ".kit-base") else "unfinished merge"
            continue
        blob, why = kit_base_copy(rel, dst)
        if blob is None:
            base_note[dst] = why
        else:
            with open(out + ".kit-base", "wb") as g:
                g.write(blob)
            base_note[dst] = ""
if upgrade:
    for rel in sorted(set(old) - set(files) - {dst_of(r) for r in files}
                      - {active_path(r) for r in files}):
        act = active_path(rel)
        if act is not None and not present(rel) and present(act):
            rel = act  # an extra that was on lives at its active path, not at the dormant one the manifest keys
        groups["retired"].append(rel)
        if SAFE_PATH.fullmatch(rel):  # a manifest line comes from the target: never print it raw
            print(f"{'retired:':<26}{rel}   {NOTE['retired']}")
    hidden = sum(1 for r in groups["retired"] if not SAFE_PATH.fullmatch(r))
    if hidden:
        print(f"{'retired:':<26}{hidden} manifest entries with unexpected characters not shown")

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
        if c == "tailored":
            for p in groups[c]:
                why = base_note.get(p, "unfinished merge")
                lines.append(f"- `{p}` (`{p}.kit`, " + (f"no base: {why})" if why else f"base `{p}.kit-base`)"))
            if not groups[c]:
                lines.append("(none)")
        elif c == "retired":
            shown = [p for p in groups[c] if SAFE_PATH.fullmatch(p)]
            lines += [f"- `{p}`" for p in shown] or ([] if len(shown) < len(groups[c]) else ["(none)"])
            if len(shown) < len(groups[c]):
                lines.append(f"- {len(groups[c]) - len(shown)} manifest entries with unexpected characters not shown")
        else:
            lines += [f"- `{p}`" for p in groups[c]] or ["(none)"]
        lines.append("")
    lines += ["## Agent seats before this upgrade", ""] + (seats_before or ["(none)"]) + [""]
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
echo
if [[ "$MODE" == upgrade ]]; then
  echo "Next: open Claude Code in $TARGET and say: Read .claude/kit-upgrade.md"
  echo "Any *.kit files are the kit's version of a file you tailored; the merge session folds them in."
else
  echo "Next: open Claude Code in $TARGET and say: Read TAILOR.md and tailor the kit to this repo."
  echo "Any *.kit files are the kit's version of a file you already had; merge by hand, then delete them."
fi
