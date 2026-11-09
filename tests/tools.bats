#!/usr/bin/env bats
# scripts/tools.sh: a bad download or a failed unpack installs nothing and writes no version marker.
# curl is a stub that writes a local file; the pin table is replaced with one entry for that file.

# shellcheck disable=SC2016  # the curl stub is written with literal $ expressions
load helpers

setup() {
  isolate
  T="$BATS_TEST_TMPDIR/kit"
  mkdir -p "$T/scripts" "$BATS_TEST_TMPDIR/bin"
  cp "$REPO_ROOT/scripts/tools.sh" "$T/scripts/"
  # curl -sSfL --retry 2 -o <file> <url>: copies $STUB_CURL_FILE to <file>.
  printf '#!/usr/bin/env bash\nwhile [[ $# -gt 0 ]]; do [[ $1 == -o ]] && out=$2; shift; done\ncp "$STUB_CURL_FILE" "$out"\n' \
    >"$BATS_TEST_TMPDIR/bin/curl"
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

sha() { if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }

# pin <sha> <url> <member>: one tool, "fake", for both supported platforms.
pin() {
  python3 - "$T/scripts/tools.sh" "$@" <<'PY'
import re, sys
p, sha, url, member = sys.argv[1:5]
s = open(p).read()
rows = "".join(f"fake 1.0 {plat} {sha} {url} {member}\n" for plat in ("linux-x64", "darwin-arm64"))
s = re.sub(r"(?s)TABLE='\n.*?\n'", "TABLE='\n" + rows + "'", s)
open(p, "w").write(s)
PY
}

@test "wrong bytes: exit 1, nothing installed, no marker (Opus 86)" {
  echo "real" >"$BATS_TEST_TMPDIR/real"
  echo "tampered" >"$BATS_TEST_TMPDIR/served"
  pin "$(sha "$BATS_TEST_TMPDIR/real")" https://example.invalid/fake -
  run env STUB_CURL_FILE="$BATS_TEST_TMPDIR/served" "$T/scripts/tools.sh" install
  assert_failure 1
  assert_output --partial "checksum mismatch"
  [[ ! -e "$T/.tools/bin/fake" && ! -e "$T/.tools/bin/.fake.version" ]]
}

@test "right bytes but an archive tar cannot unpack: exit 1, no marker (Opus 86)" {
  echo "not a tarball" >"$BATS_TEST_TMPDIR/served"
  pin "$(sha "$BATS_TEST_TMPDIR/served")" https://example.invalid/fake.tar.gz fake
  run env STUB_CURL_FILE="$BATS_TEST_TMPDIR/served" "$T/scripts/tools.sh" install
  assert_failure 1
  assert_output --partial "could not unpack"
  [[ ! -e "$T/.tools/bin/.fake.version" ]]
}

@test "right bytes: installed, executable, marker written" {
  printf '#!/bin/sh\necho fake\n' >"$BATS_TEST_TMPDIR/served"
  pin "$(sha "$BATS_TEST_TMPDIR/served")" https://example.invalid/fake -
  run env STUB_CURL_FILE="$BATS_TEST_TMPDIR/served" "$T/scripts/tools.sh" install
  assert_success
  [[ -x "$T/.tools/bin/fake" ]]
  assert_equal "$(cat "$T/.tools/bin/.fake.version")" 1.0
}
