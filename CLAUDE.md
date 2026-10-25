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
2. **Larger change** (3+ files, a migration, or the owner asks): the **planner** agent. Put its Questions to the owner in one round, each with its recommended answer, and wait. Then the **writer** agent with the confirmed blueprint, then the **reviewer** agent.
3. **Before a release**, and quarterly: the **security-auditor** agent. Critical and High block the release.
4. Report the reviewer's findings and what was done with each before committing. Pushing and merging are the owner's.

Agents brief each other through the delegation prompt: name the change, the files, the blueprint if any, and the base branch.

## Recording

- Decisions → `docs/decisions.md`, dated.
- Open items → `docs/open.md`, with an ID (`O1`…), an opened date, a decide-by date and an owner.
- Terms → `docs/glossary.md`, when a term has been explained twice.
- Status, next steps, questions → `handoff.md`, rewritten at the end of every session. It holds no secrets, credentials or customer data.
- {{PRIVACY_RULE, if any: e.g. "Tracked files hold no customer names, keys or sample data."}}

## Environment

{{ENVIRONMENT: secrets file name and how to get it, required local services, anything that fails silently without setup.}}
