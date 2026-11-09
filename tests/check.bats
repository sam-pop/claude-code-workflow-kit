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
