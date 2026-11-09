#!/usr/bin/env bats
# template/scripts/doctor.sh: expected FAILs on an untailored install, none on a tailored one,
# warnings for settings that undo the per-role setup, and no false open-item FAILs.

# shellcheck disable=SC2153  # KIT and TARGET are set by helpers.bash
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
  use_stub claude codex
}

# Make the install look tailored: no placeholders or kit notes, no NOT CONFIGURED checks.
tailor() {
  local f
  for f in CLAUDE.md handoff.md docs/*.md .claude/agents/*.md; do
    sed -i.bak -e 's/{{[^}]*}}/x/g' -e '/<!-- kit:/d' "$f" && rm -f "$f.bak"
  done
  sed -i.bak 's/not_configured "\([^"]*\)"/skip "\1"/' scripts/check.sh && rm -f scripts/check.sh.bak
  git add -A && git commit -qm tailored
}

fails() { grep -c '^FAIL:' <<<"$output" || true; }

@test "fresh untailored install: exactly the two expected FAILs" {
  run scripts/check.sh doctor
  assert_failure 1
  assert_equal "$(fails)" 2
  assert_output --partial "FAIL: scripts/check.sh still has NOT CONFIGURED checks: lint --changed,lint,test,build,dependency audit"
  assert_output --partial "FAIL: untailored kit content in:"
}

@test "tailored install: exit 0" {
  tailor
  run scripts/check.sh doctor
  assert_success
  assert_equal "$(fails)" 0
}

@test "a tailored install with no open items has no false O-id FAIL from CLAUDE.md" {
  tailor
  printf '# Open items\n\n(none)\n' >docs/open.md
  git add -A && git commit -qm "no open items"
  run scripts/check.sh doctor
  assert_success
  refute_output --partial "is referenced"
}

@test "an undeclared open-item ID in code fails" {
  tailor
  echo "# see O42" >>scripts/lint-hook.sh
  git add -A && git commit -qm o42
  run scripts/check.sh doctor
  assert_failure 1
  assert_output --partial "FAIL: O42 is referenced but is in neither docs/open.md nor docs/decisions.md"
}

@test "no false O-id FAILs: binary files, README, CHANGELOG and docs/research" {
  tailor
  printf 'bin\000 O7 \000' >blob.bin
  echo "O7 in readme" >>README.md
  echo "O8 in changelog" >CHANGELOG.md
  mkdir -p docs/research && echo "O9 in research" >docs/research/x.md
  git add -A && git commit -qm ids
  run scripts/check.sh doctor
  assert_success
}

@test "DOCTOR_SKIP_PATHS leaves the named paths out of the O-id scan" {
  tailor
  mkdir -p vendor/kit && echo "O77 example" >vendor/kit/HOW.md
  mkdir -p other && echo "O78 example" >other/x.md
  git add -A && git commit -qm vendored
  run env DOCTOR_SKIP_PATHS="vendor other" bash scripts/doctor.sh
  assert_success
  run bash scripts/doctor.sh
  assert_output --partial "O77 is referenced"
}

@test "warns on effort and model overrides in the environment" {
  tailor
  run env CLAUDE_CODE_EFFORT_LEVEL=high CLAUDE_CODE_SUBAGENT_MODEL_FORCE=sonnet scripts/check.sh doctor
  assert_success
  assert_output --partial "warn: CLAUDE_CODE_EFFORT_LEVEL is set"
  assert_output --partial "warn: CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set"
}

@test "warns on a Claude Code older than 2.1.292, not on a newer one" {
  tailor
  run env STUB_CLAUDE_VERSION=2.1.291 scripts/check.sh doctor
  assert_output --partial "warn: Claude Code 2.1.291 is older than 2.1.292"
  run env STUB_CLAUDE_VERSION=2.1.292 scripts/check.sh doctor
  refute_output --partial "is older than"
}

@test "warns on Sonnet below high, effort: max, and a reviewer at low" {
  tailor
  scripts/set-models.sh lite >/dev/null
  sed -i.bak 's/^effort: high$/effort: medium/' .claude/agents/writer.md
  sed -i.bak 's/^effort: high$/effort: max/' .claude/agents/planner.md
  sed -i.bak 's/^effort: high$/effort: low/' .claude/agents/reviewer.md
  rm -f .claude/agents/*.bak
  run scripts/check.sh doctor
  assert_output --partial "warn: writer is sonnet at effort: medium"
  assert_output --partial "warn: planner has effort: max"
  assert_output --partial "warn: reviewer has effort: low"
}

@test "warns when codex-reviewer is on but codex is missing, and on CODEX_API_KEY in a workflow" {
  tailor
  mkdir -p .claude/agents && mv .claude/optional/codex-reviewer.md .claude/agents/
  echo "      CODEX_API_KEY: x" >>.github/workflows/check.yml
  path_without codex
  run bash scripts/doctor.sh
  assert_output --partial "warn: codex-reviewer is enabled but the codex CLI is not installed"
  assert_output --partial "warn: CODEX_API_KEY in .github/workflows"
}

@test "warns on unmerged .kit files and an unfinished kit-upgrade.md" {
  tailor
  echo x >CLAUDE.md.kit
  echo x >.claude/kit-upgrade.md
  run scripts/check.sh doctor
  assert_output --partial "warn: 1 unmerged *.kit file(s)"
  assert_output --partial "warn: upgrade merge not finished"
}

@test "codex report stats read every report, including a file name with a space" {
  tailor
  mkdir -p docs/reviews
  printf -- '- [x] [90] fixed\n' >docs/reviews/2026-01-01-000000-abc-codex.md
  printf -- '- [x] [80] a dismissed: noise\n' >"docs/reviews/2026-01-02 copy-abc-codex.md"
  printf -- '- [ ] [90] open\n' >docs/reviews/2026-01-01-000000-abc-review.md
  run bash scripts/doctor.sh
  assert_success
  assert_output --partial "codex (30d): reports 2 fixed 1 dismissed 1"
}

@test "warns when a tailored check.sh does not call check-stamp" {
  tailor
  sed -i.bak '/check-stamp/d' scripts/check.sh && rm -f scripts/check.sh.bak
  run bash scripts/doctor.sh
  assert_output --partial "warn: scripts/check.sh does not call check-stamp"
}

@test "review stats count incomplete reports and unverified quotes" {
  tailor
  mkdir -p docs/reviews
  printf -- '- [ ] [90] a\nstatus: incomplete (missing: ### Coverage)\nquotes: 1 verified, 2 unverified, 0 unquoted\n' >docs/reviews/2026-01-01-000000-abc-review.md
  printf -- '- [ ] [90] b\nstatus: complete\nquotes: 0 verified, 1 unverified, 1 unquoted\n' >docs/reviews/2026-01-02-000000-abc-review.md
  run bash scripts/doctor.sh
  assert_output --partial "unmarked: 2  incomplete: 1  unverified quotes: 3"
}
