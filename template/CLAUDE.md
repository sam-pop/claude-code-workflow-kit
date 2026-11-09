# {{PROJECT_NAME}}

{{ONE_SENTENCE_DESCRIPTION}}

The main session starts with `handoff.md` when it exists (status, next steps, questions waiting on the owner), then `docs/open.md`. Items in `docs/open.md` are the owner's to decide: design around them and flag them. When one is decided, record it in `docs/decisions.md` and remove it from `docs/open.md`.

## Stack

{{STACK: language, framework, runtime version, package manager, database, hosting. One line each.}}

## Commands

Verify through `scripts/check.sh`, so every agent, hook and CI run checks the same thing.

```bash
scripts/check.sh lint      # format + lint + type-check
scripts/check.sh test      # unit and integration tests
scripts/check.sh build     # production build
scripts/check.sh security  # secret scan, dependency audit, SAST
scripts/check.sh doctor    # kit hygiene
scripts/check.sh all       # everything
```

Run locally: {{DEV_COMMAND}}

## Layout

| Path | Contents |
|---|---|
| {{path}} | {{what lives here}} |
<!-- kit: one row per top-level folder that matters. Point to deeper docs rather than describing internals here. -->

## Rules

Full rules: `docs/conventions.md`. The short version:

- {{RULE_1: e.g. "Data access goes through the repository layer; handlers call the domain."}}
- {{RULE_2}}
- {{RULE_3}}
<!-- kit: five to eight lines, each a rule phrased as what to do. -->

## Workflow

Run agents in the foreground, one at a time, and wait for each report before starting the next.

1. **Small fix** (1–2 files, obvious, reversible): make the change in the main session, run `scripts/check.sh all`, then the **reviewer** agent.
2. **Larger change** (3+ files, a migration, or the owner asks): the **planner** agent; it states the risk tier, and you confirm the tier with the owner. Put its Questions to the owner in one round, each with its recommended answer, and wait. Then the **writer** agent with the confirmed blueprint, then the **reviewer** agent.
3. **Before a release**, and quarterly: the **security-auditor** agent. Critical and High findings block the release only when they carry a reproduction; note the served model (from `/tasks`) on the saved report.
4. Report the reviewer's findings and what was done with each before committing; read the `### Verification` block at the end of the saved report (`docs/reviews/`) and pass on its unverified quotes, uncovered files and an incomplete status. Pushing and merging are the owner's.

Agents brief each other through the delegation prompt: name the change, the files, the blueprint if any, the base branch, and the rung and risk tier below.

### Risk tiers

The tier sets the reviewer's effort. Pass it as the Agent tool's `effort` parameter; this section authorises that. Never below `medium`.

| Tier | Change | Reviewer `effort` |
|---|---|---|
| Low | Small fix in the main session | `medium` |
| Medium | Normal blueprint change | `high` (frontmatter default) |
| High | Auth, tenancy, money, personal data, secrets, migrations or destructive writes, concurrency, `.claude/` `scripts/` or CI, or any escalated writer output | `xhigh` (a hypothesis: `docs/rollout.md` has the measure that drops it) |

Tiers change the reviewer's effort only, never its model: the reviewer never runs on the writer's model.

### Cross-model review

Only if `.claude/agents/codex-reviewer.md` exists (`scripts/extras.sh on codex`). On a larger change, save the planner's blueprint to a file in the repo and run **codex-reviewer** on it (`scripts/codex-review.sh plan <file>`) before the owner's question round; show its objections next to the planner's questions. Run it again after the reviewer on High-risk diffs (`scripts/codex-review.sh high <base>`) and once before a release (`scripts/codex-review.sh release`). Show the owner where it agrees with the reviewer and what only it raised. It never blocks.

### Writer ladder

Rung 1 is the writer as defined. Escalate on: a check still failing after the writer's own fixes; the reviewer's re-run disagreeing with the writer's report; a blocking finding surviving one repair pass at the same rung; a `## STUCK:` report; the owner reporting a rung that used more than 3x its usual tokens. NOT CONFIGURED checks and Warnings never trigger escalation.

- **Rung 2 and on**: a fresh writer one effort step up (Agent `effort`), on the same model, given the blueprint and a failure brief. Never resume the failed one. The tree holds the last attempt: keep, fix or revert from it.
- Steps: a writer at `high` (lite, standard) goes to `xhigh`; one at `medium` (max) goes to `high`, then `xhigh`. Never pass Agent `model`: an escalated writer must not land on the reviewer's model. The measured gain came from re-running failures at higher effort; switching models mid-ladder was never measured.
- **Then stop**: briefs go to the planner and the owner is told.

Name the rung and the trigger in each writer and reviewer prompt.

## Recording

- Decisions → `docs/decisions.md`, dated.
- Open items → `docs/open.md`, with an ID (`Oxx`), an opened date, a decide-by date and an owner.
- Terms → `docs/glossary.md`, when a term has been explained twice.
- Status, next steps, questions → `handoff.md`, rewritten at the end of every session. It holds no secrets, credentials or customer data.
- {{PRIVACY_RULE, if any: e.g. "Tracked files hold no customer names, keys or sample data."}}

## Environment

{{ENVIRONMENT: secrets file name and how to get it, required local services, anything that fails silently without setup.}}
