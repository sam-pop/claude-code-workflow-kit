#!/usr/bin/env bash
# One entry point for every verification. Agents, hooks and CI call this; nothing calls raw tools.
# Usage: scripts/check.sh <lint|test|build|dev|security|doctor|all> [--changed]
#   --changed  limit lint to files changed since the base branch (fast path for hooks)
#
# kit: fill each function with this repo's real commands. Every function must exit non-zero
# on failure. If a check does not apply, print "skipped: <reason>" and return 0.
set -euo pipefail
cd "$(dirname "$0")/.."

BASE_BRANCH="${BASE_BRANCH:-main}"
CHANGED=0
[[ "${2:-}" == "--changed" ]] && CHANGED=1

changed_files() {
  git diff --name-only --diff-filter=ACMR "$BASE_BRANCH"... 2>/dev/null
  git diff --name-only --diff-filter=ACMR 2>/dev/null
  git diff --name-only --cached --diff-filter=ACMR 2>/dev/null
}

lint() {
  echo "== lint"
  # kit: format check, linter, type-check, secret scan. Examples (delete what doesn't apply):
  #   npx prettier --check .
  #   npx eslint . --max-warnings 0
  #   npx tsc --noEmit
  #   ruff check . && ruff format --check . && mypy .
  #   swiftlint --strict
  #   gitleaks protect --staged --no-banner   (secret scan; or detect-secrets, trufflehog)
  if [[ $CHANGED -eq 1 ]]; then
    mapfile -t FILES < <(changed_files | sort -u)
    [[ ${#FILES[@]} -eq 0 ]] && { echo "skipped: no changed files"; return 0; }
    echo "{{LINT_COMMAND_FOR_FILES}} ${FILES[*]}"
  else
    echo "{{LINT_COMMAND}}"
  fi
  echo "skipped: not configured"   # kit: delete this line once commands are real
}

test_() {
  echo "== test"
  # kit: e.g. npx vitest run --reporter=dot | pytest -q | swift test | go test ./...
  echo "skipped: not configured"
}

build() {
  echo "== build"
  # kit: e.g. npm run build | docker build . | xcodebuild ... -quiet build
  echo "skipped: not configured"
}

dev() {
  echo "== dev"
  # kit: e.g. npm run dev
  echo "skipped: not configured"
}

security() {
  echo "== security"
  local rc=0
  # Secret scan. Fails on any secret in the working tree or history since the base branch.
  if command -v gitleaks >/dev/null; then
    gitleaks detect --no-banner --redact --log-opts="$BASE_BRANCH..HEAD" || rc=1
  else
    echo "skipped: gitleaks not installed (brew install gitleaks)"
  fi
  # Dependency audit. kit: keep the one that matches the stack.
  #   npm audit --audit-level=high || rc=1
  #   pip-audit || rc=1
  #   cargo audit || rc=1
  #   govulncheck ./... || rc=1
  echo "skipped: dependency audit not configured"
  # SAST. semgrep with the stack's ruleset; fails on ERROR-severity findings only.
  if command -v semgrep >/dev/null; then
    semgrep_cfg="${SEMGREP_CONFIG:-p/default}"   # kit: e.g. p/typescript, p/python, p/swift, p/owasp-top-ten
    semgrep scan --config "$semgrep_cfg" --error --severity ERROR --quiet . || rc=1
  else
    echo "skipped: semgrep not installed (pip install semgrep)"
  fi
  # Tracked files that should never be tracked.
  if git ls-files | grep -E '(^|/)\.env(\..+)?$|\.pem$|\.p12$|id_rsa' | grep -v '\.example$'; then
    echo "FAIL: sensitive file tracked (see above)"; rc=1
  fi
  return $rc
}

case "${1:-}" in
  lint)     lint ;;
  test)     test_ ;;
  build)    build ;;
  dev)      dev ;;
  security) security ;;
  doctor)   bash scripts/doctor.sh ;;
  all)      lint; test_; build; security; bash scripts/doctor.sh ;;
  *)        sed -n '2,5p' "$0"; exit 2 ;;
esac
