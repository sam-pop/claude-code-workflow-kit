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

@test "the minimum Claude Code version is the same in README and set-models.sh" {
  v=$(grep -oE 'older than [0-9]+\.[0-9]+\.[0-9]+' template/.claude/optional/set-models.sh | head -1 | awk '{print $3}')
  [[ -n "$v" ]]
  grep -q "(2, 1, 292)" template/.claude/optional/set-models.sh
  [[ "$v" == 2.1.292 ]]
  grep -q "v$v or later" README.md
  grep -q "Claude%20Code-v$v" README.md
}

@test "README profile table matches the profiles in set-models.sh" {
  for p in lite standard max; do
    want=$(grep -E "^    $p\) echo \"" template/.claude/optional/set-models.sh | sed 's/.*echo "//; s/".*//')
    row=$(grep -E "^\| \*\*$p\*\*" README.md | head -1 | cut -d'|' -f3-6 | tr '[:upper:]' '[:lower:]' | sed 's/ \/ /\//g; s/|/ /g' | tr -s ' ' | sed 's/^ //; s/ $//')
    [[ -n "$want" ]]
    assert_equal "$row" "$want"
  done
}

@test "template/CLAUDE.md stays at 150 lines or fewer" {
  (($(wc -l <template/CLAUDE.md) <= 150))
}

@test "scripts are executable in the working tree and in the index" {
  for f in template/scripts/*.sh template/.claude/optional/*.sh scripts/install.sh scripts/tools.sh tests/stubs/*; do
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

@test "every inline python3 runs isolated (python3 -I): a planted json.py or re.py in the working directory is never imported" {
  run python3 -I - <<'PY'
import re, subprocess
files = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "--", "template/", "scripts/", ".claude/", ".github/"],
                       capture_output=True, text=True).stdout.split()
# python3 (or python3.N) followed by an option other than -I, by a heredoc/redirect with no "-", or
# python3 ending a line with a backslash (its options are on the next line): flagged.
bad = re.compile(r"(?<![A-Za-z0-9_.-])python3?(\.[0-9]+)?([ \t]+(-(?!I[ \t])|<)|[ \t]*\\$)")
def flagged(line):
    return not line.lstrip().startswith("#") and bad.search(line)
# self-check: the rule must see these and only these
for l in ("python3 -c 'x'", "python3 - \"$a\" <<'PY'", "python3 <<'PY'", "python3.11 -c 'x'", "python3 \\", "  python3 -m json.tool"):
    assert flagged(l), l
for l in ("python3 -I -c 'x'", "python3 -I - \"$a\" <<'PY'", "command -v python3", "python3 is required", "# python3 -c 'x'", "path_without python3"):
    assert not flagged(l), l
for f in files:
    if f.endswith(".md"):
        continue
    try:
        lines = open(f, encoding="utf-8").read().split("\n")
    except (FileNotFoundError, UnicodeDecodeError, IsADirectoryError):
        continue
    for n, line in enumerate(lines, 1):
        if flagged(line):
            print(f"{f}:{n}: {line.strip()}")
PY
  assert_output ""
}

@test "no GNU-only alternation (\| in a basic regex) in grep or sed: BSD tools on macOS read it literally" {
  run python3 - <<'PY'
import re, subprocess
files = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "--", "*.sh", "*.bash", "*.bats",
                        "tests/stubs/*"], capture_output=True, text=True).stdout.split()
# grep or sed run without -E/-r whose single-quoted pattern holds \|
cmd = re.compile(r"\b(grep|sed)\b([^'|;]*)'([^']*)'")
for f in files:
    try:
        lines = open(f, encoding="utf-8").read().split("\n")
    except FileNotFoundError:
        continue
    for n, line in enumerate(lines, 1):
        if re.match(r"\s*#", line):
            continue
        for m in cmd.finditer(line):
            flags, pattern = m.group(2), m.group(3)
            if "\\|" in pattern and not re.search(r"\s-[A-Za-z]*[Er]", flags):
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
  # A 1.4 path is a template/ file, the active path of an extra's file, or retired on purpose.
  retired=" handoff.md docs/glossary.md "
  while IFS= read -r p; do
    [[ -f "template/$p" ]] && continue
    case "$p" in
      scripts/*.sh) [[ -f "template/.claude/optional/${p#scripts/}" ]] && continue ;;
      .claude/agents/*.md) [[ -f "template/.claude/optional/${p#.claude/agents/}" ]] && continue ;;
    esac
    [[ "$retired" == *" $p "* ]] && continue
    fail "template/$p is missing (installed by 1.4)"
  done <tests/fixtures/kit-1.4-files.txt
}

@test "every extra's file in extras.sh exists in template/.claude/optional/, and nothing else is there" {
  listed=$(sed -n '/^file_of() {/,/^}/p' template/scripts/extras.sh | grep -oE '[a-z-]+\.(sh|md)' | sort)
  [[ -n "$listed" ]]
  assert_equal "$(cd template/.claude/optional && find . -type f | sed 's#^\./##' | sort)" "$listed"
  names=$(sed -n 's/^EXTRAS="\(.*\)"$/\1/p' template/scripts/extras.sh)
  for x in $names; do
    sed -n '/^file_of() {/,/^}/p' template/scripts/extras.sh | grep -qE "^ +$x\)" || fail "$x has no files"
  done
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

@test "every extra name in extras.sh appears in README, HOW-TO-USE.md and rollout.md" {
  names=$(sed -n 's/^EXTRAS="\(.*\)"$/\1/p' template/scripts/extras.sh)
  [[ -n "$names" ]]
  for x in $names; do
    for f in README.md template/HOW-TO-USE.md template/docs/rollout.md; do
      grep -q "\`$x\`" "$f" || fail "$f does not name the $x extra"
    done
    grep -q "^### $x$" template/docs/rollout.md || fail "rollout.md has no ### $x section"
  done
}

@test "template/CLAUDE.md Workflow names scripts/extras.sh and authorises the Agent effort parameter, never model" {
  w=$(sed -n '/^## Workflow/,/^## Recording/p' template/CLAUDE.md)
  grep -q 'scripts/extras.sh status' <<<"$w"
  grep -q "Agent tool's \`effort\` parameter" <<<"$w"
  grep -q 'never `model`' <<<"$w"
  (($(wc -l <<<"$w") <= 16))
}

@test "README intro paragraphs match the committed fixture (the owner's wording stays as written)" {
  run sed -n '/^Claude Kit is a set/,/^It.s for anyone/p' README.md
  assert_output "$(cat tests/fixtures/readme-intro.md)"
  # The order is: hero, ---, intro, TL;DR, ---, Contents.
  run grep -nE '^---$|^## TL;DR|^## Contents|^Claude Kit is a set' README.md # -E: BSD grep has no \| in basic regex
  assert_line --index 0 --regexp '^[0-9]+:---$'
  assert_line --index 1 --regexp ':Claude Kit is a set'
  assert_line --index 2 --regexp ':## TL;DR'
  assert_line --index 3 --regexp ':---$'
  assert_line --index 4 --regexp ':## Contents'
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

workflows() { git ls-files -co --exclude-standard -- '.github/workflows/*.yml' 'template/.github/workflows/*.yml' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }

@test "one gitleaks version and checksum everywhere: tools.sh, template check.yml, README, HOW-TO-USE" {
  v=$(awk '$1 == "gitleaks" && $3 == "linux-x64" {print $2}' scripts/tools.sh)
  sha=$(awk '$1 == "gitleaks" && $3 == "linux-x64" {print $4}' scripts/tools.sh)
  [[ -n "$v" && -n "$sha" ]]
  grep -q "GITLEAKS_VERSION: $v$" template/.github/workflows/check.yml
  grep -q "GITLEAKS_SHA256: $sha$" template/.github/workflows/check.yml
  for f in README.md template/HOW-TO-USE.md; do
    grep -q "download/v$v/gitleaks_${v}_linux_x64.tar.gz" "$f" || fail "$f: not gitleaks $v"
    grep -q "$sha  gitleaks.tgz" "$f" || fail "$f: no checksum for gitleaks $v"
  done
  run bash -c "git ls-files -co --exclude-standard | grep -v '^tests/' | xargs grep -ohIE 'gitleaks[/_ -]v?8\.[0-9]+\.[0-9]+|GITLEAKS_VERSION: 8\.[0-9]+\.[0-9]+|gitleaks 8\.[0-9]+\.[0-9]+' 2>/dev/null | grep -oE '8\.[0-9]+\.[0-9]+' | sort -u"
  assert_output "$v"
}

@test "every uses: is pinned to a 40-hex commit SHA with a version comment" {
  while IFS= read -r f; do
    while IFS= read -r line; do
      [[ "$line" =~ uses:\ [A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}\ \#\ v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$f: $line"
    done < <(grep -E 'uses:' "$f")
  done < <(workflows)
}

@test "every workflow has top-level read-only permissions and persist-credentials: false" {
  while IFS= read -r f; do
    grep -qE '^permissions:' "$f" || fail "$f has no top-level permissions"
    grep -qE '^  contents: read$' "$f" || fail "$f: contents is not read"
    grep -q 'persist-credentials: false' "$f" || fail "$f: checkout keeps credentials"
    grep -qE '^ +timeout-minutes:' "$f" || fail "$f: no timeout-minutes"
  done < <(workflows)
}

@test "an action has the same SHA in the root and template workflows" {
  run bash -c "grep -hoE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9a-f]{40}' .github/workflows/*.yml template/.github/workflows/*.yml | sort -u | cut -d@ -f1 | uniq -d"
  assert_output ""
}

@test "semgrep is installed at a pinned version in the template workflow" {
  grep -qE 'SEMGREP_VERSION: [0-9]+\.[0-9]+\.[0-9]+$' template/.github/workflows/check.yml
  grep -q 'semgrep==${SEMGREP_VERSION}' template/.github/workflows/check.yml
}

@test "dependabot covers github-actions in template/ and github-actions plus npm at the root" {
  grep -q 'package-ecosystem: github-actions' template/.github/dependabot.yml
  grep -q 'package-ecosystem: github-actions' .github/dependabot.yml
  grep -q 'package-ecosystem: npm' .github/dependabot.yml
}

@test "template settings.json denies git push and neither asks nor allows it (audit L3)" {
  run python3 -I -c 'import json
p = json.load(open("template/.claude/settings.json"))["permissions"]
r = "Bash(git push:*)"
assert r in p.get("deny", []), "not denied"
assert r not in p.get("ask", []) and r not in p.get("allow", []), "also asked or allowed"'
  assert_success
}
