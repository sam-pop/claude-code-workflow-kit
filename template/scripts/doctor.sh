#!/usr/bin/env bash
# Kit hygiene. Called by `scripts/check.sh doctor` and `all`. Exits non-zero on any FAIL.
# DOCTOR_SKIP_PATHS: space-separated paths the O-id scan (check 3) leaves out, e.g. a vendored copy
# of the kit's own template (DOCTOR_SKIP_PATHS=template).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
rc=0
fail() {
  echo "FAIL: $*" >&2
  rc=1
}
warn() { echo "warn: $*"; }
echo "== doctor"

# Files the kit owns. Placeholder and ID checks look only here, so ${{ secrets.X }} in workflows
# and {{ }} in app templates (Handlebars, Vue, Angular) are never flagged.
KIT_FILES=()
for f in CLAUDE.md handoff.md docs/*.md .claude/agents/*.md; do [[ -f "$f" ]] && KIT_FILES+=("$f"); done
grep -qE '^[[:space:]]*not_configured "' scripts/check.sh 2>/dev/null && fail "scripts/check.sh still has NOT CONFIGURED checks: $(grep -oE 'not_configured "[^"]+"' scripts/check.sh | cut -d'"' -f2 | tr '\n' ',' | sed 's/,$//')"

# 1. CLAUDE.md stays an index.
if [[ -f CLAUDE.md ]]; then
  n=$(wc -l <CLAUDE.md)
  ((n > 150)) && fail "CLAUDE.md is $n lines (cap 150); move detail to docs/, history to git"
else
  fail "CLAUDE.md missing"
fi

# 2. No kit placeholders or kit notes left in kit-owned files.
left=$(grep -lE '(^|[^$])\{\{[^}]+\}\}|<!-- kit:' ${KIT_FILES[@]+"${KIT_FILES[@]}"} 2>/dev/null | grep -vE 'docs/reviews/README.md')
[[ -n "$left" ]] && fail "untailored kit content in: $(tr '\n' ' ' <<<"$left")"

# 3. Every O-id used in kit files or code comments exists in open.md or decisions.md.
if [[ -f docs/open.md ]]; then
  known=$(grep -ohE '\bO[0-9]+\b' docs/open.md docs/decisions.md 2>/dev/null | sort -u)
  skip=()
  for p in ${DOCTOR_SKIP_PATHS:-}; do skip+=(":!$p"); done
  used=$(git grep -IohE '\bO[0-9]+\b' -- ':!docs/reviews' ':!docs/research' ':!TAILOR.md' ':!HOW-TO-USE.md' ':!README.md' ':!CHANGELOG.md' ':!scripts/doctor.sh' ${skip[@]+"${skip[@]}"} 2>/dev/null | sort -u)
  for id in $used; do grep -qx "$id" <<<"$known" || fail "$id is referenced but is in neither docs/open.md nor docs/decisions.md"; done

  # 4. Open items age. Format: - **O12** (opened 2026-10-01, decide by 2026-11-01, owner) — ...
  today=$(date +%s)
  count=0
  while IFS= read -r line; do
    count=$((count + 1))
    by=$(grep -oE 'decide by [0-9]{4}-[0-9]{2}-[0-9]{2}' <<<"$line" | awk '{print $3}')
    id=$(grep -oE 'O[0-9]+' <<<"$line" | head -1)
    if [[ -z "$by" ]]; then
      warn "$id has no decide-by date"
      continue
    fi
    d=$(date -d "$by" +%s 2>/dev/null || date -j -f %Y-%m-%d "$by" +%s 2>/dev/null) || continue
    ((d < today)) && warn "$id is past its decide-by date ($by)"
  done < <(grep -E '^\- \*\*O[0-9]+\*\*' docs/open.md)
  ((count > 15)) && fail "$count open items; decide or delete some (cap 15)"
fi

# 5. handoff.md freshness, when tracked.
if [[ -f handoff.md ]] && git ls-files --error-unmatch handoff.md >/dev/null 2>&1; then
  last=$(git log -1 --format=%h -- handoff.md)
  [[ -n "$last" ]] && behind=$(git rev-list --count "$last"..HEAD) && ((behind > 5)) && warn "handoff.md last changed $behind commits ago"
fi

# 6. Model and effort settings that silently undo the per-role setup (docs/rollout.md).
[[ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]] && warn "CLAUDE_CODE_EFFORT_LEVEL is set: it overrides every agent's \`effort:\`, the writer ladder and risk-scaled review; unset it"
[[ -n "${CLAUDE_CODE_SUBAGENT_MODEL_FORCE:-}" ]] && warn "CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set: it forces one model on every subagent; frontmatter is ignored"
if command -v claude >/dev/null && command -v python3 >/dev/null; then
  cv=$(claude --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [[ -n "$cv" ]] && python3 -c 'import sys; sys.exit(0 if tuple(map(int, sys.argv[1].split("."))) < (2, 1, 292) else 1)' "$cv"; then
    warn "Claude Code $cv is older than 2.1.292: Agent tool per-call effort unavailable; ladder and risk tiers won't apply"
  fi
fi
[[ -f "$HOME/.claude/settings.json" ]] && grep -q '"effortLevel"' "$HOME/.claude/settings.json" && warn "effortLevel in ~/.claude/settings.json is ignored for Opus 5.5; use modelSettings or /effort"
for f in /etc/claude-code/managed-settings.json "/Library/Application Support/ClaudeCode/managed-settings.json" "$HOME/.claude/settings.json" .claude/settings*.json; do
  [[ -f "$f" ]] && grep -q '"maxEffortLevel"' "$f" && warn "maxEffortLevel in $f silently lowers xhigh"
done
for role in planner writer reviewer security-auditor; do
  f=".claude/agents/$role.md"
  [[ -f "$f" ]] || continue
  e=$(sed -n '1,/^---\r\{0,1\}$/{s/^effort:[[:space:]]*//p;}' "$f" | tr -d '\r' | head -1)
  if [[ -z "$e" ]]; then
    warn "$role has no effort: run scripts/set-models.sh <profile>"
  elif [[ "$e" == max ]]; then
    warn "$role has effort: max; no role defaults to max"
  elif [[ "$role" == reviewer && "$e" == low ]]; then
    warn "reviewer has effort: low; reviewer never below medium"
  fi
done
for f in .claude/agents/*.md; do
  m=$(sed -n '1,/^---\r\{0,1\}$/{s/^model:[[:space:]]*//p;}' "$f" | tr -d '\r' | head -1)
  e=$(sed -n '1,/^---\r\{0,1\}$/{s/^effort:[[:space:]]*//p;}' "$f" | tr -d '\r' | head -1)
  [[ "$m" == sonnet && ("$e" == medium || "$e" == low) ]] && warn "$(basename "$f" .md) is sonnet at effort: $e; never set Sonnet below high (medium drops ~15 points)"
done
if grep -lE '^model:[[:space:]]*fable' .claude/agents/*.md >/dev/null 2>&1; then
  echo "note: an agent uses model: fable. Fable bills usage credits on Pro and standard Team plans from the first request; \`claude -p\` bills without asking; background and Remote sessions drop the turn after 5 minutes waiting for consent. Set a cap in /usage-credits."
fi
[[ -f .claude/agents/codex-reviewer.md ]] && ! command -v codex >/dev/null && warn "codex-reviewer is enabled but the codex CLI is not installed"
if compgen -G ".github/workflows/*.y*ml" >/dev/null && grep -lE 'CODEX_API_KEY' .github/workflows/*.y*ml >/dev/null 2>&1; then
  warn "CODEX_API_KEY in .github/workflows: OpenAI warns against a job-level CODEX_API_KEY where repo code runs"
fi
grep -q 'check-stamp' scripts/check.sh 2>/dev/null \
  || warn "scripts/check.sh does not call check-stamp: the Stop hook cannot tell when checks passed; see CHANGELOG 1.5 Upgrade notes"
kits=$(git ls-files -co --exclude-standard '*.kit' 2>/dev/null | wc -l | tr -d ' ')
[[ "$kits" != 0 ]] && warn "$kits unmerged *.kit file(s): merge each into its original, then delete it"
[[ -f .claude/kit-upgrade.md ]] && warn "upgrade merge not finished: .claude/kit-upgrade.md is still present (open Claude Code and say: Read .claude/kit-upgrade.md)"

# 7. Review log stats, for the monthly pass. Codex and stuck reports are counted on their own lines.
shopt -s nullglob
reviews=()
codex=()
stuck=()
for f in docs/reviews/*-*.md; do
  case "$f" in *-codex.md) codex+=("$f") ;; *-stuck.md) stuck+=("$f") ;; *) reviews+=("$f") ;; esac
done
if ((${#reviews[@]})); then
  recent=$(find docs/reviews -name '*-*.md' ! -name '*-codex.md' ! -name '*-stuck.md' -mtime -30 | wc -l | tr -d ' ')
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
  while IFS= read -r f; do crecent+=("$f"); done < <(find docs/reviews -name '*-codex.md' -mtime -30)
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

exit $rc
