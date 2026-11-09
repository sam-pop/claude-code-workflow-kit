#!/usr/bin/env bash
# Review log stats for the monthly pass (metrics extra; docs/rollout.md, Extras). scripts/doctor.sh
# runs this when it is at scripts/review-stats.sh. Counts saved reports in docs/reviews/: findings
# fixed, dismissed and unmarked, incomplete reports and unverified quotes; Codex and stuck reports
# are counted on their own lines (Codex plan reviews with Codex). Prints counts only.
# Usage: scripts/review-stats.sh   Exit codes: always 0 (it only reports).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 0
shopt -s nullglob
reviews=()
codex=()
stuck=()
for f in docs/reviews/*-*.md; do
  case "$f" in *-codex.md | *-codex-plan.md) codex+=("$f") ;; *-stuck.md) stuck+=("$f") ;; *) reviews+=("$f") ;; esac
done
if ((${#reviews[@]})); then
  recent=$(find docs/reviews -name '*-*.md' ! -name '*-codex.md' ! -name '*-codex-plan.md' ! -name '*-stuck.md' -mtime -30 | wc -l | tr -d ' ')
  unmarked=$(cat "${reviews[@]}" | grep -cE '^- \[ \] \[[0-9]+\]')
  fixed=$(cat "${reviews[@]}" | grep -E '^- \[x\]' | grep -vc 'dismissed:')
  dismissed=$(cat "${reviews[@]}" | grep -c 'dismissed:')
  incomplete=$(cat "${reviews[@]}" | grep -c '^status: incomplete')
  unverified=$(cat "${reviews[@]}" | sed -n 's/^quotes: [0-9]* verified, \([0-9]*\) unverified.*/\1/p' | awk '{n += $1} END {print n + 0}')
  echo "reviews (30d): $recent  findings fixed: $fixed  dismissed: $dismissed  unmarked: $unmarked  incomplete: $incomplete  unverified quotes: $unverified"
  ((fixed + dismissed > 0)) && echo "agreement rate: $((100 * fixed / (fixed + dismissed)))%"
  cat "${reviews[@]}" | grep -oE 'dismissed: .*' | sort | uniq -c | awk '$1>=2 {$1=$1; print "  promote to false-positives? ", $0}'
fi
if ((${#codex[@]})); then
  crecent=()
  while IFS= read -r f; do crecent+=("$f"); done < <(find docs/reviews \( -name '*-codex.md' -o -name '*-codex-plan.md' \) -mtime -30)
  cn=${#crecent[@]}
  cf=0
  cx=0
  if ((cn)); then
    cf=$(cat "${crecent[@]}" | grep -E '^- \[x\]' | grep -vc 'dismissed:')
    cx=$(cat "${crecent[@]}" | grep -c 'dismissed:')
  fi
  echo "codex (30d): reports $cn fixed $cf dismissed $cx"
fi
if ((${#stuck[@]})); then
  echo "escalations (30d): $(find docs/reviews -name '*-stuck.md' -mtime -30 | wc -l | tr -d ' ')"
fi

exit 0
