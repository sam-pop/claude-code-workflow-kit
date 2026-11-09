#!/usr/bin/env bats
# template/scripts/capture-review.sh: which reports are saved, and that it never fails.

# shellcheck disable=SC2153,SC2016  # KIT and TARGET come from helpers.bash; backticks in reports are literal
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
  assert_equal "$(head -2 "$f")" $'## Review: x\nbody'
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

# A complete review of the install commit's README change, with one finding and its quote.
good_review() {
  printf '## Review: x\n\n### Summary\nok\n\n### Run\ntier: Low\n\n### Checks\nlint: 0\n\n### Standards\n- [ ] [90] `README.md:1` — title\n  > %s\n\n### Spec\n\n### Considered, below threshold\n\n### Not reviewed\nnone\n\n### Coverage\nread: README.md\n' "$1"
}

on_branch_with_readme_change() {
  git checkout -q -b feature
  echo "# changed title" >README.md
  git commit -qam change
}

@test "a clean review gets a Verification block and no message" {
  on_branch_with_readme_change
  run bash -c "$(declare -f stop_json good_review); stop_json \"\$(good_review '# changed title')\" | scripts/capture-review.sh stop"
  assert_success
  assert_output ""
  f=$(saved)
  run grep -c '^### Verification$' "$f"
  assert_output 1
  grep -q '^quotes: 1 verified, 0 unverified, 0 unquoted$' "$f"
}

@test "a review with a made-up quote gets a Verification block and a systemMessage" {
  on_branch_with_readme_change
  run bash -c "$(declare -f stop_json good_review); stop_json \"\$(good_review 'code that is not there')\" | scripts/capture-review.sh stop"
  assert_success
  assert_output --regexp '^\{"systemMessage": "Review saved to docs/reviews/[^"]*-review\.md: status: complete; quotes: 0 verified, 1 unverified, 0 unquoted; coverage: 1 changed files, 0 not in ### Coverage"\}$'
  grep -q '^- unverified \[90\] README.md:1' "$(saved)"
}

@test "security and stuck reports are saved without verification" {
  stop_json $'## Security audit: x\nbody' | scripts/capture-review.sh stop
  run grep -c Verification "$(saved)"
  assert_output 0
}
