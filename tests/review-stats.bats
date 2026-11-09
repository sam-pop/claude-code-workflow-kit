#!/usr/bin/env bats
# template/.claude/optional/review-stats.sh (metrics extra): the review log stats doctor.sh printed
# before 1.6, now printed by doctor only while the extra is on.

# shellcheck disable=SC2153  # KIT and TARGET are set by helpers.bash
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
  extras_on metrics
  mkdir -p docs/reviews
}

@test "codex report stats read every report, including a file name with a space" {
  printf -- '- [x] [90] fixed\n' >docs/reviews/2026-01-01-000000-abc-codex.md
  printf -- '- [x] [80] a dismissed: noise\n' >"docs/reviews/2026-01-02 copy-abc-codex.md"
  printf -- '- [ ] [90] open\n' >docs/reviews/2026-01-01-000000-abc-review.md
  run scripts/review-stats.sh
  assert_success
  assert_output --partial "codex (30d): reports 2 fixed 1 dismissed 1"
}

@test "review stats count incomplete reports and unverified quotes" {
  printf -- '- [ ] [90] a\nstatus: incomplete (missing: ### Coverage)\nquotes: 1 verified, 2 unverified, 0 unquoted\n' >docs/reviews/2026-01-01-000000-abc-review.md
  printf -- '- [ ] [90] b\nstatus: complete\nquotes: 0 verified, 1 unverified, 1 unquoted\n' >docs/reviews/2026-01-02-000000-abc-review.md
  run scripts/review-stats.sh
  assert_output --partial "unmarked: 2  incomplete: 1  unverified quotes: 3"
}

@test "the review stats count only reports from the last 30 days (M6)" {
  printf -- '- [ ] [90] a\n' >docs/reviews/2020-01-01-000000-abc-review.md
  printf -- '- [ ] [90] b\n' >docs/reviews/2026-01-01-000000-abc-review.md
  touch -t 202001010000 docs/reviews/2020-01-01-000000-abc-review.md
  run scripts/review-stats.sh
  assert_output --partial "reviews (30d): 1 "
}

@test "no reports: prints nothing and exits 0, also without docs/reviews/" {
  run scripts/review-stats.sh
  assert_success
  assert_output ""
  rm -rf docs/reviews
  run scripts/review-stats.sh
  assert_success
  assert_output ""
}

@test "agreement rate and repeated dismissals; exit 0 even when the last count is zero" {
  printf -- '- [x] [90] a dismissed: style nit\n- [x] [80] b dismissed: style nit\n' >docs/reviews/2026-01-01-000000-abc-review.md
  run scripts/review-stats.sh
  assert_success
  assert_output --partial "agreement rate: 0%"
  assert_output --partial "promote to false-positives?  2 dismissed: style nit"
}
