#!/usr/bin/env bats
# template/.claude/optional/stuck-detect.sh (profiles extra): counting identical check.sh failures,
# what resets the count, pass-through, and no state with the extra off.

# shellcheck disable=SC2153,SC2016  # KIT and TARGET are set by helpers.bash; sed and printf scripts hold literal $
load helpers
bats_require_minimum_version 1.5.0

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
  # A tailored check.sh whose test check prints $MSG (and a varying duration) and fails when FAIL is set.
  python3 - <<'PY'
import re
p = "scripts/check.sh"
s = open(p).read()
s = s.replace('not_configured "test"', 'echo "${MSG:-boom}"; echo "took $RANDOM ms at 1$((RANDOM % 9)):0$((RANDOM % 9)):00"; [[ -z "${FAIL:-}" ]]')
s = re.sub(r'not_configured "([^"]*)"', r'skip "\1"', s)
open(p, "w").write(s)
PY
  git add -A && git commit -qm tailored
}

failures() { git rev-parse --git-path kit/failures; }

@test "with the profiles extra on, three identical failures print 'same failure 3 times: test'" {
  extras_on profiles
  for _ in 1 2; do
    run env FAIL=1 scripts/check.sh test
    assert_failure 1
    refute_output --partial "same failure"
  done
  run env FAIL=1 scripts/check.sh test
  assert_failure 1
  assert_line --index 0 "== test"
  assert_equal "${lines[${#lines[@]} - 1]}" "same failure 3 times: test"
  run env FAIL=1 scripts/check.sh test
  assert_output --partial "same failure 4 times: test"
}

@test "output differing only in durations, clock times, colour codes and 0x addresses is the same failure" {
  extras_on profiles
  for _ in 1 2 3; do run env FAIL=1 MSG="$(printf '\033[3%dmfail\033[0m at 0x%x' $((RANDOM % 7)) "$RANDOM")" scripts/check.sh test; done
  assert_output --partial "same failure 3 times: test"
}

@test "a pass clears the count" {
  extras_on profiles
  for _ in 1 2; do run env FAIL=1 scripts/check.sh test; done
  run scripts/check.sh test
  assert_success
  run grep -c . "$(failures)"
  assert_output 0
  run env FAIL=1 scripts/check.sh test
  refute_output --partial "same failure"
}

@test "a different failure starts again at 1; each argument list counts on its own" {
  extras_on profiles
  for _ in 1 2; do run env FAIL=1 MSG=first scripts/check.sh test; done
  run env FAIL=1 MSG=second scripts/check.sh test
  assert_equal "$(awk -F'\t' '$1 == "test" {print $3}' "$(failures)")" 1
  for _ in 1 2; do run env FAIL=1 MSG=second scripts/check.sh test; done
  assert_output --partial "same failure 3 times: test"
  run env FAIL=1 scripts/check.sh all
  refute_output --partial "same failure"
}

@test "NOT CONFIGURED (exit 2) is never counted and keeps the count" {
  extras_on profiles
  for _ in 1 2; do run env FAIL=1 scripts/check.sh test; done
  git checkout -q HEAD~2 -- scripts/check.sh # untailored: test is NOT CONFIGURED
  for _ in 1 2 3; do
    run scripts/check.sh test
    assert_failure 2
    refute_output --partial "same failure"
  done
  assert_equal "$(awk -F'\t' '$1 == "test" {print $3}' "$(failures)")" 2
}

@test "the exit code of check.sh is kept" {
  extras_on profiles
  run scripts/check.sh test
  assert_success
  run env FAIL=1 scripts/check.sh test
  assert_failure 1
  run scripts/check.sh nope
  assert_failure 2
}

@test "--changed passes straight through: stderr kept apart and no state" {
  extras_on profiles
  sed -i.bak 's/skip "lint --changed"/echo "to stderr" >\&2; return 1/' scripts/check.sh && rm -f scripts/check.sh.bak
  echo x >>README.md
  run --separate-stderr scripts/check.sh lint --changed
  assert_failure 1
  assert_equal "$stderr" "to stderr"
  refute_output --partial "to stderr"
  [[ ! -e "$(failures)" ]]
}

@test "the state holds the arguments and a hash, never the output" {
  extras_on profiles
  run env FAIL=1 MSG="SECRET_$(fake_token)" scripts/check.sh test
  run grep -c SECRET "$(failures)"
  assert_output 0
  run awk -F'\t' '{print $1, length($2), $3}' "$(failures)"
  assert_output "test 16 1"
}

@test "with every extra off, check.sh all on a tailored repo leaves no kit state in .git" {
  for f in CLAUDE.md handoff.md docs/*.md .claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    sed -i.bak -e 's/{{[^}]*}}/x/g' -e '/<!-- kit:/d' "$f" && rm -f "$f.bak"
  done
  python3 - <<'PY'
import re
p = "scripts/check.sh"
s = open(p).read()
s = re.sub(r"(?ms)^security\(\) \{.*?^\}\n", 'security() {\n  echo "== security"\n}\n', s)
open(p, "w").write(s)
PY
  git add -A && git commit -qm tailored
  run env FAIL=1 scripts/check.sh all
  assert_failure 1
  run scripts/check.sh all
  assert_success
  [[ ! -e "$(git rev-parse --git-path kit)" ]]
}

@test "without python3, check.sh runs through and keeps no state" {
  extras_on profiles
  path_without python3
  run env FAIL=1 scripts/check.sh test
  assert_failure 1
  assert_output --partial "boom"
  [[ ! -e "$(failures)" ]]
}
