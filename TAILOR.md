# Tailoring the kit to this repo

You are a Claude Code session adapting the Claude Kit to the repository you are running in. Work through the steps in order. Do not write code for the product. Do not resolve product or architecture questions on the owner's behalf: anything you cannot settle from the repo itself goes into `docs/open.md` or a question to the owner.

## 1. Discover

Build a picture of the repo before touching any kit file. Use the Explore agent for anything beyond a quick look.

- **Stack**: languages, frameworks, package manager, runtime version, monorepo or single app, deploy target. Look at manifests (`package.json`, `pyproject.toml`, `go.mod`, `Package.swift`, `build.gradle`, etc.), lockfiles, Dockerfiles, CI config.
- **Commands**: how to install, build, lint, format, type-check, test, run locally. Prefer scripts the repo already defines (`npm run …`, `make …`) over reconstructing them.
- **Existing rules**: any `CLAUDE.md`, `AGENTS.md`, `.cursorrules`, `CONTRIBUTING.md`, lint and formatter configs, editorconfig, pre-commit hooks, CI workflows. These are the owner's current conventions; carry them over, do not replace them.
- **Layout**: top-level folders and what each holds. Where domain logic, data access, UI, infrastructure and tests live.
- **Patterns**: open 2 to 3 representative files per layer and note how things are actually done (DI, error handling, state, naming, test style). Report what the code does, not what docs claim.
- **Secrets and config**: how env vars and secrets are loaded; which files are git-ignored.
- **Size and team**: solo or shared, rough file count, whether there is a product owner separate from the engineer.

## 2. Ask the owner

Ask only what discovery could not answer, in rounds: every question whose prerequisites are settled goes in the same round, numbered, each with a recommended answer worded so that "yes" accepts it. If the `grilling` skill from mattpocock/skills is installed, use it; its format is the one meant here. Typical questions:

1. Tier (see `docs/rollout.md`): script, solo, shared, or review-only (other people write the code)? This decides which agents exist and whether `handoff.md` is committed. If discovery shows most commits are by people other than the owner, propose review-only.
2. Which model runs the reviewer: Fable for client/shared work, Opus for solo (the kit defaults to Fable).
3. Any rules you know you want enforced that the repo does not yet show.
4. Is there a product owner whose decisions must be recorded separately from engineering decisions?
5. Anything in the repo that is intentionally non-standard and should not be "fixed".

If the owner is not available, take the most reasonable reading, say which reading you took at the top of your report, and proceed.

**If the tier is Review-only, stop here and switch plans.** Do not install hooks, `.claude/settings.json` or `scripts/` into a repo other people commit to (`docs/rollout.md`, Review-only). Instead set up a separate review workspace: copy `.claude/agents/reviewer.md`, `.claude/agents/security-auditor.md` and `docs/conventions.md` into it, tailor those three to the client repo's stack, and write a short `CLAUDE.md` there saying where the client repo is checked out and that reviews use `gh pr diff <n>`. Then go to step 6.

## 3. Fill in

First, merge any `*.kit` files the installer left beside existing files (for example `CLAUDE.md.kit` next to the repo's own `CLAUDE.md`): keep the repo's existing rules and content, take the kit's structure, then delete the `.kit` file.

Replace every `{{PLACEHOLDER}}` and delete every `<!-- kit: … -->` comment once its instruction is done. Search for `{{` at the end to confirm none remain.

- `CLAUDE.md`: stack, layout table, the exact `check.sh` sub-commands, pointers. Keep it under 150 lines. Move anything that reads like history out.
- `scripts/check.sh`: replace every `not_configured` call with the repo's real commands, including a `lint --changed` that lints only the given files. Every function must exit non-zero on failure. A check that truly does not apply becomes `skip "<reason>"`. Until a check is configured it fails on purpose.
- `docs/conventions.md`: write the sections from what discovery found. Each rule in the Anti-Patterns table must have a mechanical check in `check.sh` or be marked **judgment** (reviewer only). Use the stack's existing lint rules where one already covers a row. Writing new custom rules is a follow-up task, not part of tailoring: list the rows that still need one under **Follow-ups** in your report.
- `docs/decisions.md`: record the decisions already visible in the repo (stack, major libraries, deploy target), dated with the best date you can find (commit history), not today's date.
- `docs/open.md`: everything discovery left unresolved, plus anything the owner said is undecided.
- `.claude/agents/*.md`: keep the structure; replace the stack-specific examples in the reviewer's "Subtle violations" and "False positives" lists with ones that fit this stack. Set the reviewer's `model`. Remove layers from the writer's workflow that this repo does not have. In `security-auditor.md`, name the sensitive data classes this repo holds and fill the stack-specific area; delete the file on Script and Solo tiers.
- `scripts/check.sh security`: pick the dependency-audit command for the stack and the semgrep ruleset; confirm gitleaks and semgrep are installed or add them to the setup instructions in `CLAUDE.md`.
- `.claude/settings.json`: keep the hooks as they are; they call `scripts/lint-hook.sh` and `scripts/capture-review.sh`. If `check.sh lint --changed` takes over ~10 s, make it faster (lint only the changed files) rather than removing the hook. Add `permissions.deny` rules for anything else in this repo that must never run unattended (a deploy script, a production database CLI).
- `.github/workflows/check.yml`: install gitleaks and semgrep (already there) and the stack's runtime.
- Delete `.github/workflows/check.yml` if the repo is not on GitHub.
- `handoff.md`: write the first one: what you did, what remains, questions for the owner. Add it to `.gitignore` only if the owner chose solo tier.

## 3b. Write for the agent that will read it

Every file in `.claude/agents/` and `CLAUDE.md` is read by a model, not a person. Before moving on, pass over each one (the `writing-for-agents` skill from mattpocock/skills covers this in depth if installed):

- **Positive phrasing.** "Never log personal data" drags the forbidden thing into context; "log identifiers only" says what to do. Rewrite prohibitions as targets; keep a prohibition only as a hard guardrail, paired with the positive.
- **No-ops.** Delete any sentence the model would obey without being told ("be thorough", "be careful"). The test is whether it changes behaviour against the default.
- **Pointers over copies.** A fact the environment already states (`package.json` scripts, a config file) is not repeated in a doc; the doc points at it. Cache only what cannot be looked up: the unwritten convention, the reason behind a choice.
- **One meaning, one place.** Where the same rule appears in two files, keep it in `docs/conventions.md` and point at it from the other.
- **Completion criteria.** Every step an agent performs ends on a condition it can check ("every modified file has a test or a one-line reason it needs none"), not a vague state ("tests are adequate").

## 4. Remove

- Delete `TAILOR.md`, `HOW-TO-USE.md` and this kit's `README.md` from the repo. If the repo has no README, write a short one that mentions `CLAUDE.md` and `scripts/check.sh`.
- Delete agent files the tier does not use.

## 5. Verify

- Run `scripts/check.sh all` and paste the last 15 lines of its output, verbatim, into your report. `doctor` inside it fails on any placeholder, kit note or unconfigured check that remains; fix those until it passes, or list exactly which remain and why.
- Read `CLAUDE.md` once more as a stranger would: can a new session find the commands, the rules and the open items in under a minute?

## 6. Report

End with: the tier chosen and why, files created or changed, the pasted `check.sh all` output, the open items you recorded, **Follow-ups** (lint rules still to write, checks still unconfigured), and the questions waiting on the owner. Keep it under 40 lines.
