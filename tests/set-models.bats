#!/usr/bin/env bats
# template/.claude/optional/set-models.sh (profiles extra): profiles, warnings, usage errors, CRLF.

# shellcheck disable=SC2153  # KIT and TARGET are set by helpers.bash
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
  extras_on profiles
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

@test "--cross exits 2 and points at extras.sh on codex; no codex-reviewer file moves" {
  run scripts/set-models.sh standard --cross
  assert_failure 2
  assert_output --partial "cross-model review: scripts/extras.sh on codex"
  [[ -f .claude/optional/codex-reviewer.md && ! -e .claude/agents/codex-reviewer.md ]]
}

@test "the dormant copy refuses to run: the profiles extra is off (exit 1)" {
  bash scripts/extras.sh off profiles >/dev/null
  run .claude/optional/set-models.sh standard
  assert_failure 1
  assert_output --partial "scripts/extras.sh on profiles"
}

@test "warns on a Claude Code older than 2.1.292, not on a newer one (moved from doctor)" {
  use_stub claude
  run env STUB_CLAUDE_VERSION=2.1.291 scripts/set-models.sh standard
  assert_success
  assert_output --partial "warn: Claude Code 2.1.291 is older than 2.1.292"
  run env STUB_CLAUDE_VERSION=2.1.292 scripts/set-models.sh standard
  refute_output --partial "is older than"
}

@test "notes Fable billing on max only, and warns on effortLevel in ~/.claude/settings.json" {
  run scripts/set-models.sh standard
  refute_output --partial "Fable bills"
  run scripts/set-models.sh max
  assert_output --partial "Fable bills usage credits"
  mkdir -p "$HOME/.claude" && echo '{"effortLevel": "high"}' >"$HOME/.claude/settings.json"
  run scripts/set-models.sh standard
  assert_output --partial "warn: effortLevel in ~/.claude/settings.json is ignored"
}

@test "no effortLevel warning when modelSettings sets Opus 5.5's effort; a top-level effortLevel alone still warns" {
  mkdir -p "$HOME/.claude"
  echo '{"effortLevel": "xhigh", "modelSettings": {"claude-opus-5-5": {"effortLevel": "medium"}}}' >"$HOME/.claude/settings.json"
  run scripts/set-models.sh standard
  assert_success
  refute_output --partial "warn: effortLevel"
  echo '{"modelSettings": {"claude-opus-5": {"effortLevel": "high"}}, "effortLevel": "high"}' >"$HOME/.claude/settings.json"
  run scripts/set-models.sh standard
  assert_output --partial "warn: effortLevel in ~/.claude/settings.json is ignored"
  echo '{not json' >"$HOME/.claude/settings.json"
  run scripts/set-models.sh standard
  assert_success
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

@test "no profile puts the reviewer on the writer's model (addendum 1)" {
  for p in lite standard max; do
    scripts/set-models.sh "$p" >/dev/null
    [[ "$(field writer model)" != "$(field reviewer model)" ]] || fail "$p: writer and reviewer both on $(field writer model)"
  done
  assert_equal "$(grep -E '^#   (lite|standard|max) +[a-z]+/' scripts/set-models.sh | tr -s ' ')" "# lite sonnet/high sonnet/high opus/medium opus/high
# standard opus/high sonnet/high opus/high opus/xhigh
# max opus/high opus/medium fable/high fable/high"
}

@test "the shipped agents are the standard profile: set-models.sh standard changes nothing (addendum 1)" {
  bash scripts/extras.sh off profiles >/dev/null
  cat .claude/agents/*.md >"$BATS_TEST_TMPDIR/shipped"
  bash scripts/extras.sh on profiles >/dev/null
  scripts/set-models.sh standard >/dev/null
  cat .claude/agents/*.md | cmp - "$BATS_TEST_TMPDIR/shipped"
}

@test "a tailored seat is refused with role, current and target, and no file changes; --force applies; untailored applies (item C)" {
  scripts/set-models.sh standard >/dev/null
  # a hand-tailored reviewer: fable at medium is none of the reviewer's profile values
  sed -i.bak 's/^model: .*/model: fable/; s/^effort: .*/effort: medium/' .claude/agents/reviewer.md && rm .claude/agents/reviewer.md.bak
  cat .claude/agents/*.md >"$BATS_TEST_TMPDIR/before"
  run scripts/set-models.sh lite
  assert_failure 1
  assert_output --partial "refused: reviewer is fable/medium"
  assert_output --partial "would set it to opus/medium"
  assert_output --partial "--force"
  cat .claude/agents/*.md >"$BATS_TEST_TMPDIR/after"
  cmp "$BATS_TEST_TMPDIR/before" "$BATS_TEST_TMPDIR/after"
  run scripts/set-models.sh lite --force
  assert_success
  assert_equal "$(field reviewer model)/$(field reviewer effort)" opus/medium
  # an untailored seat (a value of another profile) is switched without --force
  run scripts/set-models.sh max
  assert_success
  assert_equal "$(field reviewer model)/$(field reviewer effort)" fable/high
  run scripts/set-models.sh standard
  assert_success
  assert_equal "$(field writer model)/$(field writer effort)" sonnet/high
}

@test "a legacy seat with a profile model and no effort: line is not tailored (item C)" {
  sed -i.bak '/^effort:/d' .claude/agents/writer.md && rm .claude/agents/writer.md.bak
  run scripts/set-models.sh standard
  assert_success
  assert_equal "$(field writer effort)" high
}

# Write model/effort into the four agents, as an earlier kit's set-models.sh left them.
seats() {
  local role pair
  for pair in "planner:$1" "writer:$2" "reviewer:$3" "security-auditor:$4"; do
    role=${pair%%:*}
    sed -i.bak "s#^model: .*#model: ${pair#*:}#; s#^effort: .*#effort: ${pair##*/}#" ".claude/agents/$role.md"
    sed -i.bak "s#^model: \\(.*\\)/.*#model: \\1#" ".claude/agents/$role.md" && rm ".claude/agents/$role.md.bak"
  done
}

@test "seats an earlier kit's lite or max profile wrote are re-applied without --force (1.5 upgrade)" {
  # 1.5 lite: the reviewer was sonnet/high, on the writer's model
  seats sonnet/high sonnet/high sonnet/high opus/high
  assert_equal "$(field reviewer model)/$(field reviewer effort)" sonnet/high
  run scripts/set-models.sh lite
  assert_success
  assert_equal "$(field reviewer model)/$(field reviewer effort)" opus/medium
  # 1.5 max: the planner was fable/high and the reviewer opus/high, on the writer's model
  seats fable/high opus/medium opus/high fable/high
  run scripts/set-models.sh max
  assert_success
  assert_equal "$(field planner model)/$(field planner effort)" opus/high
  assert_equal "$(field reviewer model)/$(field reviewer effort)" fable/high
}
