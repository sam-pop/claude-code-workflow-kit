#!/usr/bin/env bash
# One entry point for every verification. Agents, hooks and CI call this; nothing calls raw tools.
# Usage: scripts/check.sh <lint|test|build|security|doctor|all> [--changed]
#   --changed  limit lint to files changed vs the base branch, including untracked files (hook fast path)
# Exit codes: 0 pass, 1 a check failed or a tool is missing, 2 usage.
# Environment: BASE_BRANCH (default: origin/HEAD, else main; origin/<base> when there is no local
# branch); KIT_EXPECT_BASH (CI: when set, `test` prints the bash version found on PATH first);
# KIT_STUCK_INNER (set by scripts/stuck-detect.sh for the run it wraps).
#
# The kit's own copy (tailored from template/scripts/check.sh). A missing tool is a FAIL with the
# command that installs it, never a silent skip.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
# check.sh runs the tools in .tools/ and node_modules/ on the maintainer's machine, so a branch that
# tracks files there would replace them on checkout. Both directories are git-ignored; refuse before
# any tool runs.
if [[ -n "$(git ls-files -- .tools node_modules 2>/dev/null)" ]]; then
  echo "FAIL: files under .tools/ or node_modules/ are tracked; checking out such a branch replaces the tools check.sh runs" >&2
  exit 1
fi
# Profiles extra: scripts/stuck-detect.sh counts identical failures for the writer's stop rule.
# While it is off the file is absent and check.sh keeps no state. Keep this line when tailoring.
[[ -z "${KIT_STUCK_INNER:-}" && -f scripts/stuck-detect.sh ]] && exec bash scripts/stuck-detect.sh "$@"

BASE_BRANCH="${BASE_BRANCH:-$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')}"
BASE_BRANCH="${BASE_BRANCH:-main}"
CHANGED=0
[[ "${2:-}" == "--changed" ]] && CHANGED=1

skip() {
  echo "skipped: $1"
  return 0
}

# Maintainer tools: scripts/tools.sh install puts pinned binaries in .tools/bin (first on PATH);
# npm ci installs bats and markdownlint-cli2, called by path so no package's bin shadows a system tool.
[[ -d "$PWD/.tools/bin" ]] && PATH="$PWD/.tools/bin:$PATH"
export PATH
BATS="$PWD/node_modules/.bin/bats"
MDLINT="$PWD/node_modules/.bin/markdownlint-cli2"
MDLINT_JS="$PWD/node_modules/markdownlint-cli2/markdownlint-cli2.mjs"
# markdownlint-cli2 loads JavaScript named by a .markdownlint-cli2.cjs/.mjs, a .markdownlint.cjs, or
# customRules, markdownItPlugins, outputFormatters and extends entries in any config file in the tree
# it lints, so a linted branch could run code here. Its API option noImport switches all module
# loading off and keeps the JSON/YAML rules (the root .markdownlint-cli2.jsonc); the CLI has no flag.
# A node error is a lint failure, never a pass.
mdlint() {
  node --input-type=module -e 'const {main}=await import(process.argv[1]); try { process.exitCode = await main({argv: process.argv.slice(2), logMessage: console.log, logError: console.error, noImport: true}); } catch (e) { console.error(e); process.exitCode = 2; }' "$MDLINT_JS" "$@"
}
need() { # tool hint
  [[ "$1" == */* ]] && [[ -x "$1" ]] && return 0
  [[ "$1" != */* ]] && command -v "$1" >/dev/null && return 0
  echo "FAIL: ${1##*/} not installed ($2)" >&2
  return 1
}
NPM_HINT="run: npm ci"
TOOLS_HINT="run: scripts/tools.sh install"

base_ref() { # the local base branch, else origin/<base>
  local r
  for r in "$BASE_BRANCH" "origin/$BASE_BRANCH"; do
    git rev-parse --verify --quiet "$r^{commit}" >/dev/null 2>&1 && echo "$r" && return 0
  done
  return 1
}

changed_files() {
  local base
  base=$(base_ref) || base=""
  {
    [[ -n "$base" ]] && git diff --name-only --diff-filter=ACMR "$base"... 2>/dev/null
    git diff --name-only --diff-filter=ACMR
    git diff --name-only --cached --diff-filter=ACMR
    git ls-files --others --exclude-standard
  } | sort -u
}

all_files() { git ls-files -co --exclude-standard | sort -u; }

# Reads paths on stdin; prints the existing ones that each linter takes.
shell_files() { grep -E '\.(sh|bash|bats)$|^tests/stubs/[^/]+$' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }
md_files() { grep -E '\.md$' | grep -vE '^docs/research/|^docs/reviews/[^/]*-[^/]*\.md$' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }
workflow_files() { grep -E '(^|/)\.github/workflows/[^/]+\.ya?ml$' | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done; }

lint_files() { # reads paths on stdin
  local rc=0 list sh=() md=() mdl=() wf=() f
  list=$(cat)
  while IFS= read -r f; do [[ -n "$f" ]] && sh+=("$f"); done < <(shell_files <<<"$list")
  while IFS= read -r f; do [[ -n "$f" ]] && md+=("$f"); done < <(md_files <<<"$list")
  while IFS= read -r f; do [[ -n "$f" ]] && mdl+=("$f"); done < <(md_files <<<"$list") # the same set: saved reports are left out
  while IFS= read -r f; do [[ -n "$f" ]] && wf+=("$f"); done < <(workflow_files <<<"$list")
  if ((${#sh[@]})); then
    if need shellcheck "$TOOLS_HINT"; then shellcheck "${sh[@]}" || rc=1; else rc=1; fi
    if need shfmt "$TOOLS_HINT"; then shfmt -d "${sh[@]}" || rc=1; else rc=1; fi
  fi
  if ((${#md[@]})); then
    if need "$MDLINT" "$NPM_HINT"; then mdlint "${md[@]}" >/dev/null 2>"$TMP_LINT" || {
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
  need "$BATS" "$NPM_HINT" || return 1
  "$BATS" --formatter tap -r tests | awk '
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
  skip "dependency audit: no runtime dependencies; dev tools pinned by package-lock.json and scripts/tools.sh; npm audit advisories in markdownlint-cli2's dev-only dependency tree accepted 2026-11-09, fixes arrive through Dependabot"
  skip "semgrep: shellcheck covers the shell code"
  # Files that should never be tracked.
  if git ls-files | grep -E '(^|/)\.env(\.[^/]+)?$|\.pem$|\.p12$|(^|/)id_(rsa|ed25519)$' | grep -v '\.example$'; then
    echo "FAIL: sensitive file tracked (above)" >&2
    rc=1
  fi
  return $rc
}

doctor() { bash scripts/doctor.sh; }

run_all() {
  local rc=0 t
  # Stop-warning extra: the two check-stamp lines record when checks last passed; no-op while it is
  # off. Keep them when tailoring.
  t=$(bash scripts/check-stamp.sh tree 2>/dev/null)
  lint || rc=1
  test_ || rc=1
  build || rc=1
  security || rc=1
  doctor || rc=1
  [[ $rc -eq 0 && -n "$t" ]] && bash scripts/check-stamp.sh record "$t"
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
