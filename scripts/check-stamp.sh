#!/usr/bin/env bash
# Check stamp (stop-warning extra): remembers the files on which `scripts/check.sh all` last passed,
# so the Stop hook can say when files changed after the last passing run, committed or not.
# Usage: scripts/check-stamp.sh <tree | record <id> | hook>
#   tree         print the id of the working tree's files and save their list as pending, in
#                $(git rev-parse --git-path kit/check-pending.json); check.sh all runs it first
#   record <id>  check.sh all passed: promote the pending list to kit/check-passed.json, only when its
#                id is <id> (a list saved by another run since is never recorded)
#   hook         Stop hook: prints {"systemMessage": ...} with the number of files that differ from
#                the last passing run and up to 3 of their names (printable ASCII, at most 40
#                characters, quoted); with no passing run recorded, the same for the files git status
#                shows; silent otherwise
# The file list: tracked files as the index has them (git ls-files -s) and changed or untracked files
# (git status) hashed as git blob ids of their bytes, a symlink by its target, a submodule by its
# commit and status. Left out: anything under docs/reviews/, untracked files over 1 MiB, deleted
# files, git-ignored files. The id is a sha256 of the sorted list, so a commit does not change it.
# Nothing is written to .git/objects or the index; git status runs with GIT_OPTIONAL_LOCKS=0.
# Files (per worktree, never committed): kit/check-pending.json and kit/check-passed.json hold paths
# and blob ids only. A kit/check-passed from kit 1.5 is ignored and deleted by the next record.
# Exit codes: tree and record 0 ok, 1 failed or refused; 2 usage; hook always 0 and silent on its own
# errors.
# Environment: CLAUDE_PROJECT_DIR (hook: the repo; default the script's parent directory).
# The hook stays quiet until the kit is tailored (scripts/check.sh has no NOT CONFIGURED check and
# runs `scripts/check-stamp.sh record`), outside a git repo, and without python3.
# Known limits: a file whose content git changes on add (a clean filter such as Git LFS, or line-ending
# conversion) gets a different id once committed: one extra warning until the next check.sh all. On
# very large trees (about 200k files) the hook can reach its 30 s timeout; it never blocks, but switch
# the extra off there (scripts/extras.sh off stop-warning).
set -uo pipefail
unset GIT_INDEX_FILE

stamp() { # mode [id]
  command -v python3 >/dev/null || {
    echo "check-stamp: python3 is required" >&2
    return 1
  }
  python3 -I - "$@" <<'PY'
import hashlib, json, os, stat as S, subprocess, sys, tempfile, time

mode = sys.argv[1]
LIMIT = 1 << 20  # untracked files over 1 MiB are left out
env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
env.pop("GIT_INDEX_FILE", None)

def git(*args):
    r = subprocess.run(["git", "-c", "core.quotepath=false"] + list(args), capture_output=True, env=env)
    if r.returncode != 0:
        raise SystemExit(1)
    return r.stdout

top = git("rev-parse", "--show-toplevel").decode("utf-8", "surrogateescape").rstrip("\n")
os.chdir(top)

def kit_path(name):
    p = git("rev-parse", "--git-path", "kit/" + name).decode("utf-8", "surrogateescape").rstrip("\n")
    return os.path.join(top, p) if not os.path.isabs(p) else p

def skipped(path):
    return path == "docs/reviews" or path.startswith("docs/reviews/")

def blob(data):
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()

def scan():
    """{path: "<mode> <id>"} for the files the stamp covers, and the paths git status shows."""
    files = {}
    for rec in git("ls-files", "-s", "-z").split(b"\0"):
        if not rec:
            continue
        meta, _, path = rec.partition(b"\t")
        m, sha, _stage = meta.decode().split()
        files[path.decode("utf-8", "surrogateescape")] = f"{m} {sha}"
    dirty = []
    out = git("status", "--porcelain=v1", "-z", "--untracked-files=all", "--no-renames", "--ignore-submodules=none")
    for rec in out.split(b"\0"):
        if len(rec) < 4:
            continue
        xy, path = rec[:2].decode(), rec[3:].decode("utf-8", "surrogateescape")
        if skipped(path):
            continue
        dirty.append(path)
        old = files.pop(path, None)
        if old and old.startswith("160000 "):  # a submodule: its commit and how it differs
            files[path] = f"{old} {xy.replace(' ', '.')}"
            continue
        try:
            st = os.lstat(path)
        except OSError:
            continue  # deleted
        if S.S_ISLNK(st.st_mode):
            files[path] = "120000 " + blob(os.fsencode(os.readlink(path)))
        elif S.S_ISREG(st.st_mode):
            if xy == "??" and st.st_size > LIMIT:
                continue
            try:
                with open(path, "rb") as f:
                    data = f.read()
            except OSError:
                # unreadable or gone since lstat: still changed; size and mtime stand in for its content
                files[path] = f"100644 unreadable-{st.st_size}-{st.st_mtime_ns}"
                continue
            files[path] = ("100755 " if st.st_mode & 0o111 else "100644 ") + blob(data)
    for p in [p for p in files if skipped(p)]:
        del files[p]
    return files, dirty

def ident(files):
    h = hashlib.sha256()
    for p in sorted(files):
        h.update(os.fsencode(p) + b"\0" + files[p].encode() + b"\n")
    return h.hexdigest()

def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".stamp.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape") as f:
            json.dump(obj, f, separators=(",", ":"), ensure_ascii=False)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise

def read_json(path):
    try:
        with open(path, encoding="utf-8", errors="surrogateescape") as f:
            d = json.load(f)
        return d if isinstance(d, dict) and isinstance(d.get("files"), dict) and isinstance(d.get("id"), str) else None
    except (OSError, ValueError):
        return None

def names(paths):
    """'N files: 'a', 'b', 'c' (+M more)'; names are data: printable ASCII, 40 characters, quoted."""
    paths = sorted(paths)
    shown = []
    for p in paths[:3]:
        p = "".join(c if " " <= c <= "~" else "?" for c in p)
        shown.append("'" + (p[:37] + "..." if len(p) > 40 else p) + "'")
    n = len(paths)
    return f"{n} file{'s' if n > 1 else ''}: " + ", ".join(shown) + (f" (+{n - 3} more)" if n > 3 else "")

if mode == "tree":
    files, _ = scan()
    i = ident(files)
    write_json(kit_path("check-pending.json"), {"id": i, "files": files})
    print(i)
elif mode == "record":
    want = sys.argv[2]
    pending = read_json(kit_path("check-pending.json"))
    if not pending or pending["id"] != want:
        print("check-stamp: the pending file list is not " + want[:12] + "; nothing recorded", file=sys.stderr)
        sys.exit(1)
    pending["passed"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    write_json(kit_path("check-passed.json"), pending)
    try:
        os.remove(kit_path("check-passed"))  # the 1.5 format
    except OSError:
        pass
elif mode == "hook":
    files, dirty = scan()
    passed = read_json(kit_path("check-passed.json"))
    if passed:
        if ident(files) == passed["id"]:
            sys.exit(0)
        old = passed["files"]
        changed = [p for p in set(files) | set(old) if files.get(p) != old.get(p)]
        msg = "scripts/check.sh all has not passed since these changes"
    else:
        changed = dirty
        msg = "scripts/check.sh all: no passing run recorded for these changes"
    if changed:
        print(json.dumps({"systemMessage": f"{msg} ({names(changed)}; see git status --short)"}))
PY
}

hook() {
  cat >/dev/null
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  [[ -f scripts/check.sh ]] || return 0
  grep -qE '^[[:space:]]*not_configured "' scripts/check.sh && return 0
  grep -qE '^[^#]*scripts/check-stamp\.sh record' scripts/check.sh || return 0
  command -v python3 >/dev/null || return 0
  stamp hook
  return 0
}

case "${1:-}" in
  tree)
    cd "$(dirname "$0")/.." || exit 1
    stamp tree || exit 1
    ;;
  record)
    cd "$(dirname "$0")/.." || exit 1
    [[ "${2:-}" =~ ^[0-9a-f]{64}$ ]] || {
      echo "check-stamp: record needs the id that tree printed" >&2
      exit 1
    }
    stamp record "$2" || exit 1
    ;;
  hook)
    cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" 2>/dev/null || exit 0
    hook 2>/dev/null
    exit 0
    ;;
  *)
    sed -n '4,4p' "$0" >&2
    exit 2
    ;;
esac
