#!/usr/bin/env bash
# Kit hygiene. Called by `scripts/check.sh doctor` and `all`. Exits non-zero on any FAIL.
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
fail() { echo "FAIL: $*" >&2; rc=1; }
warn() { echo "warn: $*"; }
echo "== doctor"

# Files the kit owns. Placeholder and ID checks look only here, so ${{ secrets.X }} in workflows
# and {{ }} in app templates (Handlebars, Vue, Angular) are never flagged.
KIT_FILES=()
for f in CLAUDE.md handoff.md docs/*.md .claude/agents/*.md; do [[ -f "$f" ]] && KIT_FILES+=("$f"); done
grep -qE '^[[:space:]]*not_configured "' scripts/check.sh 2>/dev/null && fail "scripts/check.sh still has NOT CONFIGURED checks: $(grep -oE 'not_configured "[^"]+"' scripts/check.sh | cut -d'"' -f2 | tr '\n' ',' | sed 's/,$//')"

# 1. CLAUDE.md stays an index.
if [[ -f CLAUDE.md ]]; then
  n=$(wc -l < CLAUDE.md); (( n > 150 )) && fail "CLAUDE.md is $n lines (cap 150); move detail to docs/, history to git"
else
  fail "CLAUDE.md missing"
fi

# 2. No kit placeholders or kit notes left in kit-owned files.
left=$(grep -lE '(^|[^$])\{\{[^}]+\}\}|<!-- kit:' "${KIT_FILES[@]}" 2>/dev/null | grep -vE 'docs/reviews/README.md')
[[ -n "$left" ]] && fail "untailored kit content in: $(tr '\n' ' ' <<<"$left")"

# 3. Every O-id used in kit files or code comments exists in open.md or decisions.md.
if [[ -f docs/open.md ]]; then
  known=$(grep -ohE '\bO[0-9]+\b' docs/open.md docs/decisions.md 2>/dev/null | sort -u)
  used=$(git grep -ohE '\bO[0-9]+\b' -- ':!docs/reviews' ':!TAILOR.md' ':!HOW-TO-USE.md' ':!scripts/doctor.sh' 2>/dev/null | sort -u)
  for id in $used; do grep -qx "$id" <<<"$known" || fail "$id is referenced but is in neither docs/open.md nor docs/decisions.md"; done

  # 4. Open items age. Format: - **O12** (opened 2026-10-01, decide by 2026-11-01, owner) — ...
  today=$(date +%s); count=0
  while IFS= read -r line; do
    count=$((count+1))
    by=$(grep -oE 'decide by [0-9]{4}-[0-9]{2}-[0-9]{2}' <<<"$line" | awk '{print $3}')
    id=$(grep -oE 'O[0-9]+' <<<"$line" | head -1)
    if [[ -z "$by" ]]; then warn "$id has no decide-by date"; continue; fi
    d=$(date -d "$by" +%s 2>/dev/null || date -j -f %Y-%m-%d "$by" +%s 2>/dev/null) || continue
    (( d < today )) && warn "$id is past its decide-by date ($by)"
  done < <(grep -E '^\- \*\*O[0-9]+\*\*' docs/open.md)
  (( count > 15 )) && fail "$count open items; decide or delete some (cap 15)"
fi

# 5. handoff.md freshness, when tracked.
if [[ -f handoff.md ]] && git ls-files --error-unmatch handoff.md >/dev/null 2>&1; then
  last=$(git log -1 --format=%h -- handoff.md)
  [[ -n "$last" ]] && behind=$(git rev-list --count "$last"..HEAD) && (( behind > 5 )) && warn "handoff.md last changed $behind commits ago"
fi

# 6. Review log stats, for the monthly pass.
if compgen -G "docs/reviews/*-*.md" >/dev/null; then
  recent=$(find docs/reviews -name '*-*.md' -mtime -30 | wc -l | tr -d ' ')
  unmarked=$(cat docs/reviews/*-*.md | grep -cE '^- \[ \] \[[0-9]+\]')
  fixed=$(cat docs/reviews/*-*.md | grep -E '^- \[x\]' | grep -vc 'dismissed:')
  dismissed=$(cat docs/reviews/*-*.md | grep -c 'dismissed:')
  echo "reviews (30d): $recent  findings fixed: $fixed  dismissed: $dismissed  unmarked: $unmarked"
  (( fixed + dismissed > 0 )) && echo "agreement rate: $(( 100 * fixed / (fixed + dismissed) ))%"
  cat docs/reviews/*-*.md | grep -oE 'dismissed: .*' | sort | uniq -c | awk '$1>=2 {$1=$1; print "  promote to false-positives? ", $0}'
fi

exit $rc
