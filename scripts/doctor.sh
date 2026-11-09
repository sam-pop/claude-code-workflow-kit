#!/usr/bin/env bash
# Kit hygiene. Called by `scripts/check.sh doctor` and `all`.
# Usage: scripts/doctor.sh   Exit codes: 0 no FAIL (warnings allowed), 1 any FAIL.
# Environment: DOCTOR_SKIP_PATHS, space-separated path prefixes the O-id scan (check 3) leaves out;
# read-only checks of CLAUDE_CODE_EFFORT_LEVEL, CLAUDE_CODE_SUBAGENT_MODEL_FORCE and the provider
# variables CLAUDE_CODE_USE_BEDROCK, CLAUDE_CODE_USE_VERTEX and CLAUDE_CODE_USE_FOUNDRY (check 5).
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
for f in CLAUDE.md docs/*.md .claude/agents/*.md; do [[ -f "$f" ]] && KIT_FILES+=("$f"); done
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

# 3. Every O-id used in a kit-owned file exists in open.md or decisions.md. An ID stands alone: not
# after a letter, digit, `_` or `-` (so -O2 is a compiler flag), and not followed by one.
oids() { grep -ohE '(^|[^A-Za-z0-9_-])O[0-9]+([^A-Za-z0-9_-]|$)' "$@" 2>/dev/null | grep -oE 'O[0-9]+' | sort -u; }
if [[ -f docs/open.md ]]; then
  known=$(oids docs/open.md docs/decisions.md)
  scan=()
  for f in CLAUDE.md docs/*.md .claude/agents/*.md .claude/optional/*.md; do
    [[ -f "$f" ]] || continue
    for p in ${DOCTOR_SKIP_PATHS:-}; do [[ "$f" == "$p" || "$f" == "${p%/}/"* ]] && continue 2; done
    scan+=("$f")
  done
  used=""
  ((${#scan[@]})) && used=$(oids "${scan[@]}")
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

# 5. Model and effort settings that silently undo the per-role setup (docs/rollout.md).
[[ -n "${CLAUDE_CODE_EFFORT_LEVEL:-}" ]] && warn "CLAUDE_CODE_EFFORT_LEVEL is set: it overrides every agent's \`effort:\`, the writer ladder and risk-scaled review; unset it"
[[ -n "${CLAUDE_CODE_SUBAGENT_MODEL_FORCE:-}" ]] && warn "CLAUDE_CODE_SUBAGENT_MODEL_FORCE is set: it forces one model on every subagent; frontmatter is ignored"
for f in /etc/claude-code/managed-settings.json "/Library/Application Support/ClaudeCode/managed-settings.json" "$HOME/.claude/settings.json" .claude/settings*.json; do
  [[ -f "$f" ]] && grep -q '"maxEffortLevel"' "$f" && warn "maxEffortLevel in $f silently lowers xhigh"
done
for v in CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY; do
  [[ -n "${!v:-}" ]] && warn "$v is set: model aliases (opus, sonnet) can map to older models on that provider, and effort levels it lacks fall back silently; check the provider's alias table"
done
# Frontmatter value of $2 in agent file $1 (CRLF tolerated; portable to BSD sed).
front() { tr -d '\r' <"$1" | sed -n '1,/^---$/{s/^'"$2"':[[:space:]]*//p;}' | head -1; }
for role in planner writer reviewer security-auditor; do
  f=".claude/agents/$role.md"
  [[ -f "$f" ]] || continue
  e=$(front "$f" effort)
  if [[ -z "$e" ]]; then
    warn "$role has no effort: add an \`effort:\` line to its frontmatter (or run \`scripts/set-models.sh <profile>\` if the seats are untailored)"
  elif [[ "$e" == max ]]; then
    warn "$role has effort: max; no role defaults to max"
  elif [[ "$role" == reviewer && "$e" == low ]]; then
    warn "reviewer has effort: low; reviewer never below medium"
  fi
done
for f in .claude/agents/*.md; do
  m=$(front "$f" model)
  e=$(front "$f" effort)
  [[ "$m" == sonnet && ("$e" == medium || "$e" == low) ]] && warn "$(basename "$f" .md) is sonnet at effort: $e; never set Sonnet below high (medium dropped ~7 to ~15 points on Anthropic's benchmarks)"
done
# The model that wrote the code never reviews it.
if [[ -f .claude/agents/writer.md && -f .claude/agents/reviewer.md ]]; then
  wm=$(front .claude/agents/writer.md model)
  rm_=$(front .claude/agents/reviewer.md model)
  [[ -n "$wm" && "$wm" == "$rm_" ]] && warn "reviewer and writer both use model: $wm: the reviewer runs on the writer's model; it reviews its own family's code (give one of them another model:)"
fi
# Extras (scripts/extras.sh): warnings about a half-enabled extra, Codex, and CODEX_API_KEY.
if [[ -f scripts/extras.sh ]]; then
  bash scripts/extras.sh status 2>/dev/null | grep '^warn:'
fi
# The untailored-kit CI gate must go with TAILOR.md: otherwise adding a file named TAILOR.md skips CI.
if [[ ! -f TAILOR.md ]] && compgen -G ".github/workflows/*.y*ml" >/dev/null; then
  gate=$(grep -lE "if:.*hashFiles\\('TAILOR\\.md'\\)" .github/workflows/*.y*ml 2>/dev/null | tr '\n' ' ')
  [[ -n "$gate" ]] && warn "the untailored-kit gate (hashFiles('TAILOR.md')) is still in: $gate; delete the 'Kit not tailored yet' step and every if: line that uses it"
fi
kits=$(git ls-files -co --exclude-standard '*.kit' 2>/dev/null | wc -l | tr -d ' ')
[[ "$kits" != 0 ]] && warn "$kits unmerged *.kit file(s): merge each into its original, then delete it"
[[ -f .claude/kit-upgrade.md ]] && warn "upgrade merge not finished: .claude/kit-upgrade.md is still present (open Claude Code and say: Read .claude/kit-upgrade.md)"

# 6. Review log stats, for the monthly pass: only with the metrics extra on.
[[ -f scripts/review-stats.sh ]] && bash scripts/review-stats.sh

exit $rc
