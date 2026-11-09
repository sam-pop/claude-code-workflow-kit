# Shared setup for the kit's bats tests. Load with: load helpers
# Every test gets its own HOME and git config, no network, and stubs on PATH for codex, gitleaks,
# timeout and claude only where a test asks for them (use_stub).

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Byte-order collation for sort, ls and globs, as the installer's manifest uses: macOS defaults to a
# case-insensitive locale, which reorders expected lists (CI macOS leg, first run).
export LC_ALL=C
load "$REPO_ROOT/node_modules/bats-support/load"
load "$REPO_ROOT/node_modules/bats-assert/load"

isolate() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1 \
    GIT_CONFIG_KEY_2 GIT_CONFIG_VALUE_2 GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
  git config --global init.defaultBranch main
  git config --global user.name Test
  git config --global user.email test@example.invalid
  git config --global protocol.file.allow always
  git config --global commit.gpgsign false
  unset CLAUDE_CODE_EFFORT_LEVEL CLAUDE_CODE_SUBAGENT_MODEL_FORCE GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML \
    CLAUDE_PROJECT_DIR BASE_BRANCH DOCTOR_SKIP_PATHS
  STUB_LOG="$BATS_TEST_TMPDIR/stub-log"
  mkdir -p "$STUB_LOG"
  export STUB_LOG
}

# A committed snapshot of the kit as it is in the working tree (uncommitted edits included), so the
# installer's `git ls-files` sees what is being tested. Built once per file into $BATS_FILE_TMPDIR/kit.
mk_kit() {
  KIT="$BATS_FILE_TMPDIR/kit"
  [[ -d "$KIT/.git" ]] && return 0
  (
    isolate
    mkdir -p "$KIT/scripts"
    cd "$REPO_ROOT" || exit 1
    git ls-files -co --exclude-standard -z -- template | while IFS= read -r -d '' f; do
      [[ -f "$f" ]] || continue
      mkdir -p "$KIT/$(dirname "$f")"
      cp -p "$f" "$KIT/$f"
    done
    cp -p scripts/install.sh scripts/kit-upgrade-prompt.md "$KIT/scripts/"
    cp -p CHANGELOG.md "$KIT/"
    cd "$KIT" && git init -q && git add -A && git commit -qm "kit snapshot"
  ) >/dev/null || return 1
}

# A target repo on main with one commit. Prints nothing; sets TARGET.
mk_target() {
  TARGET="$BATS_TEST_TMPDIR/${1:-target}"
  mkdir -p "$TARGET"
  git -C "$TARGET" init -q
  echo "# target" >"$TARGET/README.md"
  git -C "$TARGET" add README.md
  git -C "$TARGET" commit -qm init
}

# Install the kit into $TARGET and commit, so later edits show as changes.
installed_target() {
  mk_kit
  mk_target "${1:-target}"
  "$KIT/scripts/install.sh" "$TARGET" >/dev/null
  git -C "$TARGET" add -A
  git -C "$TARGET" commit -qm "install kit"
}

# Put tests/stubs/<name> first on PATH.
use_stub() {
  local d="$BATS_TEST_TMPDIR/stubs"
  mkdir -p "$d"
  local n
  for n in "$@"; do ln -sf "$REPO_ROOT/tests/stubs/$n" "$d/$n"; done
  case ":$PATH:" in *":$d:"*) ;; *) export PATH="$d:$PATH" ;; esac
}

# Rebuild PATH as one directory of symlinks to everything on PATH except the named commands.
path_without() {
  local d="$BATS_TEST_TMPDIR/path-without" dir f name skip n
  rm -rf "$d"
  mkdir -p "$d"
  local IFS=:
  for dir in $PATH; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*; do
      name=${f##*/}
      [[ -x "$f" && ! -e "$d/$name" ]] || continue
      skip=0
      for n in "$@"; do [[ "$name" == "$n" ]] && skip=1; done
      ((skip)) || ln -s "$f" "$d/$name"
    done
  done
  export PATH="$d"
}

# Skip unless the real tool is installed; with KIT_REQUIRE_REAL_TOOLS=1 (CI) fail instead.
require_real() {
  local p
  p=$(command -v "$1" 2>/dev/null) || p=""
  if [[ -z "$p" || "$p" == "$REPO_ROOT/tests/stubs/"* || "$p" == "$BATS_TEST_TMPDIR/"* ]]; then
    if [[ "${KIT_REQUIRE_REAL_TOOLS:-}" == 1 ]]; then
      fail "$1 is required (KIT_REQUIRE_REAL_TOOLS=1) but not installed"
    fi
    skip "$1 not installed"
  fi
}

# A GitHub-token-shaped fake secret, generated at runtime so no literal secret is ever committed.
fake_token() {
  local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 s="" i
  for ((i = 0; i < 36; i++)); do s+=${chars:$((RANDOM % ${#chars})):1}; done
  printf 'ghp_%s' "$s"
}

# Add the real maintainer tools to PATH (for tests that need gitleaks etc.).
with_tools() {
  [[ -d "$REPO_ROOT/.tools/bin" ]] && export PATH="$REPO_ROOT/.tools/bin:$PATH"
  return 0
}
