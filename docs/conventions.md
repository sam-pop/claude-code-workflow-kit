# Conventions

Status: ADOPTED. This is the one file the planner, writer and reviewer cite. Every rule here is either **mechanical** (checked by `scripts/check.sh`, named in the Enforcement column) or **judgment** (checked by the reviewer).

## Architecture

- `template/` is the product: exactly what `scripts/install.sh` installs into a target, at the same paths. Edit there first.
- The root is an install of `template/` tailored to this repo (dogfood copies), plus maintainer-only files: `scripts/install.sh`, `scripts/kit-upgrade-prompt.md`, `scripts/tools.sh`, `tests/`, `docs/research/`, `docs/example-review.md`, `README.md`, `SECURITY.md`, `CHANGELOG.md`. After a `template/` edit, run `scripts/install.sh --upgrade .` and merge any `.kit` file into the root copy.
- Hooks in `.claude/settings.json` call scripts in `scripts/`; the logic lives in the script, never inline in the JSON.
- A script finds the repo by its own location (`cd "$(dirname "$0")/.."`) or by `CLAUDE_PROJECT_DIR` for hooks, never by the caller's working directory.
- `scripts/install.sh` never writes inside the kit: it works from a read-only copy or one without `.git`.
- An extra is its files: dormant in `.claude/optional/`, active in `.claude/agents/` or `scripts/`. Core scripts call an extra's script only when it is active, and `scripts/extras.sh` is the one way to switch.

## Configuration

- Scripts read environment variables only where their header documents them (`BASE_BRANCH`, `DOCTOR_SKIP_PATHS`, `KIT_EXTRAS_REPO`, `CLAUDE_PROJECT_DIR` for hooks). No secrets anywhere in the kit.

## Errors

- Each script's header states its usage and exit codes; `scripts/check.sh` exits 2 for NOT CONFIGURED, 1 for a failing check.
- Hook scripts that only observe (`capture-review.sh`) always exit 0 and stay silent on their own errors: a hook bug never blocks the user's work. `lint-hook.sh` exits 2 only to hand a lint failure to Claude.
- A failing command whose output a script uses is checked (`|| { echo "...: git diff failed" >&2; exit 1; }`); a script never continues on a partial result.

## Data

- `.claude/kit-version` (`version=… commit=… installed=…`), `.claude/kit-manifest` (`<sha256>  <path>` per installed file) and the set of paths under `template/` are compatibility contracts with every repo installed since 1.4. A path removed from `template/` shows as `retired` in those repos; a renamed one needs handling in `install.sh` (a file moved into an extra is matched through `active_path`).
- Tracked files hold no maintainer working state: saved reports (`docs/reviews/*-*.md`) are git-ignored at the root.

## Naming and files

| Thing | Pattern | Example |
|---|---|---|
| Scripts | kebab-case `.sh`, executable (mode 100755) | `scripts/capture-review.sh` |
| Tests | `tests/<script-or-area>.bats` | `tests/install.bats` |
| Test names | the behaviour and, for a regression, the bug | `@test "upgrade: tailored file with unchanged kit copy gets no .kit"` |
| Stubs | `tests/stubs/<command>` | `tests/stubs/codex` |

## Testing

Write a test where it catches a real bug: an install or upgrade class, an exit-code path, a hook that must stay silent, a portability trap. Every bug fix ships a bats test that fails without the fix.

Test runner: bats (`bats -r tests`), with bats-support and bats-assert from `node_modules`. Pattern: `setup` builds what the test needs in `$BATS_TEST_TMPDIR`; `tests/helpers.bash` gives a committed kit snapshot (`mk_kit`), a target repo (`mk_target`), command stubs (`use_stub`), a PATH without a command (`path_without`) and runtime-generated fake secrets (`fake_token`).

- Each test runs with its own `HOME` and `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_NOSYSTEM=1`, and no network.
- External tools (codex, gitleaks, timeout, claude) are stubs on PATH unless a test needs the real one (`require_real`); CI on Linux sets `KIT_REQUIRE_REAL_TOOLS=1` so those tests fail instead of skipping.
- No literal secret is ever committed, in tests or anywhere else; fake tokens are generated when the test runs.

## Logging and privacy

- Scripts print paths, counts and exit codes; never file contents that might hold secrets (gitleaks runs with `--redact`).
- `template/` holds nothing about this repo or its maintainer: no names, emails, pre-release plans or root-only paths.

## Known agent failure modes

- A check reported as passed that never ran: paste the exit code and the output tail; 0 tests or a narrowed filter is not a pass.
- `cmd; echo`, `cmd | tail` or `|| true` hiding an exit code: keep the command's own status.
- Stage by explicit path, never `git add -A` or `git add .`.
- Before committing, check the branch and `git rev-list --left-right --count origin/<base>...HEAD`.
- Kill only processes you started, by PID; never a pattern `pkill`.
- Write reports and scratch output outside any worktree the harness may remove.
- Add a line here when an agent fails in a new way.

## Anti-patterns

Each row is a hard rule. **Mechanical** rows name the check in `scripts/check.sh`; **judgment** rows are the reviewer's.

| Anti-pattern | Enforcement |
|---|---|
| Shell bug patterns (unquoted expansions, unchecked `cd`, `A && B \|\| C`) | mechanical: `lint` shellcheck |
| Shell formatting that differs from `.editorconfig` | mechanical: `lint` shfmt |
| Markdown structure errors | mechanical: `lint` markdownlint-cli2 (API with `noImport`) |
| A linter run that can load code from config in the tree, read a tracked file name as an option, or write files through a tree config | mechanical: `test` (`tests/check.bats`) |
| Tracked `.tools/` or `node_modules/` files (checkout would replace the tools `check.sh` runs) | mechanical: `test` (`tests/check.bats`) |
| Broken relative link or heading anchor in Markdown | mechanical: `lint` lychee `--offline --include-fragments` |
| Workflow syntax or expression errors | mechanical: `lint` actionlint |
| A secret in the tree | mechanical: `security` gitleaks |
| Inline `python3` without `-I` (a `json.py` or `re.py` in the working directory would be imported) | mechanical: `test` (`tests/consistency.bats`) |
| bash-4 syntax (`mapfile`, `declare -A`, `local -n`, `${x,,}`, `[[ -v`, `\|&`, `coproc`) | mechanical: `test` (`tests/consistency.bats`) |
| Root copy drifting from `template/` | mechanical: `test` (`tests/consistency.bats`) |
| Maintainer content inside `template/` | mechanical: `test` (`tests/consistency.bats`) |
| Core keeping state with every extra off | mechanical: `test` (`tests/check.bats`) |
| Bug fix without a regression test | judgment |
| A hook that can block or print noise on its own failure | judgment |
| A new runtime dependency in `template/` (anything beyond bash, git, python3 stdlib) | judgment |
| An edit to a root dogfood copy that was not made in `template/` first | judgment |
| A behaviour change without README, `template/HOW-TO-USE.md` and CHANGELOG Upgrade notes | judgment |
| Resolving an item in `docs/open.md` without the owner | judgment |
| Unrelated refactors mixed into a change | judgment |
| A fix for a scanner-bypass finding (a secret passing the Codex gitleaks pre-scan) that adds code instead of a line in the blind-spot list in `docs/rollout.md`, when no documented guarantee is false | judgment |

## Definition of done

- `scripts/check.sh all` passes, or the report says exactly which part could not run.
- New behavior with branches or failure paths has a test that would catch its bug.
- No row of the Anti-patterns table is violated.
- Any new third-party dependency was called out for approval before being added.
- Any open item touched is still open, or the owner closed it and `docs/decisions.md` records it.
- A deploy is done when a post-deploy check against production passes, not when the deploy command exits.
