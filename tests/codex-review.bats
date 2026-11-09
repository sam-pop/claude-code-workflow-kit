#!/usr/bin/env bats
# template/scripts/codex-review.sh: the guard hook, what leaves for Codex, the secret pre-scan,
# fallbacks, timeouts and failure paths. Codex, gitleaks and timeout are stubs (tests/stubs/).

# shellcheck disable=SC2153,SC2016  # KIT and TARGET come from helpers.bash; $-strings are literal commands under test
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
  mkdir -p .claude/agents
  git mv .claude/optional/codex-reviewer.md .claude/agents/codex-reviewer.md
  printf '.env\n' >.gitignore
  mkdir -p src
  printf 'one\ntwo\n' >src/app.txt
  git add -A
  git commit -qm "app"
  use_stub codex gitleaks
}

guard() { printf '%s' "$1" | scripts/codex-review.sh guard; }
guard_cmd() { python3 -c 'import json,sys; print(json.dumps({"tool_input": {"command": sys.argv[1]}}))' "$1" | scripts/codex-review.sh guard; }
codex_calls() { find "$STUB_LOG" -name 'codex.*.argv' | wc -l | tr -d ' '; }
prompt() { cat "$STUB_LOG/codex.${1:-1}.prompt"; }
listing() { cat "$STUB_LOG/codex.${1:-1}.ls"; }

@test "guard allows the high and release forms" {
  for c in "scripts/codex-review.sh high" "scripts/codex-review.sh high main" "bash scripts/codex-review.sh release v1.3" \
    "./scripts/codex-review.sh high origin/main" 'bash "$CLAUDE_PROJECT_DIR/scripts/codex-review.sh" high' \
    'bash "${CLAUDE_PROJECT_DIR}/scripts/codex-review.sh" release'; do
    run guard_cmd "$c"
    assert_success
  done
}

@test "guard denies anything else" {
  for c in "scripts/codex-review.sh high main; rm -rf ." 'scripts/codex-review.sh high $(id)' \
    "scripts/codex-review.sh high && id" $'scripts/codex-review.sh high\nid' "scripts/codex-review.sh  high" \
    "scripts/codex-review.sh high --opt" "bash -c 'scripts/codex-review.sh high'" "FOO=1 scripts/codex-review.sh high" \
    "/tmp/scripts/codex-review.sh high" "scripts/codex-review.sh guard" "cat .env"; do
    run guard_cmd "$c"
    assert_failure 2
  done
  run guard 'not json'
  assert_failure 2
  run guard '{}'
  assert_failure 2
}

@test "the agent's hook command starts with bash and blocks when CLAUDE_PROJECT_DIR is unset (R1-55, R2-55)" {
  cmd=$(sed -n 's/^ *command: "\(.*\)"$/\1/p' .claude/agents/codex-reviewer.md | sed 's/\\"/"/g')
  [[ "$cmd" == "bash "* ]]
  run env -u CLAUDE_PROJECT_DIR bash -c "$cmd" <<<'{"tool_input":{"command":"scripts/codex-review.sh high"}}'
  assert_failure 2
  run env CLAUDE_PROJECT_DIR="$TARGET" bash -c "$cmd" <<<'{"tool_input":{"command":"scripts/codex-review.sh high"}}'
  assert_success
}

@test "cross-model review off: exit 3 and codex is not called" {
  git mv .claude/agents/codex-reviewer.md .claude/optional/codex-reviewer.md
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_failure 3
  assert_equal "$(codex_calls)" 0
}

@test "codex not installed: exit 3" {
  path_without codex
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_failure 3
  assert_output --partial "Codex CLI not installed"
}

@test "high: exact codex argv, including --skip-git-repo-check for the non-git review tree (R2-85)" {
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_success
  assert_output --partial "## Codex review: high main..worktree — gpt-6.1-sol/high"
  run cat "$STUB_LOG/codex.1.argv"
  assert_line --index 0 exec
  assert_line --index 1 -C
  assert_line --index 3 -m
  assert_line --index 4 gpt-6.1-sol
  assert_line --index 5 -c
  assert_line --index 6 'model_reasoning_effort="high"'
  assert_line --index 7 -s
  assert_line --index 8 read-only
  assert_line --index 9 --ephemeral
  assert_line --index 10 --ignore-user-config
  assert_line --index 11 --skip-git-repo-check
  assert_line --index 12 -o
  assert_line --index 14 -
}

@test "egress: the review tree has no .git and no ignored .env, but has untracked files and docs/ (R1-75)" {
  echo "KEY=x" >.env
  echo "new" >src/untracked.txt
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_success
  run listing
  refute_line --regexp '^\./\.git(/|$)'
  refute_line ./.env
  assert_line ./src/untracked.txt
  assert_line ./docs/conventions.md
}

@test "export-ignore does not hide files, and an uncommitted docs edit is in the review tree (R2-88)" {
  echo "docs export-ignore" >.gitattributes
  git add .gitattributes && git commit -qm attrs
  echo "edited line" >>docs/conventions.md
  run scripts/codex-review.sh high
  assert_success
  run listing
  assert_line ./docs/conventions.md
  run prompt
  assert_output --partial "+edited line"
}

@test "hostile git config does not change the diff format (R1-88)" {
  git config diff.noprefix true
  git config color.ui always
  git config diff.mnemonicPrefix true
  git config diff.external /bin/false
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_success
  run prompt
  assert_output --partial "diff --git a/src/app.txt b/src/app.txt"
  refute_output --partial $'\033['
}

@test "a removed secret line refuses the run with exit 5 and codex is not called (R1-88)" {
  echo "token FAKE-SECRET-abc" >src/secret.txt
  git add src/secret.txt && git commit -qm "oops"
  rm src/secret.txt
  run scripts/codex-review.sh high
  assert_failure 5
  assert_output --partial "secrets found in what Codex would read"
  assert_equal "$(codex_calls)" 0
}

@test "an inline gitleaks:allow added by the change does not exempt it (R4-65)" {
  echo "token FAKE-SECRET-abc gitleaks:allow" >src/secret.txt
  git add src/secret.txt
  run scripts/codex-review.sh high
  assert_failure 5
  assert_equal "$(codex_calls)" 0
}

@test "gitleaks rules come from the merge-base, never from the reviewed tree or GITLEAKS_CONFIG (R3-65)" {
  echo "title = 'trusted'" >.gitleaks.toml
  echo "trusted-fingerprint" >.gitleaksignore
  git add -A && git commit -qm "trusted gitleaks config"
  echo "title = 'reviewed'" >.gitleaks.toml
  echo "reviewed-fingerprint" >.gitleaksignore
  echo "title = 'env'" >"$BATS_TEST_TMPDIR/env.toml"
  run env GITLEAKS_CONFIG="$BATS_TEST_TMPDIR/env.toml" GITLEAKS_CONFIG_TOML="title = 'envtoml'" scripts/codex-review.sh high
  assert_success
  run cat "$STUB_LOG/gitleaks.log"
  assert_output --partial "config: title = 'trusted'"
  assert_output --partial "ignore: trusted-fingerprint"
  assert_output --partial "env GITLEAKS_CONFIG: unset"
  refute_output --partial "reviewed"
  refute_output --partial "srcconfig: present"
}

@test "release mode takes the gitleaks config from the start ref" {
  echo "title = 'at-tag'" >.gitleaks.toml
  git add -A && git commit -qm cfg && git tag v1.0
  echo "title = 'later'" >.gitleaks.toml
  echo change >>src/app.txt
  git add -A && git commit -qm later
  run scripts/codex-review.sh release v1.0
  assert_success
  run cat "$STUB_LOG/gitleaks.log"
  assert_output --partial "config: title = 'at-tag'"
  refute_output --partial "later"
}

@test "real gitleaks: a removed token, a token marked gitleaks:allow, and an allow-all config under review all refuse" {
  with_tools
  rm -f "$BATS_TEST_TMPDIR/stubs/gitleaks"
  require_real gitleaks
  tok=$(fake_token)
  echo "token=$tok" >src/removed.txt
  git add -A && git commit -qm "token"
  rm src/removed.txt
  run scripts/codex-review.sh high
  assert_failure 5
  git checkout -q -- src/removed.txt
  git rm -q src/removed.txt && git commit -qm "drop token"

  echo "token=$(fake_token) # gitleaks:allow" >src/allowed.txt
  run scripts/codex-review.sh high
  assert_failure 5
  rm src/allowed.txt

  printf '[allowlist]\npaths = [".*"]\n' >.gitleaks.toml
  echo "token=$(fake_token)" >src/new.txt
  run scripts/codex-review.sh high
  assert_failure 5
  assert_equal "$(codex_calls)" 0
}

@test "release: astra failure falls back to sol/xhigh and says why" {
  git tag v1.0
  echo change >>src/app.txt
  git add -A && git commit -qm change
  run env STUB_CODEX_FAIL_MODEL=gpt-6-astra scripts/codex-review.sh release
  assert_success
  assert_output --partial "— gpt-6.1-sol/xhigh —"
  assert_output --partial "Fallback: astra failed (error: model gpt-6-astra is not available); retried on gpt-6.1-sol/xhigh"
  run cat "$STUB_LOG/codex.2.argv"
  assert_line 'model_reasoning_effort="xhigh"'
}

@test "release: no tag exits 2; a bad ref exits 2" {
  run scripts/codex-review.sh release
  assert_failure 2
  assert_output --partial "no tag found"
  run scripts/codex-review.sh release nosuchref
  assert_failure 2
  run scripts/codex-review.sh release 'bad;ref'
  assert_failure 2
  assert_output --partial "bad ref"
}

@test "timeouts: high reports 540s; release uses 300 then 240" {
  use_stub timeout
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_failure 1
  assert_output --partial "timed out after 540s"
  git add -A && git commit -qm c && git tag v1.0 HEAD~1
  run scripts/codex-review.sh release v1.0
  assert_failure 1
  assert_output --partial "timed out after 240s"
  run cat "$STUB_LOG/timeout.log"
  assert_output $'timeout 540\ntimeout 300\ntimeout 240'
}

@test "timeouts: gtimeout is used when timeout is missing; neither gives a note (R2-70)" {
  echo change >>src/app.txt
  path_without timeout gtimeout
  ln -s "$REPO_ROOT/tests/stubs/timeout" "$BATS_TEST_TMPDIR/path-without/gtimeout"
  run scripts/codex-review.sh high
  assert_failure 1
  run cat "$STUB_LOG/timeout.log"
  assert_output "gtimeout 540"
  rm "$BATS_TEST_TMPDIR/path-without/gtimeout"
  run scripts/codex-review.sh high
  assert_success
  assert_output --partial "neither timeout nor gtimeout found"
}

@test "a diff over 600000 bytes exits 4; an empty diff exits 0 without calling codex" {
  run scripts/codex-review.sh high
  assert_success
  assert_output --partial "nothing reviewed"
  assert_equal "$(codex_calls)" 0
  python3 -c 'import sys; sys.stdout.write(("x" * 99 + "\n") * 7000)' >src/big.txt
  git add src/big.txt
  run scripts/codex-review.sh high
  assert_failure 4
}

@test "submodule pointers are listed, labelled and not applied (R2-55, R3-50)" {
  sub="$BATS_TEST_TMPDIR/sub"
  mkdir -p "$sub" && git -C "$sub" init -q && echo a >"$sub/a" && git -C "$sub" add a && git -C "$sub" commit -qm a
  git -C "$sub" commit -q --allow-empty -m b
  git submodule add -q "$sub" vendor/sub 2>/dev/null
  git -C vendor/sub checkout -q HEAD~1
  git add -A && git commit -qm "add sub"
  git -C vendor/sub checkout -q main
  new=$(git -C vendor/sub rev-parse HEAD)
  run scripts/codex-review.sh high
  assert_success
  run prompt
  assert_output --partial "submodule pointer changed: vendor/sub"
  assert_output --partial "..$new"
  run listing
  refute_line ./vendor/sub/a
}

@test "submodule added and deleted are labelled" {
  sub="$BATS_TEST_TMPDIR/sub"
  mkdir -p "$sub" && git -C "$sub" init -q && echo a >"$sub/a" && git -C "$sub" add a && git -C "$sub" commit -qm a
  git submodule add -q "$sub" vendor/sub 2>/dev/null
  run scripts/codex-review.sh high
  assert_success
  run prompt
  assert_output --regexp 'submodule pointer changed: vendor/sub added\.\.[0-9a-f]{40}'
  git commit -qm "add sub"
  git rm -q vendor/sub
  run scripts/codex-review.sh high
  assert_success
  run prompt 2
  assert_output --regexp 'submodule pointer changed: vendor/sub [0-9a-f]{40}\.\.deleted'
}

@test "a required LFS smudge filter that fails does not stop the export; the pointer is kept (R3-55)" {
  echo "*.bin filter=lfs" >.gitattributes
  echo "pointer-content" >data.bin
  git -c filter.lfs.clean=cat add -A
  git -c filter.lfs.clean=cat commit -qm lfs
  git config filter.lfs.smudge false
  git config filter.lfs.clean cat
  git config filter.lfs.required true
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_success
  run listing
  assert_line ./data.bin
}

@test "a required clean filter that fails on a modified file: exit 1, git diff failed (R4-55)" {
  echo "*.dat filter=bad" >.gitattributes
  echo "v1" >x.dat
  git add -A && git commit -qm dat
  git config filter.bad.clean false
  git config filter.bad.required true
  echo "v2" >x.dat
  run scripts/codex-review.sh high
  assert_failure 1
  assert_output --partial "codex-review: git diff failed"
  assert_equal "$(codex_calls)" 0
}

@test "reviewer.md without ## Checklist exits 1; the prompt keeps the fenced ## Review: example" {
  echo change >>src/app.txt
  run scripts/codex-review.sh high
  assert_success
  run prompt
  assert_output --partial "## Review: <change>"
  assert_output --partial "## Checklist"
  sed -i.bak 's/^## Checklist$/## Check list/' .claude/agents/reviewer.md
  run scripts/codex-review.sh high
  assert_failure 1
  assert_output --partial "lacks section: ## Checklist"
}
