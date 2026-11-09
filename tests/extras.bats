#!/usr/bin/env bats
# template/scripts/extras.sh: switching extras on and off, the hook edit in settings.json, status
# warnings for half-enabled extras, sync, and refusals.

# shellcheck disable=SC2153,SC2016  # KIT and TARGET are set by helpers.bash; sed scripts hold literal $
load helpers

setup() {
  isolate
  installed_target
  cd "$TARGET" || exit 1
}

stop_hooks() { # number of hooks under Stop that run check-stamp.sh, then the Stop key's presence
  python3 - <<'PY'
import json
d = json.load(open(".claude/settings.json"))
stop = d.get("hooks", {}).get("Stop")
n = sum("scripts/check-stamp.sh" in h.get("command", "") for g in (stop or []) for h in g.get("hooks", []))
print(n, "stop-key" if stop is not None else "no-stop-key")
PY
}

@test "fresh install: every extra off, status exit 0, no Stop hook" {
  run bash scripts/extras.sh status
  assert_success
  assert_output "codex: off
profiles: off
stop-warning: off
verify-review: off
metrics: off"
  assert_equal "$(stop_hooks)" "0 no-stop-key"
}

@test "stop-warning on then off leaves an untailored settings.json byte-identical" {
  cp .claude/settings.json "$BATS_TEST_TMPDIR/before"
  run bash scripts/extras.sh on stop-warning
  assert_success
  assert_output --partial "moved: .claude/optional/check-stamp.sh -> scripts/check-stamp.sh"
  assert_output --partial "hook added: Stop"
  assert_output --partial "Record it in docs/decisions.md"
  [[ -x scripts/check-stamp.sh && ! -e .claude/optional/check-stamp.sh ]]
  assert_equal "$(stop_hooks)" "1 stop-key"
  run bash scripts/extras.sh off stop-warning
  assert_success
  assert_output --partial "hook removed: Stop"
  [[ -f .claude/optional/check-stamp.sh && ! -e scripts/check-stamp.sh ]]
  cmp .claude/settings.json "$BATS_TEST_TMPDIR/before"
}

@test "on twice adds one hook; off twice is a no-op the second time" {
  bash scripts/extras.sh on stop-warning >/dev/null
  run bash scripts/extras.sh on stop-warning
  assert_success
  assert_output --partial "stop-warning was already on"
  assert_equal "$(stop_hooks)" "1 stop-key"
  bash scripts/extras.sh off stop-warning >/dev/null
  run bash scripts/extras.sh off stop-warning
  assert_success
  assert_output --partial "stop-warning was already off"
}

@test "a tailored settings.json keeps its own hooks, its ask rule and a shared Stop group's other hook" {
  python3 - <<'PY'
import json
p = ".claude/settings.json"
d = json.load(open(p))
d["permissions"]["ask"] = ["Bash(git push:*)"]
d["hooks"]["Stop"] = [{"hooks": [{"type": "command", "command": "./notify.sh"}]}]
d["hooks"]["Notification"] = [{"hooks": [{"type": "command", "command": "./ping.sh"}]}]
open(p, "w").write(json.dumps(d, indent=4))
PY
  bash scripts/extras.sh on stop-warning >/dev/null
  assert_equal "$(stop_hooks)" "1 stop-key"
  # the user moves the kit's hook into their own Stop group
  python3 - <<'PY'
import json
p = ".claude/settings.json"
d = json.load(open(p))
mine = d["hooks"]["Stop"].pop()["hooks"][0]
d["hooks"]["Stop"][0]["hooks"].append(mine)
open(p, "w").write(json.dumps(d, indent=2))
PY
  run bash scripts/extras.sh off stop-warning
  assert_success
  run python3 -c 'import json; d = json.load(open(".claude/settings.json")); print(d["permissions"]["ask"], d["hooks"]["Stop"], len(d["hooks"]["Notification"]))'
  assert_output "['Bash(git push:*)'] [{'hooks': [{'type': 'command', 'command': './notify.sh'}]}] 1"
}

@test "off drops a Stop group and the Stop key left empty" {
  bash scripts/extras.sh on stop-warning >/dev/null
  bash scripts/extras.sh off stop-warning >/dev/null
  assert_equal "$(stop_hooks)" "0 no-stop-key"
  run grep -c '"Stop"' .claude/settings.json
  assert_output 0
}

@test "invalid settings.json: on stop-warning exits 1, the file and the script stay as they were" {
  printf '{ "hooks": \n' >.claude/settings.json
  cp .claude/settings.json "$BATS_TEST_TMPDIR/before"
  run bash scripts/extras.sh on stop-warning
  assert_failure 1
  assert_output --partial "not valid JSON"
  cmp .claude/settings.json "$BATS_TEST_TMPDIR/before"
  [[ -f .claude/optional/check-stamp.sh && ! -e scripts/check-stamp.sh ]]
}

@test "missing settings.json: on stop-warning exits 1 and moves nothing" {
  rm .claude/settings.json
  run bash scripts/extras.sh on stop-warning
  assert_failure 1
  assert_output --partial "settings.json is missing"
  [[ -f .claude/optional/check-stamp.sh && ! -e scripts/check-stamp.sh ]]
}

@test "both copies exist: on and off exit 1 and move nothing" {
  cp .claude/optional/verify-review.sh scripts/verify-review.sh
  run bash scripts/extras.sh on verify-review
  assert_failure 1
  assert_output --partial "both .claude/optional/verify-review.sh and scripts/verify-review.sh exist"
  run bash scripts/extras.sh off verify-review
  assert_failure 1
  [[ -f .claude/optional/verify-review.sh && -f scripts/verify-review.sh ]]
  run bash scripts/extras.sh status
  assert_failure 1
  assert_output --partial "warn: verify-review: both"
}

@test "unknown extra and bad arguments exit 2" {
  for args in "on nope" "" "on" "status extra" "flip codex"; do
    # shellcheck disable=SC2086  # split the argument list on purpose
    run bash scripts/extras.sh $args
    assert_failure 2
  done
}

@test "an extra that is not installed: on exits 1, off and status say not installed" {
  rm .claude/optional/review-stats.sh
  run bash scripts/extras.sh on metrics
  assert_failure 1
  assert_output --partial "metrics is not installed"
  run bash scripts/extras.sh off metrics
  assert_success
  assert_output --partial "metrics: not installed"
  run bash scripts/extras.sh status
  assert_line "metrics: not installed"
}

@test "a symlinked scripts/ leading out of the repo refuses and writes nothing outside" {
  out="$BATS_TEST_TMPDIR/outside"
  mv scripts "$out"
  ln -s "$out" scripts
  before=$(cd "$out" && ls)
  run env CLAUDE_PROJECT_DIR="$TARGET" bash "$out/extras.sh" on profiles
  assert_failure 1
  assert_output --partial "scripts/set-models.sh resolves outside the repo"
  assert_equal "$(cd "$out" && ls)" "$before"
  [[ -f .claude/optional/set-models.sh ]]
}

@test "codex on and off moves the agent and keeps edits; on without the codex CLI warns" {
  echo "my edit" >>.claude/optional/codex-reviewer.md
  path_without codex
  run bash scripts/extras.sh on codex
  assert_success
  assert_output --partial "warn: Codex CLI not installed"
  assert_output --partial "leave for OpenAI"
  [[ -f .claude/agents/codex-reviewer.md && ! -e .claude/optional/codex-reviewer.md ]]
  run bash scripts/extras.sh status
  assert_failure 1
  assert_output --partial "warn: codex is on but the codex CLI is not installed"
  bash scripts/extras.sh off codex >/dev/null
  [[ -f .claude/optional/codex-reviewer.md && ! -e .claude/agents/codex-reviewer.md ]]
  run tail -1 .claude/optional/codex-reviewer.md
  assert_output "my edit"
}

@test "status warns (exit 1) on a missing hook, a missing check.sh line and a hook left behind" {
  extras_on stop-warning
  run bash scripts/extras.sh status
  assert_success
  # hook missing
  bash scripts/extras.sh off stop-warning >/dev/null
  mv .claude/optional/check-stamp.sh scripts/check-stamp.sh
  run bash scripts/extras.sh status
  assert_failure 1
  assert_output --partial "warn: stop-warning is on but .claude/settings.json has no Stop hook"
  # check.sh line missing (a comment naming it does not count)
  git checkout -q -- .claude/settings.json
  sed -i.bak 's/^\( *\)\[\[ \$rc -eq 0.*check-stamp.sh record.*$/\1# scripts\/check-stamp.sh record dropped/' scripts/check.sh && rm -f scripts/check.sh.bak
  run bash scripts/extras.sh status
  assert_failure 1
  assert_output --partial "warn: stop-warning is on but scripts/check.sh does not run scripts/check-stamp.sh record"
  git checkout -q -- scripts/check.sh
  # hook left behind: the script is off, the hook is not
  mv scripts/check-stamp.sh .claude/optional/check-stamp.sh
  run bash scripts/extras.sh status
  assert_failure 1
  assert_output --partial "has a Stop hook for scripts/check-stamp.sh but stop-warning is off"
}

@test "sync adds the hook of an extra whose file is on, and removes a hook whose script was deleted" {
  mv .claude/optional/check-stamp.sh scripts/check-stamp.sh
  run bash scripts/extras.sh sync
  assert_success
  assert_output --partial "hook added: Stop"
  assert_equal "$(stop_hooks)" "1 stop-key"
  run bash scripts/extras.sh status
  assert_success
  rm scripts/check-stamp.sh
  run bash scripts/extras.sh sync
  assert_success
  assert_output --partial "hook removed: Stop"
  assert_equal "$(stop_hooks)" "0 no-stop-key"
  run bash scripts/extras.sh status
  assert_success
  assert_line "stop-warning: not installed"
}

@test "sync with an invalid settings.json warns and exits 1, leaving it unchanged" {
  mv .claude/optional/check-stamp.sh scripts/check-stamp.sh
  printf 'not json\n' >.claude/settings.json
  run bash scripts/extras.sh sync
  assert_failure 1
  assert_output --partial "stop-warning: .claude/settings.json is not valid JSON"
  assert_equal "$(cat .claude/settings.json)" "not json"
}

@test "settings.json keeps its file mode across a hook edit" {
  chmod 600 .claude/settings.json
  bash scripts/extras.sh on stop-warning >/dev/null
  perm=$(stat -c %a .claude/settings.json 2>/dev/null || stat -f %Lp .claude/settings.json)
  assert_equal "$perm" 600
}
