#!/usr/bin/env bats
# template/scripts/set-models.sh: profiles, --cross, usage errors, CRLF.

# shellcheck disable=SC2153  # KIT and TARGET are set by helpers.bash
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
}

field() { awk -v k="$2:" 'NR>1 && /^---/ {exit} $1==k {print $2}' ".claude/agents/$1.md" | tr -d '\r'; }

@test "two runs of the same profile are byte-identical, with one effort: line per agent" {
  scripts/set-models.sh standard >/dev/null
  cat .claude/agents/*.md >"$BATS_TEST_TMPDIR/a"
  scripts/set-models.sh standard >/dev/null
  cat .claude/agents/*.md >"$BATS_TEST_TMPDIR/b"
  cmp "$BATS_TEST_TMPDIR/a" "$BATS_TEST_TMPDIR/b"
  for a in planner writer reviewer security-auditor; do
    assert_equal "$(grep -c '^effort:' ".claude/agents/$a.md")" 1
  done
}

@test "each profile writes the model/effort pairs in the script's header table" {
  for p in lite standard max; do
    scripts/set-models.sh "$p" >/dev/null
    row=$(grep -E "^#   $p +[a-z]+/" scripts/set-models.sh | sed "s/^#   $p  *//")
    got="$(field planner model)/$(field planner effort) $(field writer model)/$(field writer effort) $(field reviewer model)/$(field reviewer effort) $(field security-auditor model)/$(field security-auditor effort)"
    assert_equal "$got" "$(echo "$row" | tr -s ' ')"
  done
}

@test "--cross moves codex-reviewer to agents/ and back, keeping edits" {
  echo "my edit" >>.claude/optional/codex-reviewer.md
  run scripts/set-models.sh standard --cross
  assert_success
  assert_output --partial "cross-model review: on"
  [[ -f .claude/agents/codex-reviewer.md && ! -e .claude/optional/codex-reviewer.md ]]
  run scripts/set-models.sh standard
  assert_output --partial "cross-model review: off"
  [[ -f .claude/optional/codex-reviewer.md && ! -e .claude/agents/codex-reviewer.md ]]
  run tail -1 .claude/optional/codex-reviewer.md
  assert_output "my edit"
}

@test "--cross with neither codex-reviewer file exits 1 (R1-60)" {
  rm .claude/optional/codex-reviewer.md
  run scripts/set-models.sh standard --cross
  assert_failure 1
  assert_output --partial "neither exists"
}

@test "usage errors exit 2: no args, --cross alone, unknown profile, two profiles" {
  for args in "" "--cross" "foo" "lite max"; do
    # shellcheck disable=SC2086  # split the argument list on purpose
    run scripts/set-models.sh $args
    assert_failure 2
  done
}

@test "a CRLF agent file round-trips byte-identical (R1-55, R2-55)" {
  scripts/set-models.sh standard >/dev/null
  cp .claude/agents/writer.md "$BATS_TEST_TMPDIR/lf"
  awk '{ printf "%s\r\n", $0 }' "$BATS_TEST_TMPDIR/lf" >.claude/agents/writer.md
  cp .claude/agents/writer.md "$BATS_TEST_TMPDIR/crlf"
  scripts/set-models.sh lite >/dev/null
  scripts/set-models.sh standard >/dev/null
  cmp .claude/agents/writer.md "$BATS_TEST_TMPDIR/crlf"
}
