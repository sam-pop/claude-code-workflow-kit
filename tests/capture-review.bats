#!/usr/bin/env bats
# template/scripts/capture-review.sh: which reports are saved, and that it never fails.

# shellcheck disable=SC2153  # KIT and TARGET are set by helpers.bash
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
}

stop_json() { python3 -c 'import json,sys; print(json.dumps({"last_assistant_message": sys.argv[1]}))' "$1"; }
handback_json() { python3 -c 'import json,sys; print(json.dumps({"tool_input": {"message": sys.argv[1]}}))' "$1"; }
saved() { find docs/reviews -name '*-*.md' | sort; }

@test "review, security, codex and stuck reports are saved with their kind as suffix" {
  for pair in "## Review: x|review" "## Security audit: x|security" "## Codex review: x|codex" "## STUCK: x|stuck"; do
    stop_json "${pair%%|*}"$'\nbody' | scripts/capture-review.sh stop
    run saved
    assert_output --regexp "-${pair##*|}\.md"
  done
  assert_equal "$(saved | wc -l | tr -d ' ')" 4
  f=$(saved | grep -- '-review.md$')
  assert_equal "$(cat "$f")" $'## Review: x\nbody'
}

@test "any other message is ignored" {
  stop_json "Done. Files changed: a, b" | scripts/capture-review.sh stop
  stop_json "Some text ## Review: not first" | scripts/capture-review.sh stop
  assert_equal "$(saved | wc -l | tr -d ' ')" 0
}

@test "malformed hook JSON exits 0 and saves nothing" {
  run scripts/capture-review.sh stop <<<'{not json'
  assert_success
  assert_equal "$(saved | wc -l | tr -d ' ')" 0
}

@test "handback mode reads tool_input.message" {
  handback_json $'## STUCK: change\nRung: 1' | scripts/capture-review.sh handback
  run saved
  assert_output --regexp '-stuck\.md$'
  stop_json "## STUCK: wrong field" | scripts/capture-review.sh handback
  assert_equal "$(saved | wc -l | tr -d ' ')" 1
}

@test "without python3 the hook exits 0 and saves nothing" {
  path_without python3
  run scripts/capture-review.sh stop <<<'{"last_assistant_message": "## Review: x"}'
  assert_success
  [[ ! -d docs/reviews ]] || assert_equal "$(saved | wc -l | tr -d ' ')" 0
}
