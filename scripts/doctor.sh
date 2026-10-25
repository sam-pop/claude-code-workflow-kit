#!/usr/bin/env bash
# Kit hygiene. Called by `scripts/check.sh doctor`. Exits non-zero on a FAIL.
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
fail() { echo "FAIL: $*"; rc=1; }
warn() { echo "warn: $*"; }

# 1. CLAUDE.md stays an index.
if [[ -f CLAUDE.md ]]; then
  n=$(wc -l < CLAUDE.md)
  (( n > 150 )) && fail "CLAUDE.md is $n lines (cap 150); move history to handoff.md or docs/"
else
  fail "CLAUDE.md missing"
fi

# 2. No kit placeholders left behind.
SKIP='TAILOR.md|HOW-TO-USE.md|scripts/doctor.sh'
if grep -rIl --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=docs/reviews -e '{{' -e '<!-- kit:' . 2>/dev/null | grep -qvE "$SKIP"; then
  fail "placeholders remain:"; grep -rIl --exclude-dir=.git --exclude-dir=node_modules -e '{{' -e '<!-- kit:' . | grep -vE "$SKIP" | sed 's/^/  /'
fi

# 3. Every O-id referenced anywhere exists in open.md or decisions.md.
if [[ -f docs/open.md ]]; then
  known=$(grep -ohE '\bO[0-9]+\b' docs/open.md docs/decisions.md 2>/dev/null | sort -u)
  used=$(grep -rIlE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=docs/reviews '\bO[0-9]+\b' . 2>/dev/null | grep -vE "$SKIP" | xargs -r grep -ohE '\bO[0-9]+\b' | sort -u)
  for id in $used; do
    grep -qx "$id" <<<"$known" || fail "$id is referenced but is in neither docs/open.md nor docs/decisions.md"
  done
fi

# 4. handoff.md is not stale (committed repos only).
if [[ -f handoff.md ]] && git ls-files --error-unmatch handoff.md >/dev/null 2>&1; then
  since=$(git log --oneline -- handoff.md | head -1 | cut -d' ' -f1)
  if [[ -n "$since" ]]; then
    behind=$(git rev-list --count "$since"..HEAD 2>/dev/null || echo 0)
    (( behind > 5 )) && warn "handoff.md last changed $behind commits ago"
  fi
fi

# 5. Review log stats (last 30 days) for the monthly pass.
if [[ -d docs/reviews ]]; then
  recent=$(find docs/reviews -name '*.md' -mtime -30 | wc -l)
  blocking=$(grep -rh '^\- \[ \] \[[0-9]' docs/reviews --include='*-review.md' 2>/dev/null | wc -l)
  dismissed=$(grep -rhc 'dismissed:' docs/reviews 2>/dev/null | awk '{s+=$1} END {print s+0}')
  echo "reviews last 30d: $recent  open findings: $blocking  dismissed total: $dismissed"
  # Recurring dismissal reasons → candidates for the reviewer's false-positives list.
  grep -rhoE 'dismissed: .*' docs/reviews 2>/dev/null | sort | uniq -c | awk '$1>=2 {print "  recurring dismissal (promote to false-positives?):", $0}'
fi

exit $rc
