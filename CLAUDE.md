# Claude Kit

The kit itself: templates, agents, hooks and scripts installed into other repositories (`template/`), maintained here with its own workflow (the root is an install of `template/`).

The main session starts with `handoff.md` when it exists (status, next steps, questions waiting on the owner), then `docs/open.md`. Items in `docs/open.md` are the owner's to decide: design around them and flag them. When one is decided, record it in `docs/decisions.md` and remove it from `docs/open.md`.

## Stack

- Shell: bash 3.2 or later, BSD and GNU userland (macOS and Linux); inline Python: python3 3.8 or later, standard library only.
- Git and GitHub; CI in `.github/workflows/check.yml`.
- Maintainer tools: node 22 (`.nvmrc`) with `npm ci` for bats and markdownlint-cli2; `scripts/tools.sh install` for shellcheck, shfmt, gitleaks, lychee and actionlint (pinned, checksum-verified, into `.tools/bin`).

## Commands

Verify through `scripts/check.sh`, so every agent, hook and CI run checks the same thing.

```bash
scripts/check.sh lint      # shellcheck, shfmt, markdownlint-cli2, lychee (offline), actionlint
scripts/check.sh test      # bats tests/
scripts/check.sh build     # skipped: the kit ships source
scripts/check.sh security  # gitleaks, tracked sensitive files
scripts/check.sh doctor    # kit hygiene (template/ left out of the open-item scan)
scripts/check.sh all       # everything
```

Setup once: `npm ci && scripts/tools.sh install`. One test file: `npx bats tests/install.bats`. After editing anything under `template/`: `scripts/install.sh --upgrade .`, merge any `.kit` files, delete `.claude/kit-upgrade.md`.

## Layout

| Path | Contents |
|---|---|
| `template/` | The product: exactly what `scripts/install.sh` installs. Edit here. |
| root `CLAUDE.md`, `.claude/`, `docs/`, `scripts/`, `.github/` | Dogfood copies of `template/`, tailored to this repo; synced with `scripts/install.sh --upgrade .` |
| `scripts/install.sh`, `scripts/kit-upgrade-prompt.md`, `scripts/tools.sh` | The installer, the merge-session prompt it embeds, and the pinned maintainer tools; never installed |
| `tests/` | bats tests, `helpers.bash`, `stubs/`, `fixtures/` |
| `docs/research/` | Evidence behind the model and effort defaults |
| `README.md`, `CHANGELOG.md` | Public docs; the installer reads the version from `CHANGELOG.md` |

## Rules

Full rules: `docs/conventions.md`. The short version:

- Edit `template/` first, then sync the root with `scripts/install.sh --upgrade .`.
- Write shell for bash 3.2 and BSD userland; python3 inline code uses the standard library only.
- Add no runtime dependency to `template/`: targets need only bash, git and python3.
- Never overwrite a file a target tailored: the installer writes a `.kit` sibling instead.
- Every bug fix ships with a bats test that fails without the fix.
- Keep `template/CLAUDE.md` at 150 lines or fewer.
- A behaviour change updates README, `template/HOW-TO-USE.md` and the CHANGELOG Upgrade notes.

## Workflow

Run agents in the foreground, one at a time, and wait for each report before starting the next.

1. **Small fix** (1–2 files, obvious, reversible): make the change in the main session, run `scripts/check.sh all`, then the **reviewer** agent.
2. **Larger change** (3+ files, a migration, or the owner asks): the **planner** agent; it states the risk tier, and you confirm the tier with the owner. Put its Questions to the owner in one round, each with its recommended answer, and wait. Then the **writer** agent with the confirmed blueprint, then the **reviewer** agent.
3. **Before a release**, and quarterly: the **security-auditor** agent. Critical and High findings block the release only when they carry a reproduction; note the served model (from `/tasks`) on the saved report.
4. Report the reviewer's findings and what was done with each before committing. Pushing and merging are the owner's.

Agents brief each other through the delegation prompt: name the change, the files, the blueprint if any, the base branch, and the rung and risk tier below.

### Risk tiers

The tier sets the reviewer's effort. Pass it as the Agent tool's `effort` parameter; this section authorises that. Never below `medium`.

| Tier | Change | Reviewer `effort` |
|---|---|---|
| Low | Small fix in the main session | `medium` |
| Medium | Normal blueprint change | `high` (frontmatter default) |
| High | Auth, tenancy, money, personal data, secrets, migrations or destructive writes, concurrency, `.claude/` `scripts/` or CI, or any escalated writer output | `xhigh` |

On the **lite** profile (`.claude/agents/writer.md` has `model: sonnet`) Low and Medium use the reviewer as defined (sonnet/high); High passes Agent `model: opus, effort: medium`.

### Cross-model review

Only if `.claude/agents/codex-reviewer.md` exists (`scripts/set-models.sh <profile> --cross`). Run **codex-reviewer** after the reviewer on High-risk diffs (`scripts/codex-review.sh high <base>`) and once before a release (`scripts/codex-review.sh release`). Show the owner where it agrees with the reviewer and what only it raised. It never blocks.

### Writer ladder

Rung 1 is the writer as defined. Escalate on: a check still failing after the writer's own fixes; the reviewer's re-run disagreeing with the writer's report; a blocking finding surviving one repair pass at the same rung; a `## STUCK:` report; the owner reporting a rung that used more than 3x its usual tokens. NOT CONFIGURED checks and Warnings never trigger escalation.

- **Rung 2**: a fresh writer with Agent `effort: high`, given the blueprint and a failure brief. Never resume the failed one. The tree holds the last attempt: keep, fix or revert from it.
- **Rung 3**: a fresh writer with Agent `model: fable, effort: high` if `.claude/agents/planner.md` has `model: fable` (max profile), else `effort: xhigh`.
- **Lite** (`writer.md` has `model: sonnet`): rung 1 is sonnet/high, rung 2 Agent `model: opus, effort: medium`, rung 3 `model: opus, effort: high`.
- **Then stop**: briefs go to the planner and the owner is told.

Name the rung and the trigger in each writer and reviewer prompt.

## Recording

- Decisions → `docs/decisions.md`, dated.
- Open items → `docs/open.md`, with an ID (`Oxx`), an opened date, a decide-by date and an owner.
- Terms → `docs/glossary.md`, when a term has been explained twice.
- Status, next steps, questions → `handoff.md`, rewritten at the end of every session. It is local to the maintainer (git-ignored), like the saved reports in `docs/reviews/`.
- `template/` holds nothing about this repo or its maintainer: no names, emails, pre-release plans or root-only paths (`tests/consistency.bats`).

## Environment

No secrets and no services. Without `npm ci` and `scripts/tools.sh install`, `scripts/check.sh` fails and names the missing tool. Tests need no network; they use stubs in `tests/stubs/` for codex, gitleaks, timeout and claude unless `KIT_REQUIRE_REAL_TOOLS=1`.
