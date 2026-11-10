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
  for f in CLAUDE.md docs/*.md .claude/agents/*.md; do
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

@test "an undeclared open-item ID in a kit-owned file fails" {
  tailor
  echo "See O42." >>docs/conventions.md
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
  echo "O77 example" >docs/vendored.md
  mkdir -p .claude/agents/other && echo "O78 example" >.claude/agents/other.md
  git add -A && git commit -qm vendored
  run env DOCTOR_SKIP_PATHS="docs/vendored.md .claude/agents/other.md" bash scripts/doctor.sh
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

@test "warns on Sonnet below high, effort: max, and a reviewer at low" {
  tailor
  extras_on profiles
  scripts/set-models.sh lite >/dev/null
  sed -i.bak 's/^effort: high$/effort: medium/' .claude/agents/writer.md
  sed -i.bak 's/^effort: high$/effort: max/' .claude/agents/planner.md
  sed -i.bak 's/^effort: medium$/effort: low/' .claude/agents/reviewer.md
  rm -f .claude/agents/*.bak
  run scripts/check.sh doctor
  assert_output --partial "warn: writer is sonnet at effort: medium"
  assert_output --partial "warn: planner has effort: max"
  assert_output --partial "warn: reviewer has effort: low"
}

@test "warns when codex is on but the codex CLI is missing, and on CODEX_API_KEY in a workflow (via extras.sh status)" {
  tailor
  extras_on codex
  echo "      CODEX_API_KEY: x" >>.github/workflows/check.yml
  path_without codex
  run bash scripts/doctor.sh
  assert_output --partial "warn: codex is on but the codex CLI is not installed"
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

@test "warns when stop-warning is on and a tailored check.sh does not run check-stamp record, even if a comment names it (Opus 50)" {
  tailor
  extras_on stop-warning
  sed -i.bak '/check-stamp\.sh record/d' scripts/check.sh && rm -f scripts/check.sh.bak
  grep -q 'check-stamp' scripts/check.sh
  run bash scripts/doctor.sh
  assert_success
  assert_output --partial "warn: stop-warning is on but scripts/check.sh does not run scripts/check-stamp.sh record"
}

@test "no check-stamp warning while stop-warning is off, even without the stamp lines" {
  tailor
  sed -i.bak '/check-stamp\.sh record/d' scripts/check.sh && rm -f scripts/check.sh.bak
  run bash scripts/doctor.sh
  assert_success
  refute_output --partial "check-stamp"
}

@test "a half-enabled extra is a warning, not a FAIL" {
  tailor
  extras_on stop-warning
  python3 - .claude/settings.json <<'PY2'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
del d["hooks"]["Stop"]
open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY2
  run bash scripts/doctor.sh
  assert_success
  assert_equal "$(fails)" 0
  assert_output --partial "warn: stop-warning is on but .claude/settings.json has no Stop hook for scripts/check-stamp.sh"
}

@test "review stats print only with the metrics extra on" {
  tailor
  mkdir -p docs/reviews
  printf -- '- [ ] [90] a\n' >docs/reviews/2026-01-01-000000-abc-review.md
  run bash scripts/doctor.sh
  refute_output --partial "reviews (30d)"
  extras_on metrics
  run bash scripts/doctor.sh
  assert_output --partial "reviews (30d): 1 "
}

@test "no false O-id FAILs from compiler flags, product names or files the kit does not own (B4)" {
  tailor
  printf 'CFLAGS = -O2\n' >Makefile
  echo "Office O365 licences" >README.md
  echo "Build with -O2 or -O3, never O0-style names like xO5." >>docs/conventions.md
  mkdir -p src && echo "// see O99" >src/app.c
  git add -A && git commit -qm flags
  run bash scripts/doctor.sh
  assert_success
  refute_output --partial "is referenced"
}

@test "a tailored repo that kept the TAILOR.md CI gate gets a warning, not a FAIL; removing the gate clears it (A6)" {
  tailor
  git rm -q TAILOR.md && git commit -qm "tailoring done"
  run bash scripts/doctor.sh
  assert_success
  assert_output --partial "warn: the untailored-kit gate (hashFiles('TAILOR.md')) is still in: .github/workflows/check.yml"
  python3 - .github/workflows/check.yml <<'PY2'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"      - name: Kit not tailored yet\n(        .*\n)+", "", s)
s = "\n".join(l for l in s.split("\n") if "if: hashFiles('TAILOR.md')" not in l)
open(p, "w").write(s)
PY2
  run bash scripts/doctor.sh
  assert_success
  refute_output --partial "untailored-kit gate"
}

@test "CRLF frontmatter is read (portable, no GNU sed escape) (B10)" {
  tailor
  extras_on profiles
  scripts/set-models.sh lite >/dev/null
  sed -i.bak 's/^effort: high$/effort: medium/' .claude/agents/writer.md && rm -f .claude/agents/writer.md.bak
  awk '{ printf "%s\r\n", $0 }' .claude/agents/writer.md >w && mv w .claude/agents/writer.md
  run bash scripts/doctor.sh
  assert_output --partial "warn: writer is sonnet at effort: medium"
}

@test "warns when a non-Anthropic provider is selected (C13)" {
  tailor
  run env CLAUDE_CODE_USE_BEDROCK=1 bash scripts/doctor.sh
  assert_output --partial "warn: CLAUDE_CODE_USE_BEDROCK is set"
}

@test "warns when the reviewer runs on the writer's model; the shipped agents and every profile do not (addendum 3)" {
  tailor
  run bash scripts/doctor.sh
  refute_output --partial "reviewer and writer both use model"
  extras_on profiles
  for p in lite standard max; do
    scripts/set-models.sh "$p" >/dev/null
    run bash scripts/doctor.sh
    refute_output --partial "reviewer and writer both use model"
  done
  sed -i.bak 's/^model: .*/model: opus/' .claude/agents/writer.md .claude/agents/reviewer.md && rm -f .claude/agents/*.bak
  run bash scripts/doctor.sh
  assert_success
  assert_output --partial "warn: reviewer and writer both use model: opus: the reviewer runs on the writer's model; it reviews its own family's code"
}

@test "a missing effort: line is warned about and the message names both fixes (item C)" {
  tailor
  sed -i.bak '/^effort:/d' .claude/agents/security-auditor.md && rm -f .claude/agents/*.bak
  run scripts/check.sh doctor
  assert_output --partial "warn: security-auditor has no effort: add an \`effort:\` line to its frontmatter (or, with the profiles extra on, run \`scripts/set-models.sh <profile>\` if the seats are untailored)"
}

@test "doctor warns on an unmerged .kit-base" {
  tailor
  echo x >docs/conventions.md.kit-base
  run scripts/check.sh doctor
  assert_output --partial "warn: 1 unmerged *.kit file(s)"
}
