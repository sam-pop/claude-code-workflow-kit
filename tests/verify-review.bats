#!/usr/bin/env bats
# template/scripts/verify-review.sh: sections, quotes and coverage of a saved review.

# shellcheck disable=SC2153  # KIT and TARGET are set by helpers.bash
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
  mkdir -p src
  printf '%s\n' "line one" "line two" "const total = items.reduce((a, b) => a + b, 0);" "line four" \
    "line five" "line six" "line seven" "line eight" "line nine" "line ten" >src/app.js
  echo "old helper" >src/old.js
  git add -A && git commit -qm base
  git checkout -q -b feature
  sed -i.bak 's/line four/line 4 changed/' src/app.js && rm -f src/app.js.bak
  git rm -q src/old.js
  git commit -qm change
  REPORT=docs/reviews/2026-01-01-000000-abc-review.md
  mkdir -p docs/reviews
}

# report <findings block> [coverage block] [kind]: a complete report with the given parts.
report() {
  local cov="${2:-read: src/app.js, src/old.js}"
  {
    if [[ "${3:-}" == codex ]]; then echo "## Codex review: high main..worktree"; else echo "## Review: change"; fi
    echo
    echo "### Summary"
    echo "ok"
    if [[ "${3:-}" != codex ]]; then printf '\n### Run\ntier: Medium\n'; fi
    printf '\n### Checks\nlint: 0\n\n### Standards\n%s\n\n### Spec\n\n### Considered, below threshold\n\n### Not reviewed\nnone\n\n### Coverage\n%s\n' "$1" "$cov"
  } >"$REPORT"
}

verify() { scripts/verify-review.sh "$REPORT"; }

@test "an exact quote is verified; complete and covered exits 0" {
  report $'- [ ] [90] `src/app.js:3` — wrong\n  > const total = items.reduce((a, b) => a + b, 0);'
  run verify
  assert_success
  assert_line "### Verification"
  assert_line "status: complete"
  assert_line "quotes: 1 verified, 0 unverified, 0 unquoted"
  assert_line "coverage: 2 changed files, 0 not in ### Coverage"
  assert_line --regexp '^checked: .* · base: main@[0-9a-f]{7} · scripts/verify-review.sh$'
}

@test "an altered quote is unverified and exits 1" {
  report $'- [ ] [92] src/app.js:3 — wrong\n  > const total = items.reduce((a, b) => a * b, 0);'
  run verify
  assert_failure 1
  assert_line "quotes: 0 verified, 1 unverified, 0 unquoted"
  assert_line "- unverified [92] src/app.js:3 — quote not found within ±3 lines"
}

@test "an elided quote is verified when its parts appear in order" {
  report $'- [ ] [90] src/app.js:3 — wrong\n  > const total = … a + b, 0);'
  run verify
  assert_success
  report $'- [ ] [90] src/app.js:3 — wrong\n  > a + b, 0); ... const total'
  run verify
  assert_failure 1
}

@test "a quote of a removed line is verified (removed)" {
  report $'- [ ] [90] src/old.js:1 — deleted helper still used\n  > (removed) old helper'
  run verify
  assert_success
  assert_line "quotes: 1 verified, 0 unverified, 0 unquoted"
}

@test "a finding with no quote is counted unquoted" {
  report $'- [x] [90] src/app.js:3 — wrong'
  run verify
  assert_failure 1
  assert_line "quotes: 0 verified, 0 unverified, 1 unquoted"
}

@test "a short path resolves by unique suffix against the changed files" {
  report $'- [ ] [90] app.js:4 — changed\n  > line 4 changed'
  run verify
  assert_success
}

@test "a quote 4 lines away from the cited line is unverified" {
  report $'- [ ] [90] src/app.js:8 — wrong\n  > line 4 changed'
  run verify
  assert_failure 1
  report $'- [ ] [90] src/app.js:7 — wrong\n  > line 4 changed'
  run verify
  assert_success
}

@test "a changed file missing from Coverage is listed" {
  report $'- [ ] [90] src/app.js:3 — wrong\n  > const total' "read: src/app.js"
  run verify
  assert_failure 1
  assert_line "coverage: 2 changed files, 1 not in ### Coverage: src/old.js"
}

@test "untracked files count as changed; docs/reviews/ does not" {
  echo new >src/new.js
  report $'- [ ] [90] src/app.js:3 — wrong\n  > const total'
  run verify
  assert_failure 1
  assert_line "coverage: 3 changed files, 1 not in ### Coverage: src/new.js"
}

@test "a missing ### Checks makes the report incomplete" {
  report $'- [ ] [90] src/app.js:3 — wrong\n  > const total'
  sed -i.bak '/^### Checks$/d' "$REPORT" && rm -f "$REPORT.bak"
  run verify
  assert_failure 1
  assert_line "status: incomplete (missing: ### Checks)"
}

@test "a codex report without ### Run is complete" {
  report $'- [ ] [90] src/app.js:3 — wrong\n  > const total' "read: src/app.js, src/old.js" codex
  run verify
  assert_success
  assert_line "status: complete"
}

@test "no base branch: coverage is not checked" {
  report $'- [ ] [90] src/app.js:3 — wrong\n  > const total'
  run env BASE_BRANCH=nosuchbranch scripts/verify-review.sh "$REPORT"
  assert_line "coverage: not checked (no base)"
}

@test "a finding in a nonexistent file is unverified: file not found" {
  report $'- [ ] [90] src/ghost.js:1 — wrong\n  > anything'
  run verify
  assert_failure 1
  assert_line "- unverified [90] src/ghost.js:1 — file not found"
}

@test "usage: no argument or a missing file exits 2" {
  run scripts/verify-review.sh
  assert_failure 2
  run scripts/verify-review.sh docs/reviews/none.md
  assert_failure 2
}
