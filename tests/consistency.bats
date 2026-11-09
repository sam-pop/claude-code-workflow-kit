#!/usr/bin/env bats
# Facts that must agree across files, kit hygiene of template/, and drift between the root dogfood
# install and template/.

# shellcheck disable=SC2016,SC2153  # literal backticks and $ in patterns; KIT and TARGET come from helpers.bash
load helpers

setup() {
  isolate
  cd "$REPO_ROOT" || exit 1
}

shell_files() { git ls-files -co --exclude-standard -- '*.sh' '*.bash' '*.bats' 'tests/stubs/*' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }

@test "README version badge matches the first CHANGELOG version" {
  v=$(sed -n 's/^## \[\([0-9.]*\)\].*/\1/p' CHANGELOG.md | head -1)
  run grep -c "badge/version-$v-" README.md
  assert_output 1
}

@test "the minimum Claude Code version is the same in README and doctor.sh" {
  v=$(grep -oE 'older than [0-9]+\.[0-9]+\.[0-9]+' template/scripts/doctor.sh | head -1 | awk '{print $3}')
  [[ -n "$v" ]]
  grep -q "(2, 1, 292)" template/scripts/doctor.sh
  [[ "$v" == 2.1.292 ]]
  grep -q "v$v or later" README.md
  grep -q "Claude%20Code-v$v" README.md
}

@test "README profile table matches the profiles in set-models.sh" {
  for p in lite standard max; do
    want=$(awk -v p="  $p)" '$0 == p {on=1; next} on && /;;/ {exit} on' template/scripts/set-models.sh \
      | grep -oE '(planner|writer|reviewer|auditor)=[a-z]+/[a-z]+' | cut -d= -f2 | tr '\n' ' ' | sed 's/ $//')
    row=$(grep -E "^\| \*\*$p\*\*" README.md | head -1 | cut -d'|' -f3-6 | tr '[:upper:]' '[:lower:]' | sed 's/ \/ /\//g; s/|/ /g' | tr -s ' ' | sed 's/^ //; s/ $//')
    assert_equal "$row" "$want"
  done
}

@test "template/CLAUDE.md stays at 150 lines or fewer" {
  (($(wc -l <template/CLAUDE.md) <= 150))
}

@test "scripts are executable in the working tree and in the index" {
  for f in template/scripts/*.sh scripts/install.sh scripts/tools.sh tests/stubs/*; do
    [[ -x "$f" ]] || fail "$f is not executable"
    mode=$(git ls-files -s -- "$f" | awk '{print $1}')
    [[ -z "$mode" || "$mode" == 100755 ]] || fail "$f has mode $mode in the index"
  done
}

@test "settings.json is valid JSON and every hook command's script exists" {
  for s in template/.claude/settings.json .claude/settings.json; do
    run python3 - "$s" <<'PY'
import json, re, sys, os
path = sys.argv[1]
root = os.path.dirname(os.path.dirname(path))
data = json.load(open(path))
for event, groups in data.get("hooks", {}).items():
    for g in groups:
        for h in g.get("hooks", []):
            for m in re.findall(r"scripts/[A-Za-z0-9._-]+\.sh", h.get("command", "")):
                if not os.path.isfile(os.path.join(root, m)):
                    print("missing", m); sys.exit(1)
PY
    assert_success
  done
}

@test "no bash-4-only syntax in shell files (bash 3.2 floor)" {
  # Code only: comments and quoted strings are stripped first, so a test may name what it forbids.
  run python3 - <<'PY'
import re, subprocess
files = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "--", "*.sh", "*.bash", "*.bats",
                        "tests/stubs/*"], capture_output=True, text=True).stdout.split()
bad = re.compile(r"\bmapfile\b|\breadarray\b|declare -A|local -n|\$\{[A-Za-z_]+(,,|\^\^)\}|\[\[ -v |\|&|\bcoproc\b")
for f in files:
    try:
        lines = open(f, encoding="utf-8").read().split("\n")
    except FileNotFoundError:
        continue
    for n, line in enumerate(lines, 1):
        code = re.sub(r"'[^']*'|\"(\\.|[^\"\\])*\"", "", line)
        code = re.sub(r"(^|\s)#.*", "", code)
        if bad.search(code):
            print(f"{f}:{n}: {line.strip()}")
PY
  assert_output ""
}

@test "every shell file starts with a bash or bats shebang" {
  while IFS= read -r f; do
    head -1 "$f" | grep -qE '^#!/usr/bin/env (bash|bats)$' || fail "$f: $(head -1 "$f")"
  done < <(shell_files | grep -v '\.bash$')
}

@test "codex-reviewer tells the relay to use a 600000 ms Bash timeout (R1-85)" {
  grep -q 'timeout` set to `600000`' template/.claude/optional/codex-reviewer.md
}

@test "TAILOR.md says cross-model review is unavailable on Review-only (R1-85)" {
  grep -q 'Cross-model review is not available on Review-only' template/TAILOR.md
}

@test "the upgrade prompt and the decisions template both name the lite profile (R1-Spec)" {
  grep -q 'lite|standard|max' scripts/kit-upgrade-prompt.md
  grep -q 'lite | standard | max' template/docs/decisions.md
}

@test "every path kit 1.4 installed is still under template/ (no surprise retirements)" {
  while IFS= read -r p; do
    [[ -f "template/$p" ]] || fail "template/$p is missing (installed by 1.4)"
  done <tests/fixtures/kit-1.4-files.txt
}

@test "the root dogfood install has not drifted from template/" {
  run scripts/install.sh --upgrade --dry-run .
  assert_success
  # handoff.md is local maintainer state: present (tailored) on a maintainer machine, absent in CI.
  while IFS= read -r line; do
    case "$line" in
      "current:"* | "tailored (kit unchanged):"* | "skipped:"* | "never re-added:"* | "dry run:"* | "" | replaced\ [0-9]*) ;;
      "warn:"*) ;;
      *) fail "unexpected: $line" ;;
    esac
  done <<<"$output"
}

@test "template/ holds no maintainer content" {
  repo_url='https://github\.com/sam-pop/claude-code-workflow-kit[^ )>]*'
  pats='[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z0-9.-]+|sam-pop|poplovitch|docs/research/|tools\.sh|kit-upgrade-prompt|helpers\.bash|tests/stubs|package-lock|\.markdownlint-cli2'
  run bash -c "git ls-files -co --exclude-standard -- template | xargs grep -nIE '$pats' 2>/dev/null | sed -E 's#$repo_url##g' | grep -E '$pats'"
  assert_output ""
  # Pre-launch words the maintainer keeps out of the repo: one per line in the git-ignored
  # .maintainer-words (never committed, so the words themselves never enter the repo either).
  if [[ -f .maintainer-words ]]; then
    while IFS= read -r w; do
      [[ -n "$w" ]] || continue
      run grep -rnIi -- "$w" template
      assert_output ""
    done <.maintainer-words
  fi
}

@test "a fresh install contains only paths that exist under template/" {
  mk_kit
  mk_target
  "$KIT/scripts/install.sh" "$TARGET" >/dev/null
  while IFS= read -r f; do
    [[ "$f" == .claude/kit-manifest || "$f" == .claude/kit-version || "$f" == README.md ]] && continue
    [[ -f "template/$f" ]] || fail "installed $f, which is not under template/"
  done < <(cd "$TARGET" && find . -path ./.git -prune -o -type f -print | sed 's#^\./##')
}
