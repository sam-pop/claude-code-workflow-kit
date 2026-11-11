#!/usr/bin/env bats
# tests/helpers.bash isolate(): a git variable inherited from the outer environment must not make the
# scratch repositories write into, or read from, another repository.

# shellcheck disable=SC2153  # TARGET is set by helpers.bash
load helpers

@test "isolate: GIT_DIR, GIT_OBJECT_DIRECTORY and GIT_NAMESPACE from the outer environment never reach the scratch repo" {
  decoy="$BATS_TEST_TMPDIR/decoy"
  mkdir -p "$decoy/objects" "$decoy/alt"
  git init -q --bare "$decoy/decoy.git"
  export GIT_DIR="$decoy/decoy.git" GIT_OBJECT_DIRECTORY="$decoy/objects" \
    GIT_ALTERNATE_OBJECT_DIRECTORIES="$decoy/alt" GIT_NAMESPACE=decoy GIT_COMMON_DIR="$decoy/decoy.git"
  before=$(find "$decoy" -type f | sort | tr '\n' ' ')
  isolate
  installed_target
  cd "$TARGET" || exit 1
  extras_on verify-review
  echo changed >>README.md
  git add -A && git commit -qm more
  assert_equal "$(git rev-parse --git-dir)" ".git"
  assert_equal "$(find "$decoy" -type f | sort | tr '\n' ' ')" "$before"
}
