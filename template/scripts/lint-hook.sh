#!/usr/bin/env bash
# PostToolUse hook after Edit/Write: lint the changed files. On failure, exit 2 with the output on
# stderr so Claude sees it and fixes it; on success, stay silent (exit 0 output is not shown to Claude).
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/..}" || exit 0
out=$(scripts/check.sh lint --changed 2>&1); rc=$?
grep -q 'NOT CONFIGURED' <<<"$out" && exit 0   # quiet until the kit is tailored
if [[ $rc -ne 0 ]]; then
  printf 'Lint failed after your edit. Fix before continuing:\n%s\n' "$(tail -n 40 <<<"$out")" >&2
  exit 2
fi
exit 0
