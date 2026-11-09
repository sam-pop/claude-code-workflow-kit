# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). `scripts/install.sh` reads the version from the first `## [x.y]` heading below.

## [1.5] — Unreleased

### Added

- `scripts/check-stamp.sh` and a `Stop` hook: `scripts/check.sh all` records the working tree it passed on (in `.git/kit/check-passed`, never committed), and when Claude finishes a turn after files changed since, the session shows which files. Silent when nothing changed and until `check.sh` is configured.
- `scripts/verify-review.sh`: each saved review and Codex report gets a `### Verification` block. Every Standards and Spec finding now quotes the line it cites; the script checks the quote against the file (within 3 lines, or a removed line in the diff), checks that `### Coverage` names every changed file, and lists missing sections. Issues also show as a one-line message when the report is saved.
- `.github/dependabot.yml` for the SHA-pinned actions.
- `check.sh doctor` review stats count incomplete reports and unverified quotes, and warn when `scripts/check.sh` does not run `scripts/check-stamp.sh record`.
- `DOCTOR_SKIP_PATHS` (space-separated) leaves paths out of the doctor's open-item scan, for a vendored copy of something that uses its own IDs.
- `check.sh doctor` warns when a tailored repo (no `TAILOR.md`) still has the `hashFiles('TAILOR.md')` CI gate, or when `CLAUDE_CODE_USE_BEDROCK`, `_VERTEX` or `_FOUNDRY` is set (aliases differ by provider).
- More `permissions.deny` rules: `git branch -f`, `git update-ref`, `git stash clear`, `gh pr create`, `gh pr merge`, `gh repo delete`, `gh repo edit`, `gh repo archive`, `gh repo create`, `gh repo sync`.

### Changed

- The installable files live under `template/` in the kit repository; `scripts/install.sh` copies `template/` as is and never writes into the kit, so it works from a read-only copy or one without `.git`. Installed paths are unchanged: a repo installed from 1.4 upgrades with nothing retired.
- The merge-session prompt moved to `scripts/kit-upgrade-prompt.md` in the kit (it was never installed).
- The reviewer's Output: findings name the full `path:line` with the source line quoted under it, and a new `### Coverage` section lists every changed file read (or why not).
- `check.yml`: top-level `permissions: contents: read`, concurrency with cancel-in-progress, a 20-minute timeout, actions pinned to a commit SHA with `persist-credentials: false`, gitleaks 8.30.1 downloaded and checked against its sha256 before unpacking, semgrep pinned.
- gitleaks 8.30.1 everywhere (was 8.21.2).
- `scripts/codex-review.sh` hardening: gitleaks is required (exit 3 without it; before, the scan was skipped with a warning and the diff was sent); the reviewer checklist sent to Codex comes from the base, not the change; the run refuses (exit 5) when the change edits `scripts/codex-review.sh` or `codex-reviewer.md`, or when a tracked `.env`, `*.pem`, `*.p12` or SSH key would be sent; the trusted base is `origin/<base>` when `<base>` is a branch with a remote-tracking copy (any other ref is used as given), and a local base at or ahead of HEAD is refused (exit 2); tracked and untracked symlinks and `.codex/` are removed from the review tree and listed, with names made printable; an `AGENTS.md` is named in the report header. Limitation, documented: a base `.gitleaks.toml` with a relative `[extend] path` cannot be resolved, so the run refuses as if secrets were found.
- `max` and the Astra release model are labelled experimental; `pin()` is gone from `codex-review.sh` (it only guarded constants).
- Hook messages carry counts and at most three quoted, printable-ASCII names (40 characters), never raw file names or tool output: the Stop warning, the review-saved message and the lint hook's output.
- `scripts/verify-review.sh`: coverage counts only exact paths on the `read:` line; a finding with no parsable path counts as `unparsed` (an issue); a bold label before the path is accepted; quotes under 12 non-space characters and 2 words are `quote too short`; the removed-line fallback needs the `(removed)` prefix; paths outside the repository are never opened.
- The doctor's open-item scan reads only kit-owned files (`CLAUDE.md`, `handoff.md`, `docs/*.md`, `.claude/agents/`, `.claude/optional/`), and an ID must stand alone, so `-O2` and IDs in code no longer count.
- Agents described as "Read-only" are now described as having no edit tools, with Bash limited by instruction; reviewer quotes replace secret values with `…`.
- Shell scripts formatted with shfmt and clean under shellcheck; behaviour unchanged except where Fixed says so.
- The kit repository installs itself at its root and runs its own checks (shellcheck, shfmt, markdownlint, lychee, actionlint, a bats suite, gitleaks) in CI on Linux and macOS `/bin/bash` 3.2.

### Fixed

- `scripts/codex-review.sh` stops with `codex-review: git diff failed` (exit 1) when building the diff fails, for example on a required clean filter that errors; before, it reviewed a partial diff.
- `CLAUDE.md` wrote the example open-item ID as `O1`, so `check.sh doctor` failed on any tailored repo whose `docs/open.md` had no O1. It now reads `Oxx`.
- `check.sh doctor` read codex report names with spaces as several files.
- `scripts/install.sh` made every `scripts/*.sh` in the target executable, including the target's own scripts; it now sets the mode only on files it writes (executable when the kit's copy is, and every `.sh`, so a kit copy that lost its modes still installs runnable scripts), and refuses (exit 1, before writing anything) when a destination, its `.kit` sibling or a state file resolves outside the target through a symlink, dangling or not. A second positional argument is a usage error (exit 2) instead of silently winning.
- `scripts/capture-review.sh`: two reports in the same second overwrote each other; a counter is added and no file is overwritten. When `verify-review.sh` times out or fails, the report gets `not run (timeout|error)` and the session is told.
- `check.sh lint --changed` fell back to nothing when the base branch exists only as `origin/<base>`.
- `check.sh doctor` read CRLF frontmatter only with GNU sed.

### Upgrade notes

- A tailored `scripts/check.sh`: add the two stamp lines to `run_all`, the first before `lint`, the second after `doctor`:

  ```bash
  local rc=0 t
  t=$(bash scripts/check-stamp.sh tree 2>/dev/null)
  ...
  [[ $rc -eq 0 && -n "$t" ]] && bash scripts/check-stamp.sh record "$t"
  ```

  Without them the Stop hook stays silent and `check.sh doctor` warns.
- A tailored `.claude/settings.json`: add the `Stop` hook entry (`"${CLAUDE_PROJECT_DIR}/scripts/check-stamp.sh" hook`, timeout 30).
- A tailored `.claude/agents/reviewer.md`: merge the new Output format (the quote line under each finding, `### Coverage`, the paragraph about verification). Keep the five sections `codex-review.sh` reads (from the base's copy, so an edit takes effect once it is on the base): Confidence, Checklist, Subtle violations, False positives, Output.
- A tailored `.github/workflows/check.yml`: adopt `permissions`, `concurrency`, `timeout-minutes`, the SHA-pinned checkout with `persist-credentials: false` and the gitleaks checksum step.
- `.github/dependabot.yml` arrives as new (or as `.kit` if you have one); delete it if you use another updater.
- Deleting `scripts/check-stamp.sh` but keeping the `Stop` entry in `settings.json` makes every turn end with a (non-blocking) hook error; remove both or neither.
- A tailored `.github/workflows/check.yml`: delete the "Kit not tailored yet" step and every `if: hashFiles('TAILOR.md')` line once `TAILOR.md` is gone; `doctor` warns while they remain.
- Cross-model review now needs gitleaks on the machine that runs it, and in high mode a base that is not HEAD: work on a branch, or keep `origin/<base>` fetched.
- An open-item ID used only in code comments is no longer checked by `doctor`; keep IDs in `docs/` or `CLAUDE.md`.
- A tailored `.claude/settings.json`: merge the new deny rules.
- Re-running `install.sh --upgrade` from a 1.4 kit after upgrading to 1.5 lists `scripts/check-stamp.sh`, `scripts/verify-review.sh` and `.github/dependabot.yml` as retired; they are not deleted.

## [1.4] — 2026-11-09

### Added

- Effort per role: `scripts/set-models.sh` writes `effort:` beside `model:`.
- Profile `lite` (Sonnet/high planner, writer and reviewer; Opus/high auditor) for Pro ($20) plans.
- Risk tiers (Low, Medium, High) that set the reviewer's effort, and a writer escalation ladder, both in the `CLAUDE.md` Workflow section.
- The writer's `## STUCK:` report and stop rules; `scripts/capture-review.sh` saves it as `*-stuck.md`.
- Optional cross-model review: `--cross` enables `codex-reviewer`, which relays `scripts/codex-review.sh` (Codex in a fresh copy of HEAD with no `.git`, gitleaks pre-scan of that copy and of the prompt, read-only sandbox, `timeout`). Reports are saved as `*-codex.md`.
- `scripts/install.sh --upgrade` (with `--force` for an unfinished merge) and `--dry-run`, `.claude/kit-version`, `.claude/kit-manifest`, and `.claude/kit-upgrade.md` (the merge prompt plus the classification; say "Read .claude/kit-upgrade.md").
- Doctor checks for settings that undo the effort setup (`CLAUDE_CODE_EFFORT_LEVEL`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, old Claude Code, `effortLevel`, `maxEffortLevel`), for Sonnet below `high`, for a missing `effort:`, for Fable billing, and for an unfinished upgrade merge. Review stats now count Codex reports and escalations separately.
- Research report and notes under `docs/research/`; README sections on cost, cross-model review, troubleshooting and upgrading.

### Changed

- Standard profile: planner opus/high, writer opus/medium (was Sonnet), reviewer opus/high, auditor opus/xhigh. The `max` profile: Fable planner and auditor, Opus writer and reviewer.
- The security auditor's Critical and High findings block a release only with a reproduction; its report records the served model.
- The reviewer's report gains a `### Run` line (tier, writer rung, requested model and effort).
- Claude Code v2.1.292 or later is required (the Agent tool's per-call `effort`).
- The installer copies only files tracked in the kit checkout (`git ls-files`), and no longer copies `README.md`, `CHANGELOG.md`, `docs/research/`, `docs/assets/` or the kit's own review log.

### Fixed

- `scripts/doctor.sh` no longer fails on binary files or on research and release documents when it looks for undeclared open-item IDs.

### Upgrade notes

- The writer is now opus/medium: re-run `scripts/set-models.sh <profile> [--cross]` after merging.
- If `.claude/settings.json` is tailored, add `codex-reviewer|writer` to the `SubagentStop` matcher (`reviewer|security-auditor|codex-reviewer|writer`).
- Merge the `CLAUDE.md` `## Workflow` text: risk tiers, cross-model review and the writer ladder.
- The reviewer's output gains a `### Run` line, and the auditor's a `Run:` line.
- A repo from before 1.4 has no manifest, so every existing kit file that differs from 1.4 arrives as `.kit` once. Then open Claude Code and say: Read .claude/kit-upgrade.md

## [1.3]

- Fixes from an adversarial audit of the kit (commit d5fe8e1, "v1.3: fixes from adversarial audit").

## [1.2]

- Claude Kit v1.2 (commit 8b33a24).
