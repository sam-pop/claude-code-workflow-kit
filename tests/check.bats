#!/usr/bin/env bats
# template/scripts/check.sh and lint-hook.sh as installed (untailored and tailored), and the kit's
# own root scripts/check.sh.

# shellcheck disable=SC2153,SC2016  # KIT and TARGET are set by helpers.bash; sed and printf scripts hold literal $
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
}

hook() { scripts/lint-hook.sh </dev/null; }

@test "untailored: lint, test and build exit 2 NOT CONFIGURED; security names the dependency audit" {
  for c in lint test build; do
    run scripts/check.sh "$c"
    assert_failure 2
    assert_output --partial "NOT CONFIGURED: $c"
  done
  use_stub gitleaks
  run scripts/check.sh security
  assert_failure
  assert_output --partial "NOT CONFIGURED: dependency audit"
}

@test "untailored: lint --changed with a modified and an untracked file is NOT CONFIGURED, with no bash-4 error (R3)" {
  echo change >>README.md
  echo new >new.txt
  run scripts/check.sh lint --changed
  assert_failure 2
  assert_output --partial "NOT CONFIGURED: lint --changed"
  refute_output --partial "mapfile"
  refute_output --partial "command not found"
}

@test "lint --changed with no changes is skipped and passes" {
  run scripts/check.sh lint --changed
  assert_success
  assert_output --partial "skipped: no changed files"
}

@test "an unknown sub-command prints usage and exits 2" {
  run scripts/check.sh nope
  assert_failure 2
  assert_output --partial "Usage: scripts/check.sh"
}

@test "lint hook stays quiet while lint is NOT CONFIGURED" {
  echo change >>README.md
  run hook
  assert_success
  assert_output ""
}

@test "lint hook exits 2 with the lint output tail when a tailored lint fails" {
  sed -i.bak 's/not_configured "lint --changed"/echo "bad file: README.md" >\&2; return 1/' scripts/check.sh
  rm -f scripts/check.sh.bak
  echo change >>README.md
  run hook
  assert_failure 2
  assert_output --partial "Lint failed after your edit"
  assert_output --partial "bad file: README.md"
}

# The kit's own check.sh, run in a scratch repo so the result depends only on the files given here.
root_check_repo() {
  export KIT_STUCK_INNER=1 # the root's own check.sh, without the stuck detector
  R="$BATS_TEST_TMPDIR/root"
  mkdir -p "$R/scripts"
  cp "$REPO_ROOT/scripts/check.sh" "$R/scripts/"
  git -C "$R" init -q
}

@test "root check.sh: a missing tool is a FAIL naming how to install it, never a skip" {
  root_check_repo
  printf '#!/usr/bin/env bash\necho ok\n' >"$R/scripts/a.sh"
  git -C "$R" add -A
  path_without shellcheck shfmt markdownlint-cli2 lychee actionlint bats gitleaks
  run "$R/scripts/check.sh" lint
  assert_failure
  assert_output --partial "FAIL: shellcheck not installed (run: scripts/tools.sh install)"
  run "$R/scripts/check.sh" test
  assert_failure
  assert_output --partial "FAIL: bats not installed (run: npm ci)"
}

@test "root check.sh: lint fails on a shellcheck finding in a tracked script" {
  with_tools
  require_real shellcheck
  require_real shfmt
  root_check_repo
  # shellcheck disable=SC2016  # the unquoted $1 is the finding under test
  printf '#!/usr/bin/env bash\nrm $1\n' >"$R/scripts/bad.sh"
  git -C "$R" add -A
  run "$R/scripts/check.sh" lint
  assert_failure
  assert_output --partial "SC2086"
}

@test "root check.sh: build is skipped with a reason" {
  root_check_repo
  run "$R/scripts/check.sh" build
  assert_success
  assert_output --partial "skipped: the kit ships source; nothing to build"
}

@test "lint hook passes on printable ASCII only, so escapes and control characters never reach Claude (A7)" {
  sed -i.bak 's/not_configured "lint --changed"/printf "bad \\033[31mfile\\033[0m\\a\\n" >\&2; return 1/' scripts/check.sh
  rm -f scripts/check.sh.bak
  echo change >>README.md
  run hook
  assert_failure 2
  assert_output --partial "bad [31mfile[0m"
  refute_output --partial $'\033'
  refute_output --partial $'\a'
}

@test "lint --changed falls back to origin/<base> when there is no local base branch (B9)" {
  sed -i.bak 's/not_configured "lint --changed"/printf "file: %s\\n" "${FILES[@]}"/' scripts/check.sh
  rm -f scripts/check.sh.bak
  git commit -qam "tailor lint --changed"
  git update-ref refs/remotes/origin/main HEAD
  git checkout -q -b work
  echo x >committed.txt && git add committed.txt && git commit -qm c
  git branch -q -D main
  run scripts/check.sh lint --changed
  assert_success
  assert_output --partial "file: committed.txt"
}

@test "root check.sh: a bin in node_modules/.bin cannot shadow gitleaks (A12)" {
  root_check_repo
  mkdir -p "$R/node_modules/.bin"
  printf '#!/usr/bin/env bash\necho SHADOW\n' >"$R/node_modules/.bin/gitleaks"
  chmod +x "$R/node_modules/.bin/gitleaks"
  use_stub gitleaks
  run "$R/scripts/check.sh" security
  refute_output --partial SHADOW
}

@test "root check.sh: markdownlint never loads code from the tree, in lint, lint --changed and the lint hook" {
  with_tools
  require_real lychee
  require_real shellcheck
  require_real shfmt
  mjs="$REPO_ROOT/node_modules/markdownlint-cli2/markdownlint-cli2.mjs"
  if [[ ! -f "$mjs" ]]; then
    [[ "${KIT_REQUIRE_REAL_TOOLS:-}" == 1 ]] && fail "markdownlint-cli2 is required (KIT_REQUIRE_REAL_TOOLS=1) but not installed"
    skip "markdownlint-cli2 not installed"
  fi
  root_check_repo
  cp "$REPO_ROOT/scripts/lint-hook.sh" "$R/scripts/"
  cp "$REPO_ROOT/.markdownlint-cli2.jsonc" "$REPO_ROOT/.editorconfig" "$R/"
  printf '/node_modules\n' >"$R/.gitignore"
  ln -s "$REPO_ROOT/node_modules" "$R/node_modules"
  mkdir -p "$R/docs/guide" "$R/docs/y"
  # Three ways a config in the tree can make the linter run code; each writes a marker when loaded.
  printf 'require("fs").writeFileSync("%s/ran-cli2-cjs", "x");\nmodule.exports = {};\n' "$BATS_TEST_TMPDIR" >"$R/docs/guide/.markdownlint-cli2.cjs"
  printf 'require("fs").writeFileSync("%s/ran-root-cjs", "x");\nmodule.exports = {};\n' "$BATS_TEST_TMPDIR" >"$R/.markdownlint.cjs"
  printf 'require("fs").writeFileSync("%s/ran-rule-cjs", "x");\nmodule.exports = { names: ["custom-x"], description: "x", tags: ["custom-t"], function: function () {} };\n' "$BATS_TEST_TMPDIR" >"$R/docs/y/rule.cjs"
  printf '{ "customRules": ["./rule.cjs"] }\n' >"$R/docs/y/.markdownlint-cli2.jsonc"
  printf '# T\n\n\nbad\n' >"$R/docs/guide/bad.md" # two blank lines: MD012
  printf '# Y\n\nok\n' >"$R/docs/y/ok.md"
  printf '# R\n\nok\n' >"$R/ok.md"
  git -C "$R" add -A

  run "$R/scripts/check.sh" lint
  assert_failure 1
  assert_output --partial "MD012"
  run "$R/scripts/check.sh" lint --changed
  assert_failure 1
  assert_output --partial "MD012"
  run env CLAUDE_PROJECT_DIR="$R" "$R/scripts/lint-hook.sh"
  assert_failure 2
  assert_output --partial "MD012"
  [[ ! -e "$BATS_TEST_TMPDIR/ran-cli2-cjs" ]]
  [[ ! -e "$BATS_TEST_TMPDIR/ran-root-cjs" ]]
  [[ ! -e "$BATS_TEST_TMPDIR/ran-rule-cjs" ]]
}

@test "root check.sh: tracked .tools/ or node_modules/ fails before any tool runs" {
  root_check_repo
  mkdir -p "$R/.tools/bin" "$R/node_modules/.bin"
  printf '#!/usr/bin/env bash\necho x >"%s/ran-tracked-tool"\n' "$BATS_TEST_TMPDIR" >"$R/.tools/bin/shellcheck"
  chmod +x "$R/.tools/bin/shellcheck"
  printf '#!/usr/bin/env bash\necho a\n' >"$R/scripts/a.sh"
  git -C "$R" add scripts/a.sh
  git -C "$R" add -f .tools/bin/shellcheck
  run "$R/scripts/check.sh" lint
  assert_failure 1
  assert_output --partial "files under .tools/ or node_modules/ are tracked"
  [[ ! -e "$BATS_TEST_TMPDIR/ran-tracked-tool" ]]
  # the same guard for node_modules/
  git -C "$R" rm -q --cached -r .tools
  printf 'x\n' >"$R/node_modules/.bin/bats"
  git -C "$R" add -f node_modules/.bin/bats
  run "$R/scripts/check.sh" test
  assert_failure 1
  assert_output --partial "files under .tools/ or node_modules/ are tracked"
}

@test "root check.sh: tracked .TOOLS/ or Node_Modules/ (other case, as on a case-insensitive checkout) fails too" {
  root_check_repo
  mkdir -p "$R/.TOOLS/bin"
  printf '#!/usr/bin/env bash\necho x >"%s/ran-tracked-tool"\n' "$BATS_TEST_TMPDIR" >"$R/.TOOLS/bin/shellcheck"
  chmod +x "$R/.TOOLS/bin/shellcheck"
  git -C "$R" add -f .TOOLS/bin/shellcheck
  run "$R/scripts/check.sh" lint
  assert_failure 1
  assert_output --partial "files under .tools/ or node_modules/ are tracked"
  [[ ! -e "$BATS_TEST_TMPDIR/ran-tracked-tool" ]]
  git -C "$R" rm -q --cached -r .TOOLS
  mkdir -p "$R/Node_Modules/.bin"
  printf 'x\n' >"$R/Node_Modules/.bin/bats"
  git -C "$R" add -f Node_Modules/.bin/bats
  run "$R/scripts/check.sh" test
  assert_failure 1
  assert_output --partial "files under .tools/ or node_modules/ are tracked"
}

@test "root check.sh: GIT_LITERAL_PATHSPECS does not switch off the tracked-tools guard" {
  root_check_repo
  mkdir -p "$R/.tools/bin"
  printf '#!/usr/bin/env bash\n' >"$R/.tools/bin/x"
  git -C "$R" add -f .tools/bin/x
  GIT_LITERAL_PATHSPECS=1 run "$R/scripts/check.sh" build
  assert_failure 1
  assert_output --partial "files under .tools/ or node_modules/ are tracked"
}

@test "root check.sh: a tracked node_modules or .tools entry itself (a symlink) fails the guard" {
  # Checkout replaces the git-ignored directory with the branch's symlink, and check.sh then runs the
  # tools the link points at.
  root_check_repo
  mkdir -p "$R/evil"
  for name in node_modules .tools .TOOLS; do
    ln -s evil "$R/$name"
    git -C "$R" add -f "$name"
    run "$R/scripts/check.sh" build
    assert_failure 1
    assert_output --partial "files under .tools/ or node_modules/ are tracked"
    git -C "$R" rm -q --cached "$name"
    rm "$R/$name"
  done
}

@test "root check.sh: a failing git ls-files fails the guard closed" {
  export KIT_STUCK_INNER=1
  mkdir -p "$BATS_TEST_TMPDIR/nogit/scripts"
  cp "$REPO_ROOT/scripts/check.sh" "$BATS_TEST_TMPDIR/nogit/scripts/"
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run "$BATS_TEST_TMPDIR/nogit/scripts/check.sh" build
  assert_failure 1
  assert_output --partial "git ls-files failed"
}
