# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). `scripts/install.sh` reads the version from the first `## [x.y]` heading below.

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
