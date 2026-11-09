#!/usr/bin/env bats
# scripts/install.sh: fresh install, upgrade classes, kit state, refusals.

# shellcheck disable=SC2153  # KIT and TARGET are set by helpers.bash (mk_kit, mk_target)
load helpers

setup() {
  isolate
  mk_kit
}

template_paths() { (cd "$KIT/template" && git ls-files | sort); }
target_files() { (cd "$TARGET" && find . -path ./.git -prune -o -type f -print | sed 's#^\./##' | sort); }

# A copy of the kit that a test can change and commit (a "newer kit").
mk_kit2() {
  KIT2="$BATS_TEST_TMPDIR/kit2"
  cp -R "$KIT" "$KIT2"
}
commit_kit2() { git -C "$KIT2" add -A && git -C "$KIT2" commit -qm "kit change"; }

perms() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

kit_version() { sed -n 's/^## \[\([0-9.]*\)\].*/\1/p' "$KIT/CHANGELOG.md" | head -1; }

@test "fresh install: exactly the template/ files plus the two state files" {
  mk_target
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_success
  expected=$( (
    template_paths
    echo .claude/kit-manifest
    echo .claude/kit-version
    echo README.md
  ) | sort)
  assert_equal "$(target_files)" "$expected"
}

@test "fresh install: no README, CHANGELOG, research, assets, installer or tests from the kit" {
  mk_target
  rm "$TARGET/README.md"
  "$KIT/scripts/install.sh" "$TARGET" >/dev/null
  run target_files
  refute_output --regexp '(^|/)(README|CHANGELOG)\.md$|docs/research|docs/assets|install\.sh|kit-upgrade-prompt|^tests/|^template/'
}

@test "fresh install: manifest paths are target-relative, without a template/ prefix" {
  mk_target
  "$KIT/scripts/install.sh" "$TARGET" >/dev/null
  run grep -c 'template/' "$TARGET/.claude/kit-manifest"
  assert_output 0
  assert_equal "$(awk '{print $2}' "$TARGET/.claude/kit-manifest")" "$(template_paths)"
}

@test "fresh install: scripts keep their executable mode" {
  mk_target
  "$KIT/scripts/install.sh" "$TARGET" >/dev/null
  [[ -x "$TARGET/scripts/check.sh" && -x "$TARGET/scripts/doctor.sh" ]]
}

@test "fresh install: an existing differing file is kept byte-identical and the kit copy goes to .kit" {
  mk_target
  printf '# mine\r\nrules\n' >"$TARGET/CLAUDE.md"
  cp "$TARGET/CLAUDE.md" "$BATS_TEST_TMPDIR/orig"
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_success
  assert_output --partial "tailored:"
  cmp "$TARGET/CLAUDE.md" "$BATS_TEST_TMPDIR/orig"
  cmp "$TARGET/CLAUDE.md.kit" "$KIT/template/CLAUDE.md"
}

@test "a second plain install refuses and points at --upgrade" {
  installed_target
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_failure 1
  assert_output --partial "use --upgrade"
}

@test "--dry-run writes nothing" {
  mk_target
  run "$KIT/scripts/install.sh" --dry-run "$TARGET"
  assert_success
  assert_output --partial "dry run: nothing is written"
  assert_equal "$(target_files)" "README.md"
}

@test "upgrade: an unmodified file the kit changed is replaced in place and keeps its mode" {
  installed_target
  chmod 700 "$TARGET/scripts/doctor.sh"
  mk_kit2
  echo "# newer" >>"$KIT2/template/scripts/doctor.sh"
  commit_kit2
  run "$KIT2/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^replaced: +scripts/doctor.sh$'
  cmp "$TARGET/scripts/doctor.sh" "$KIT2/template/scripts/doctor.sh"
  # x bits are added only where the file can be read: a 700 file stays 700
  assert_equal "$(perms "$TARGET/scripts/doctor.sh")" 700
}

@test "upgrade: a tailored file the kit changed gets a .kit sibling and is not touched" {
  installed_target
  echo "local rule" >>"$TARGET/docs/conventions.md"
  cp "$TARGET/docs/conventions.md" "$BATS_TEST_TMPDIR/mine"
  mk_kit2
  echo "kit rule" >>"$KIT2/template/docs/conventions.md"
  commit_kit2
  run "$KIT2/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^tailored: +docs/conventions.md +\(kit copy saved as docs/conventions.md.kit\)$'
  cmp "$TARGET/docs/conventions.md" "$BATS_TEST_TMPDIR/mine"
  cmp "$TARGET/docs/conventions.md.kit" "$KIT2/template/docs/conventions.md"
}

@test "upgrade: a tailored file whose kit copy did not change gets no .kit (R1-88)" {
  installed_target
  echo "local rule" >>"$TARGET/docs/conventions.md"
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^tailored \(kit unchanged\): +docs/conventions.md'
  [[ ! -e "$TARGET/docs/conventions.md.kit" ]]
}

@test "upgrade: new, skipped, never re-added and retired are classified and nothing is deleted" {
  installed_target
  rm "$TARGET/docs/rollout.md" "$TARGET/TAILOR.md"
  mk_kit2
  echo "# brand new" >"$KIT2/template/docs/new-file.md"
  git -C "$KIT2" rm -q template/docs/decisions.md
  commit_kit2
  run "$KIT2/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^new: +docs/new-file.md$'
  assert_line --regexp '^skipped: +docs/rollout.md +\(you deleted it\)$'
  assert_line --regexp '^never re-added: +TAILOR.md$'
  assert_line --regexp '^retired: +docs/decisions.md +\(no longer in the kit; not deleted\)$'
  [[ -f "$TARGET/docs/new-file.md" && -f "$TARGET/docs/decisions.md" ]]
  [[ ! -e "$TARGET/docs/rollout.md" && ! -e "$TARGET/TAILOR.md" ]]
  assert_line --partial "retired 1"
}

@test "upgrade: an unfinished merge refuses; --dry-run still works (R2-90)" {
  installed_target
  echo x >"$TARGET/CLAUDE.md.kit"
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_failure 1
  assert_output --partial "the previous kit merge is not finished: CLAUDE.md.kit"
  run "$KIT/scripts/install.sh" --upgrade --dry-run "$TARGET"
  assert_success
  assert_output --partial "dry run"
}

@test "upgrade --force: keeps a tailored file with a .kit as tailored, keeps upgraded_from, deletes a stale .kit (R3-50)" {
  installed_target
  mk_kit2
  echo "kit rule" >>"$KIT2/template/docs/conventions.md"
  echo "kit rule" >>"$KIT2/template/docs/decisions.md"
  commit_kit2
  echo "local" >>"$TARGET/docs/conventions.md"
  echo "local" >>"$TARGET/docs/decisions.md"
  "$KIT2/scripts/install.sh" --upgrade "$TARGET" >/dev/null
  from=$(sed -n 's/.*upgraded_from=\([^ ]*\).*/\1/p' "$TARGET/.claude/kit-version")
  # the user resolves decisions.md by taking the kit copy, leaving the .kit behind
  cp "$KIT2/template/docs/decisions.md" "$TARGET/docs/decisions.md"
  run "$KIT2/scripts/install.sh" --upgrade --force "$TARGET"
  assert_success
  assert_line --regexp '^tailored: +docs/conventions.md'
  assert_line --regexp '^current: +docs/decisions.md +\(stale docs/decisions.md.kit deleted'
  [[ -e "$TARGET/docs/conventions.md.kit" && ! -e "$TARGET/docs/decisions.md.kit" ]]
  run grep -o "upgraded_from=$from" "$TARGET/.claude/kit-version"
  assert_success
}

@test "upgrade: the target's own UPGRADE.md is untouched and kit-upgrade.md embeds the prompt (R1-90)" {
  installed_target
  echo "my upgrade notes" >"$TARGET/UPGRADE.md"
  "$KIT/scripts/install.sh" --upgrade "$TARGET" >/dev/null
  assert_equal "$(cat "$TARGET/UPGRADE.md")" "my upgrade notes"
  run head -1 "$TARGET/.claude/kit-upgrade.md"
  assert_output "$(head -1 "$KIT/scripts/kit-upgrade-prompt.md")"
}

@test "upgrade from the same version says there are no changes since it (R1-minor)" {
  installed_target
  "$KIT/scripts/install.sh" --upgrade "$TARGET" >/dev/null
  run grep -F "No changes since $(kit_version)." "$TARGET/.claude/kit-upgrade.md"
  assert_success
}

@test "upgrade of a repo installed from kit 1.4: only handoff.md and docs/glossary.md retired, codex stays on, profiles and metrics on, the rest off" {
  git -C "$REPO_ROOT" cat-file -e "0823256^{commit}" 2>/dev/null || skip "kit 1.4 commit 0823256 not in this clone"
  k14="$BATS_TEST_TMPDIR/kit14"
  mkdir -p "$k14"
  git -C "$REPO_ROOT" archive 0823256 | tar -x -C "$k14"
  (cd "$k14" && git init -q && git add -A && git commit -qm k14)
  mk_target
  "$k14/scripts/install.sh" "$TARGET" >/dev/null
  assert_equal "$(awk '{print $2}' "$TARGET/.claude/kit-manifest")" "$(cat "$REPO_ROOT/tests/fixtures/kit-1.4-files.txt")"
  mkdir -p "$TARGET/.claude/agents"
  mv "$TARGET/.claude/optional/codex-reviewer.md" "$TARGET/.claude/agents/codex-reviewer.md"
  git -C "$TARGET" add -A && git -C "$TARGET" commit -qm k14
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --partial "retired 2"
  assert_line --regexp '^retired: +handoff\.md '
  assert_line --regexp '^retired: +docs/glossary\.md '
  [[ "$(grep -c '^retired:' <<<"$output")" == 2 ]]
  refute_line --regexp '^new: +\.claude/optional/codex-reviewer.md'
  # 1.5 and 1.6 add exactly these files: stop-warning and verify-review arrive off, metrics on.
  assert_equal "$(grep -E '^new: ' <<<"$output" | awk '{print $2}' | sort | tr '\n' ' ')" \
    ".claude/optional/check-stamp.sh .claude/optional/stuck-detect.sh .claude/optional/verify-review.sh .github/dependabot.yml scripts/extras.sh scripts/review-stats.sh "
  # profiles is on, so sync moves its new stuck detector next to set-models.sh
  assert_line "moved: .claude/optional/stuck-detect.sh -> scripts/stuck-detect.sh"
  assert_line --regexp '^(current|replaced): +scripts/set-models\.sh$'
  assert_line --regexp '\.claude/agents/codex-reviewer\.md'
  [[ ! -e "$TARGET/.claude/optional/codex-reviewer.md" ]]
  use_stub codex
  run bash "$TARGET/scripts/extras.sh" status
  assert_success
  assert_output "codex: on
profiles: on
stop-warning: off
verify-review: off
metrics: on"
}

# A repo installed from kit 1.5 (tag v1.5 = 85094b7), committed, without tailoring.
installed_from_15() {
  local ref
  for ref in v1.5 85094b7; do
    git -C "$REPO_ROOT" cat-file -e "$ref^{commit}" 2>/dev/null && break
    ref=""
  done
  [[ -n "$ref" ]] || skip "kit 1.5 (tag v1.5 or commit 85094b7) not in this clone"
  k15="$BATS_TEST_TMPDIR/kit15"
  mkdir -p "$k15"
  git -C "$REPO_ROOT" archive "$ref" | tar -x -C "$k15"
  (cd "$k15" && git init -q && git add -A && git commit -qm k15)
  mk_target
  "$k15/scripts/install.sh" "$TARGET" >/dev/null
  git -C "$TARGET" add -A && git -C "$TARGET" commit -qm k15
}

@test "upgrade from kit 1.5: every extra it ran stays on, the Stop hook stays, status is clean, only handoff.md and docs/glossary.md retired" {
  use_stub codex
  installed_from_15
  cp "$TARGET/.claude/settings.json" "$BATS_TEST_TMPDIR/settings15"
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --partial "retired 2"
  assert_line --regexp '^retired: +handoff\.md '
  assert_line --regexp '^retired: +docs/glossary\.md '
  [[ "$(grep -c '^retired:' <<<"$output")" == 2 ]]
  assert_line --regexp '^replaced: +\.claude/settings\.json$'
  assert_line --partial "hook added: Stop"
  assert_line --regexp '^new: +scripts/review-stats\.sh$'
  assert_line "moved: .claude/optional/stuck-detect.sh -> scripts/stuck-detect.sh"
  [[ -x "$TARGET/scripts/stuck-detect.sh" ]]
  for f in check-stamp.sh verify-review.sh set-models.sh; do
    assert_line --regexp "^(current|replaced): +scripts/$f\$"
    [[ -x "$TARGET/scripts/$f" && ! -e "$TARGET/.claude/optional/$f" ]] || fail "$f not on"
  done
  # the untailored settings.json the upgrade replaced gets its Stop hook back, byte for byte
  cmp "$TARGET/.claude/settings.json" "$BATS_TEST_TMPDIR/settings15"
  run bash "$TARGET/scripts/extras.sh" status
  assert_success
  assert_output "codex: off
profiles: on
stop-warning: on
verify-review: on
metrics: on"
  # the manifest keys extras by their .claude/optional/ path
  run grep -cE '  (scripts|\.claude/agents)/(check-stamp|verify-review|set-models|review-stats)\.sh$' "$TARGET/.claude/kit-manifest"
  assert_output 0
  # nothing changed in the kit since: a second upgrade is all current and syncs nothing
  git -C "$TARGET" add -A && git -C "$TARGET" commit -qm up
  rm "$TARGET/.claude/kit-upgrade.md"
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  refute_line --partial "hook added"
  refute_line --regexp '^(new|replaced|tailored):'
}

@test "upgrade: an extra that is on is updated in place, with no .kit when unmodified" {
  installed_target
  (cd "$TARGET" && extras_on verify-review) >/dev/null
  mk_kit2
  echo "# newer" >>"$KIT2/template/.claude/optional/verify-review.sh"
  commit_kit2
  run "$KIT2/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^replaced: +scripts/verify-review\.sh$'
  cmp "$TARGET/scripts/verify-review.sh" "$KIT2/template/.claude/optional/verify-review.sh"
  [[ ! -e "$TARGET/.claude/optional/verify-review.sh" && ! -e "$TARGET/scripts/verify-review.sh.kit" ]]
  grep -q '  \.claude/optional/verify-review\.sh$' "$TARGET/.claude/kit-manifest"
}

@test "upgrade: a tailored extra that is on gets its .kit beside the active file" {
  installed_target
  (cd "$TARGET" && extras_on verify-review) >/dev/null
  echo "# mine" >>"$TARGET/scripts/verify-review.sh"
  mk_kit2
  echo "# newer" >>"$KIT2/template/.claude/optional/verify-review.sh"
  commit_kit2
  run "$KIT2/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^tailored: +scripts/verify-review\.sh '
  [[ -f "$TARGET/scripts/verify-review.sh.kit" && ! -e "$TARGET/.claude/optional/verify-review.sh" ]]
}

@test "upgrade: an extra the repo switched off stays off" {
  installed_target
  (cd "$TARGET" && extras_on stop-warning metrics) >/dev/null
  (cd "$TARGET" && bash scripts/extras.sh off stop-warning && bash scripts/extras.sh off metrics && git add -A && git commit -qm off) >/dev/null
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  [[ -f "$TARGET/.claude/optional/check-stamp.sh" && ! -e "$TARGET/scripts/check-stamp.sh" ]]
  [[ -f "$TARGET/.claude/optional/review-stats.sh" && ! -e "$TARGET/scripts/review-stats.sh" ]]
  run grep -c '"Stop"' "$TARGET/.claude/settings.json"
  assert_output 0
}

@test "upgrade: an extra's file the repo deleted is skipped, not re-added off (active or dormant)" {
  installed_target
  (cd "$TARGET" && extras_on verify-review) >/dev/null
  rm "$TARGET/scripts/verify-review.sh" "$TARGET/.claude/optional/review-stats.sh"
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^skipped: +\.claude/optional/verify-review\.sh +\(you deleted it\)$'
  assert_line --regexp '^skipped: +\.claude/optional/review-stats\.sh +\(you deleted it\)$'
  [[ ! -e "$TARGET/.claude/optional/verify-review.sh" && ! -e "$TARGET/scripts/verify-review.sh" ]]
  [[ ! -e "$TARGET/scripts/review-stats.sh" ]]
}

@test "upgrade: a 1.5 manifest whose active extra file was deleted is skipped, not retired" {
  installed_from_15
  rm "$TARGET/scripts/verify-review.sh"
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^skipped: +\.claude/optional/verify-review\.sh'
  refute_line --regexp '^retired: +scripts/verify-review\.sh'
  [[ ! -e "$TARGET/.claude/optional/verify-review.sh" ]]
}

@test "upgrade: metrics arrives on for a manifest without review-stats.sh, stays off for one that has it off" {
  installed_target
  grep -v 'review-stats' "$TARGET/.claude/kit-manifest" >"$BATS_TEST_TMPDIR/m"
  cp "$BATS_TEST_TMPDIR/m" "$TARGET/.claude/kit-manifest"
  rm "$TARGET/.claude/optional/review-stats.sh"
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^new: +scripts/review-stats\.sh$'
  [[ -x "$TARGET/scripts/review-stats.sh" ]]
  installed_target other
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  [[ -f "$TARGET/.claude/optional/review-stats.sh" && ! -e "$TARGET/scripts/review-stats.sh" ]]
}

@test "fresh install leaves a repo's own scripts/set-models.sh alone and installs the extra off" {
  mk_target
  mkdir -p "$TARGET/scripts"
  echo "echo mine" >"$TARGET/scripts/set-models.sh"
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_success
  assert_equal "$(cat "$TARGET/scripts/set-models.sh")" "echo mine"
  [[ -f "$TARGET/.claude/optional/set-models.sh" && ! -e "$TARGET/scripts/set-models.sh.kit" ]]
}

@test "upgrade: a sync that cannot edit settings.json warns and still exits 0" {
  installed_target
  (cd "$TARGET" && extras_on stop-warning) >/dev/null
  printf 'not json\n' >"$TARGET/.claude/settings.json"
  git -C "$TARGET" commit -qam broken
  run "$KIT/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_output --partial "warn: scripts/extras.sh sync did not finish"
  assert_equal "$(cat "$TARGET/.claude/settings.json")" "not json"
}

@test "kit state: an untracked file in template/ is not installed and the installer warns (R2-60)" {
  mk_kit2
  echo "draft" >"$KIT2/template/docs/draft.md"
  mk_target
  run "$KIT2/scripts/install.sh" "$TARGET"
  assert_success
  assert_output --partial "warn: the kit checkout has 1 uncommitted path(s)"
  [[ ! -e "$TARGET/docs/draft.md" ]]
}

@test "kit state: an untracked review log in the kit's docs/reviews/ does not warn (R3-60)" {
  mk_kit2
  mkdir -p "$KIT2/docs/reviews"
  echo "review" >"$KIT2/docs/reviews/2026-01-01-000000-abc-review.md"
  mk_target
  run "$KIT2/scripts/install.sh" "$TARGET"
  assert_success
  refute_output --partial "warn:"
}

@test "kit without .git installs by walking template/" {
  plain="$BATS_TEST_TMPDIR/plain"
  cp -R "$KIT" "$plain"
  rm -rf "$plain/.git"
  mk_target
  run "$plain/scripts/install.sh" "$TARGET"
  assert_success
  assert_equal "$(awk '{print $2}' "$TARGET/.claude/kit-manifest")" "$(template_paths)"
  run grep -c 'commit=unknown' "$TARGET/.claude/kit-version"
  assert_output 1
}

@test "read-only kit installs and nothing in the kit changes" {
  ro="$BATS_TEST_TMPDIR/ro"
  cp -R "$KIT" "$ro"
  rm -rf "$ro/.git"
  chmod -R a-w "$ro"
  if [[ $EUID -eq 0 ]] && touch "$ro/probe" 2>/dev/null; then
    rm -f "$ro/probe"
    chmod -R u+w "$ro"
    skip "running as root: file permissions do not stop writes (run as a normal user to test)"
  fi
  before=$(cd "$ro" && find . -print | sort)
  mk_target
  run "$ro/scripts/install.sh" "$TARGET"
  chmod -R u+w "$ro"
  assert_success
  assert_equal "$(cd "$ro" && find . -print | sort)" "$before"
}

@test "a target equal to or inside the kit's template/ is refused" {
  run "$KIT/scripts/install.sh" "$KIT/template"
  assert_failure 1
  assert_output --partial "refusing to install into the kit's own template/"
  run "$KIT/scripts/install.sh" "$KIT/template/docs"
  assert_failure 1
  [[ -z "$(git -C "$KIT" status --porcelain)" ]]
}

@test "a kit without template/ fails with a clear message" {
  mk_kit2
  rm -rf "$KIT2/template"
  mk_target
  run "$KIT2/scripts/install.sh" "$TARGET"
  assert_failure 1
  assert_output --partial "the kit has no template/ directory"
}

@test "install leaves the mode of the target's own scripts alone (A9)" {
  mk_kit
  mk_target
  mkdir -p "$TARGET/scripts"
  printf 'echo deploy\n' >"$TARGET/scripts/deploy-prod.sh"
  chmod 644 "$TARGET/scripts/deploy-prod.sh"
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_success
  [[ ! -x "$TARGET/scripts/deploy-prod.sh" ]]
  [[ -x "$TARGET/scripts/check.sh" ]]
}

@test "a symlinked directory leading out of the target refuses the run and writes nothing outside (A9)" {
  mk_kit
  mk_target
  out="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$out"
  ln -s "$out" "$TARGET/docs"
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_failure 1
  assert_output --partial "resolve outside the target"
  assert_output --partial "docs/conventions.md"
  assert_equal "$(find "$out" -type f | wc -l | tr -d ' ')" 0
  [[ ! -e "$TARGET/.claude/kit-manifest" ]]
}

@test "more than one target directory is a usage error (B13)" {
  mk_kit
  mk_target a
  mk_target b
  run "$KIT/scripts/install.sh" "$BATS_TEST_TMPDIR/a" "$BATS_TEST_TMPDIR/b"
  assert_failure 2
  [[ ! -e "$BATS_TEST_TMPDIR/b/CLAUDE.md" ]]
}

@test "a .kit symlink to a file outside the target refuses the run and leaves the file alone (A9, .kit)" {
  mk_target
  out="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$out"
  echo "keep me" >"$out/victim.txt"
  echo "mine" >"$TARGET/CLAUDE.md"
  ln -s "$out/victim.txt" "$TARGET/CLAUDE.md.kit"
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_failure 1
  assert_output --partial "resolve outside the target"
  assert_output --partial "CLAUDE.md.kit"
  assert_equal "$(cat "$out/victim.txt")" "keep me"
  [[ ! -e "$TARGET/.claude/kit-manifest" ]]
}

@test "a dangling .kit symlink leading outside the target creates nothing there (A9, dangling .kit)" {
  mk_target
  out="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$out"
  echo "mine" >"$TARGET/CLAUDE.md"
  ln -s "$out/created.md" "$TARGET/CLAUDE.md.kit"
  run "$KIT/scripts/install.sh" "$TARGET"
  assert_failure 1
  assert_output --partial "CLAUDE.md.kit"
  [[ ! -e "$out/created.md" ]]
}

@test "upgrade: a state file symlinked outside the target refuses the run (A9, state files)" {
  mk_target
  "$KIT/scripts/install.sh" "$TARGET" >/dev/null
  out="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$out"
  for f in kit-version kit-upgrade.md; do
    rm -f "$TARGET/.claude/$f"
    ln -s "$out/$f" "$TARGET/.claude/$f"
    run "$KIT/scripts/install.sh" --upgrade "$TARGET"
    assert_failure 1
    assert_output --partial ".claude/$f"
    [[ ! -e "$out/$f" ]]
    rm "$TARGET/.claude/$f"
  done
}

@test "a kit copy whose scripts lost their modes still installs executable scripts" {
  plain="$BATS_TEST_TMPDIR/plain"
  cp -R "$KIT" "$plain"
  rm -rf "$plain/.git"
  chmod 644 "$plain"/template/scripts/*.sh
  mk_target
  run "$plain/scripts/install.sh" "$TARGET"
  assert_success
  for f in "$TARGET"/scripts/*.sh; do [[ -x "$f" ]] || fail "not executable: $f"; done
}
