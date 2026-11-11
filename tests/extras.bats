#!/usr/bin/env bats
# template/scripts/extras.sh: switching extras on and off (one file each), status, refusals, and the
# retired stop-warning.

# shellcheck disable=SC2153,SC2016  # KIT and TARGET are set by helpers.bash; sed scripts hold literal $
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
}

@test "fresh install: every extra off, status exit 0, and stop-warning is not an extra any more" {
  run bash scripts/extras.sh status
  assert_success
  assert_output "codex: off
profiles: off
verify-review: off
metrics: off"
}

@test "both copies exist: on and off exit 1 and move nothing" {
  cp .claude/optional/verify-review.sh scripts/verify-review.sh
  run bash scripts/extras.sh on verify-review
  assert_failure 1
  assert_output --partial "both .claude/optional/verify-review.sh and scripts/verify-review.sh exist"
  run bash scripts/extras.sh off verify-review
  assert_failure 1
  [[ -f .claude/optional/verify-review.sh && -f scripts/verify-review.sh ]]
  run bash scripts/extras.sh status
  assert_failure 1
  assert_output --partial "warn: verify-review: both"
}

@test "unknown extra and bad arguments exit 2" {
  for args in "on nope" "" "on" "status extra" "flip codex"; do
    # shellcheck disable=SC2086  # split the argument list on purpose
    run bash scripts/extras.sh $args
    assert_failure 2
  done
}

@test "an extra that is not installed: on exits 1, off and status say not installed" {
  rm .claude/optional/review-stats.sh
  run bash scripts/extras.sh on metrics
  assert_failure 1
  assert_output --partial "metrics is not installed"
  run bash scripts/extras.sh off metrics
  assert_success
  assert_output --partial "metrics: not installed"
  run bash scripts/extras.sh status
  assert_line "metrics: not installed"
}

@test "a symlinked scripts/ leading out of the repo refuses and writes nothing outside" {
  out="$BATS_TEST_TMPDIR/outside"
  mv scripts "$out"
  ln -s "$out" scripts
  before=$(cd "$out" && ls)
  run env KIT_EXTRAS_REPO="$TARGET" bash "$out/extras.sh" on profiles
  assert_failure 1
  assert_output --partial "scripts/set-models.sh resolves outside the repo"
  assert_equal "$(cd "$out" && ls)" "$before"
  [[ -f .claude/optional/set-models.sh ]]
}

@test "codex on and off moves the agent and keeps edits; on without the codex CLI warns" {
  echo "my edit" >>.claude/optional/codex-reviewer.md
  path_without codex
  run bash scripts/extras.sh on codex
  assert_success
  assert_output --partial "warn: Codex CLI not installed"
  assert_output --partial "leave for OpenAI"
  [[ -f .claude/agents/codex-reviewer.md && ! -e .claude/optional/codex-reviewer.md ]]
  run bash scripts/extras.sh status
  assert_failure 1
  assert_output --partial "warn: codex is on but the codex CLI is not installed"
  bash scripts/extras.sh off codex >/dev/null
  [[ -f .claude/optional/codex-reviewer.md && ! -e .claude/agents/codex-reviewer.md ]]
  run tail -1 .claude/optional/codex-reviewer.md
  assert_output "my edit"
}

@test "CLAUDE_PROJECT_DIR (reserved for hooks) is ignored: extras.sh acts on its own repo; KIT_EXTRAS_REPO selects another (item 12)" {
  other="$BATS_TEST_TMPDIR/other"
  mkdir -p "$other/.claude/optional"
  run env CLAUDE_PROJECT_DIR="$other" bash scripts/extras.sh status
  assert_success
  assert_line "profiles: off"
  run env CLAUDE_PROJECT_DIR="$other" bash scripts/extras.sh on metrics
  assert_success
  [[ -f scripts/review-stats.sh && ! -e .claude/optional/review-stats.sh ]]
  run env KIT_EXTRAS_REPO="$other" bash scripts/extras.sh status
  assert_line "metrics: not installed"
}

@test "on metrics refuses when .claude/optional is a symlink to a directory outside the repo; the outside file stays (audit L2)" {
  out="$BATS_TEST_TMPDIR/outside"
  mv .claude/optional "$out"
  ln -s "$out" .claude/optional
  run bash scripts/extras.sh on metrics
  assert_failure 1
  assert_output --partial ".claude/optional/review-stats.sh resolves outside the repo"
  [[ -f "$out/review-stats.sh" && ! -e scripts/review-stats.sh ]]
}

@test "on stop-warning says it was retired in 1.8, exits 1 and changes nothing; off exits 0 and changes nothing" {
  git status --short >"$BATS_TEST_TMPDIR/before"
  run bash scripts/extras.sh on stop-warning
  assert_failure 1
  assert_output --partial "stop-warning was retired in 1.8"
  run bash scripts/extras.sh off stop-warning
  assert_success
  assert_output --partial "stop-warning was retired in 1.8"
  git status --short >"$BATS_TEST_TMPDIR/after"
  cmp "$BATS_TEST_TMPDIR/before" "$BATS_TEST_TMPDIR/after"
  [[ ! -e scripts/check-stamp.sh && ! -e .claude/optional/check-stamp.sh ]]
}

@test "sync is gone: extras.sh sync is a usage error (exit 2)" {
  run bash scripts/extras.sh sync
  assert_failure 2
}

@test "a 1.7 repo's leftovers (Stop hook, check-stamp.sh, stuck-detect.sh and a stamp line in check.sh) never make status warn or fail" {
  mkdir -p .claude
  echo '#!/usr/bin/env bash' >scripts/check-stamp.sh
  echo '#!/usr/bin/env bash' >scripts/stuck-detect.sh
  echo '[[ -f scripts/stuck-detect.sh ]] && exec bash scripts/stuck-detect.sh "$@"' >>scripts/check.sh
  python3 -I - <<'PY2'
import json
p = ".claude/settings.json"
d = json.load(open(p))
d.setdefault("hooks", {})["Stop"] = [{"hooks": [{"type": "command", "command": "\"${CLAUDE_PROJECT_DIR}/scripts/check-stamp.sh\" hook", "timeout": 30}]}]
open(p, "w").write(json.dumps(d, indent=2) + "\n")
PY2
  run bash scripts/extras.sh status
  assert_success
  assert_output "codex: off
profiles: off
verify-review: off
metrics: off"
}

@test "profiles is one file: on and off move only set-models.sh" {
  run bash scripts/extras.sh on profiles
  assert_success
  assert_output --partial "moved: .claude/optional/set-models.sh -> scripts/set-models.sh"
  [[ -x scripts/set-models.sh ]]
  [[ ! -e scripts/stuck-detect.sh && ! -e .claude/optional/stuck-detect.sh ]]
  run bash scripts/extras.sh off profiles
  assert_success
  [[ -f .claude/optional/set-models.sh && ! -e scripts/set-models.sh ]]
}

@test "on and off leave .claude/settings.json byte-identical for every extra" {
  cp .claude/settings.json "$BATS_TEST_TMPDIR/before"
  for x in codex profiles verify-review metrics; do
    bash scripts/extras.sh on "$x" >/dev/null
    bash scripts/extras.sh off "$x" >/dev/null
  done
  cmp .claude/settings.json "$BATS_TEST_TMPDIR/before"
}
