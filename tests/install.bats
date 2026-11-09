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
  # chmod +x at the end of install adds x bits but never widens group/other read on a 700 file
  assert_equal "$(perms "$TARGET/scripts/doctor.sh")" 711
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
  rm "$TARGET/docs/glossary.md" "$TARGET/TAILOR.md"
  mk_kit2
  echo "# brand new" >"$KIT2/template/docs/new-file.md"
  git -C "$KIT2" rm -q template/docs/rollout.md
  commit_kit2
  run "$KIT2/scripts/install.sh" --upgrade "$TARGET"
  assert_success
  assert_line --regexp '^new: +docs/new-file.md$'
  assert_line --regexp '^skipped: +docs/glossary.md +\(you deleted it\)$'
  assert_line --regexp '^never re-added: +TAILOR.md$'
  assert_line --regexp '^retired: +docs/rollout.md +\(no longer in the kit; not deleted\)$'
  [[ -f "$TARGET/docs/new-file.md" && -f "$TARGET/docs/rollout.md" ]]
  [[ ! -e "$TARGET/docs/glossary.md" && ! -e "$TARGET/TAILOR.md" ]]
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

@test "upgrade of a repo installed from kit 1.4: retired 0, codex-reviewer found under agents/" {
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
  assert_line --partial "retired 0"
  refute_line --regexp '^new: +\.claude/optional/codex-reviewer.md'
  # 1.5 adds exactly these three files.
  assert_equal "$(grep -E '^new: ' <<<"$output" | awk '{print $2}' | sort | tr '\n' ' ')" \
    ".github/dependabot.yml scripts/check-stamp.sh scripts/verify-review.sh "
  assert_line --regexp '\.claude/agents/codex-reviewer\.md'
  [[ ! -e "$TARGET/.claude/optional/codex-reviewer.md" ]]
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
