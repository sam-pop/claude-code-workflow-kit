#!/usr/bin/env bash
# One entry point for every verification. Agents, hooks and CI call this; nothing calls raw tools.
# Usage: scripts/check.sh <lint|test|build|security|doctor|all> [--changed]
#   --changed  limit lint to files changed vs the base branch, including untracked files (hook fast path)
#
# kit: replace each NOT CONFIGURED line with this repo's real commands. An unconfigured check FAILS
# (exit 2) on purpose, so nobody can report "lint passed" for a check that never ran. If a check
# truly does not apply, replace its body with: skip "<reason>"
set -uo pipefail
cd "$(dirname "$0")/.."

BASE_BRANCH="${BASE_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')}"
BASE_BRANCH="${BASE_BRANCH:-main}"
CHANGED=0; [[ "${2:-}" == "--changed" ]] && CHANGED=1

not_configured() { echo "NOT CONFIGURED: $1 (edit scripts/check.sh)" >&2; return 2; }
skip() { echo "skipped: $1"; return 0; }

changed_files() {
  { git diff --name-only --diff-filter=ACMR "$BASE_BRANCH"... 2>/dev/null
    git diff --name-only --diff-filter=ACMR
    git diff --name-only --cached --diff-filter=ACMR
    git ls-files --others --exclude-standard; } | sort -u
}

lint() {
  echo "== lint"
  if [[ $CHANGED -eq 1 ]]; then
    mapfile -t FILES < <(changed_files)
    [[ ${#FILES[@]} -eq 0 ]] && { skip "no changed files"; return; }
    # kit: run the linter on "${FILES[@]}" only, e.g.
    #   npx eslint --max-warnings 0 "${FILES[@]}"      (filter to *.ts,*.tsx first)
    #   ruff check "${FILES[@]}"
    not_configured "lint --changed"
  else
    # kit: format check + lint + type-check, e.g.
    #   npx prettier --check . && npx eslint . --max-warnings 0 && npx tsc --noEmit
    #   ruff format --check . && ruff check . && mypy .
    not_configured "lint"
  fi
}

test_() {
  echo "== test"
  # kit: e.g. npx vitest run | pytest -q | go test ./... | swift test
  # Print the pass/fail/skip counts; the reviewer compares them against the base branch.
  not_configured "test"
}

build() {
  echo "== build"
  # kit: e.g. npm run build | docker build . | go build ./...
  not_configured "build"
}

security() {
  echo "== security"
  local rc=0
  # Secret scan of the working tree. (Run `gitleaks git` once on a new repo to scan history.)
  if command -v gitleaks >/dev/null; then
    gitleaks dir . --no-banner --redact || rc=1
  else
    echo "FAIL: gitleaks not installed (brew install gitleaks)" >&2; rc=1
  fi
  # Dependency audit. kit: keep the one for this stack, delete the rest.
  #   npm audit --audit-level=high || rc=1
  #   pip-audit || rc=1
  #   govulncheck ./... || rc=1
  not_configured "dependency audit" || rc=1
  # SAST: semgrep with the stack's ruleset, failing on ERROR severity only.
  if command -v semgrep >/dev/null; then
    semgrep scan --config "${SEMGREP_CONFIG:-p/default}" --error --severity ERROR --quiet . || rc=1
  else
    echo "FAIL: semgrep not installed (pip install semgrep)" >&2; rc=1
  fi
  # Files that should never be tracked.
  if git ls-files | grep -E '(^|/)\.env(\.[^/]+)?$|\.pem$|\.p12$|(^|/)id_(rsa|ed25519)$' | grep -v '\.example$'; then
    echo "FAIL: sensitive file tracked (above)" >&2; rc=1
  fi
  return $rc
}

run_all() {
  local rc=0
  lint || rc=1; test_ || rc=1; build || rc=1; security || rc=1; bash scripts/doctor.sh || rc=1
  echo "== all: $([[ $rc -eq 0 ]] && echo PASS || echo FAIL)"
  return $rc
}

case "${1:-}" in
  lint)     lint ;;
  test)     test_ ;;
  build)    build ;;
  security) security ;;
  doctor)   bash scripts/doctor.sh ;;
  all)      run_all ;;
  *)        sed -n '2,4p' "$0"; exit 2 ;;
esac
