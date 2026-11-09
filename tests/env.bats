#!/usr/bin/env bats
# The CI matrix asserts which bash runs the suite (macOS leg: /bin/bash 3.2).

load helpers

@test "the bash on PATH has the major version KIT_EXPECT_BASH names" {
  [[ -n "${KIT_EXPECT_BASH:-}" ]] || skip "KIT_EXPECT_BASH not set (set by CI)"
  run bash -c 'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"'
  assert_success
  case "$KIT_EXPECT_BASH" in
    *.*) assert_equal "$output" "$KIT_EXPECT_BASH" ;;
    *) assert_equal "${output%%.*}" "$KIT_EXPECT_BASH" ;;
  esac
}
