#!/usr/bin/env bash
# One entry point for every verification. Agents, hooks and CI call this; nothing calls raw tools.
# Usage: scripts/check.sh <lint|test|build|security|doctor|all> [--changed]
#   --changed  limit lint to files changed vs the base branch, including untracked files (hook fast path)
#
# The kit's own copy (tailored from template/scripts/check.sh). A missing tool is a FAIL with the
# command that installs it, never a silent skip.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

BASE_BRANCH="${BASE_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')}"
BASE_BRANCH="${BASE_BRANCH:-main}"
CHANGED=0
[[ "${2:-}" == "--changed" ]] && CHANGED=1

skip() {
  echo "skipped: $1"
  return 0
}

# Maintainer tools: npm ci (bats, markdownlint-cli2) and scripts/tools.sh install (the rest).
for d in "$PWD/node_modules/.bin" "$PWD/.tools/bin"; do
  [[ -d "$d" ]] && PATH="$d:$PATH"
done
export PATH
need() { # tool hint
  command -v "$1" >/dev/null && return 0
  echo "FAIL: $1 not installed ($2)" >&2
  return 1
}
NPM_HINT="run: npm ci"
TOOLS_HINT="run: scripts/tools.sh install"

changed_files() {
  {
    git diff --name-only --diff-filter=ACMR "$BASE_BRANCH"... 2>/dev/null
    git diff --name-only --diff-filter=ACMR
    git diff --name-only --cached --diff-filter=ACMR
    git ls-files --others --exclude-standard
  } | sort -u
}

all_files() { git ls-files -co --exclude-standard | sort -u; }

# Reads paths on stdin; prints the existing ones that each linter takes.
shell_files() { grep -E '\.(sh|bash|bats)$|^tests/stubs/[^/]+$' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }
md_files() { grep -E '\.md$' | grep -vE '^docs/research/|^docs/reviews/[^/]*-[^/]*\.md$' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }
md_link_files() { md_files | grep -vE '(^|/)docs/reviews/'; }
workflow_files() { grep -E '(^|/)\.github/workflows/[^/]+\.ya?ml$' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }

lint_files() { # reads paths on stdin
  local rc=0 list sh=() md=() mdl=() wf=() f
  list=$(cat)
  while IFS= read -r f; do [[ -n "$f" ]] && sh+=("$f"); done < <(shell_files <<<"$list")
  while IFS= read -r f; do [[ -n "$f" ]] && md+=("$f"); done < <(md_files <<<"$list")
  while IFS= read -r f; do [[ -n "$f" ]] && mdl+=("$f"); done < <(md_link_files <<<"$list")
  while IFS= read -r f; do [[ -n "$f" ]] && wf+=("$f"); done < <(workflow_files <<<"$list")
  if ((${#sh[@]})); then
    if need shellcheck "$TOOLS_HINT"; then shellcheck "${sh[@]}" || rc=1; else rc=1; fi
    if need shfmt "$TOOLS_HINT"; then shfmt -d "${sh[@]}" || rc=1; else rc=1; fi
  fi
  if ((${#md[@]})); then
    if need markdownlint-cli2 "$NPM_HINT"; then markdownlint-cli2 "${md[@]}" >/dev/null 2>"$TMP_LINT" || {
      cat "$TMP_LINT" >&2
      rc=1
    }; else rc=1; fi
  fi
  if ((${#mdl[@]})); then
    if need lychee "$TOOLS_HINT"; then lychee --offline --include-fragments --no-progress "${mdl[@]}" >"$TMP_LINT" 2>&1 || {
      cat "$TMP_LINT" >&2
      rc=1
    }; else rc=1; fi
  fi
  if ((${#wf[@]})); then
    if need actionlint "$TOOLS_HINT"; then actionlint "${wf[@]}" || rc=1; else rc=1; fi
  fi
  echo "shell ${#sh[@]}  markdown ${#md[@]}  links ${#mdl[@]}  workflows ${#wf[@]}"
  return $rc
}

lint() {
  echo "== lint"
  local rc=0
  TMP_LINT=$(mktemp)
  if [[ $CHANGED -eq 1 ]]; then
    local list
    list=$(changed_files)
    if [[ -z "$list" ]]; then
      rm -f "$TMP_LINT"
      skip "no changed files"
      return
    fi
    lint_files <<<"$list" || rc=1
  else
    all_files | lint_files || rc=1
  fi
  rm -f "$TMP_LINT"
  return $rc
}

test_() {
  echo "== test"
  if [[ -n "${KIT_EXPECT_BASH:-}" ]]; then
    echo "bash on PATH: $(bash -c 'echo $BASH_VERSION')"
  fi
  need bats "$NPM_HINT" || return 1
  bats --formatter tap -r tests | awk '
    { print }
    /^ok / { if (/ # skip/) s++; else p++ }
    /^not ok / { f++ }
    END { printf "tests: %d passed, %d failed, %d skipped\n", p, f, s }'

}

build() {
  echo "== build"
  skip "the kit ships source; nothing to build"
}

security() {
  echo "== security"
  local rc=0
  # Secret scan of the working tree with .gitleaks.toml and .gitleaksignore from the repo root.
  if need gitleaks "$TOOLS_HINT"; then
    gitleaks dir . --no-banner --redact || rc=1
  else
    rc=1
  fi
  skip "dependency audit: no runtime dependencies; dev tools pinned by package-lock.json and scripts/tools.sh; Dependabot alerts"
  skip "semgrep: shellcheck covers the shell code"
  # Files that should never be tracked.
  if git ls-files | grep -E '(^|/)\.env(\.[^/]+)?$|\.pem$|\.p12$|(^|/)id_(rsa|ed25519)$' | grep -v '\.example$'; then
    echo "FAIL: sensitive file tracked (above)" >&2
    rc=1
  fi
  return $rc
}

doctor() { DOCTOR_SKIP_PATHS=template bash scripts/doctor.sh; }

run_all() {
  local rc=0
  lint || rc=1
  test_ || rc=1
  build || rc=1
  security || rc=1
  doctor || rc=1
  echo "== all: $([[ $rc -eq 0 ]] && echo PASS || echo FAIL)"
  return $rc
}

case "${1:-}" in
  lint) lint ;;
  test) test_ ;;
  build) build ;;
  security) security ;;
  doctor) doctor ;;
  all) run_all ;;
  *)
    sed -n '2,4p' "$0"
    exit 2
    ;;
esac
