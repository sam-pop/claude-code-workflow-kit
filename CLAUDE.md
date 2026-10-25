# {{PROJECT_NAME}}

{{ONE_SENTENCE_DESCRIPTION}}

A session starts with `handoff.md` when it exists: current status, what is next, questions waiting on the owner. Then `docs/open.md`, so you know what is undecided. **Never pick a value for an open item; flag it or ask.** Decisions live in `docs/decisions.md` and only there; when one is made, move it there and remove it from `docs/open.md`.

## Stack

{{STACK: language, framework, runtime version, package manager, database, hosting. One line each.}}

## Commands

Always go through `scripts/check.sh`. Never run raw tool commands for verification.

```bash
scripts/check.sh lint    # format + lint + type-check
scripts/check.sh test    # unit and integration tests
scripts/check.sh build    # production build
scripts/check.sh security # secret scan, dependency audit, SAST
scripts/check.sh all      # everything, in that order
scripts/check.sh dev      # run locally
```

## Layout

| Path | Contents |
|---|---|
| {{path}} | {{what lives here}} |
<!-- kit: one row per top-level folder that matters. Point to deeper docs rather than describing internals here. -->

## Rules

Full rules: `docs/conventions.md`. The agents enforce them; the mechanical ones also run in `scripts/check.sh lint`. The short version:

- {{RULE_1: e.g. "All data access goes through the repository layer; no SQL or SDK calls in handlers."}}
- {{RULE_2}}
- {{RULE_3}}
<!-- kit: five to eight lines maximum. Each must be a rule, not a fact about the codebase. -->

## Workflow

1. **Small fix** (one file, obvious, reversible): writer agent, then reviewer agent. Commit.
2. **Anything else**: planner agent (blueprint) → writer agent (code, tests, `check.sh all`) → reviewer agent (findings). Report the reviewer's findings and what was done with each before committing.
3. **Security-sensitive change** (auth, payments, tenancy, external input, data export): the security-auditor agent after the reviewer. Critical and High findings block; Medium and Low go to `docs/open.md`. Also run it before each release.
4. A session handed work for another session says which agents to run and asks for the reviewer's findings back.

Agents: `.claude/agents/planner.md`, `writer.md`, `reviewer.md`, `security-auditor.md`. Last audit: `docs/security.md`.

## Recording

- Decisions → `docs/decisions.md`, dated. Decisions only; no analysis.
- Open items → `docs/open.md`, with an ID (`O1`, `O2`…). Other docs refer to the ID.
- Terms → `docs/glossary.md`. Use its words in code, docs and prompts; add a term once it has been explained twice.
- Status, next steps, questions → `handoff.md`, rewritten at the end of every session.
- {{PRIVACY_RULE, if any: e.g. "No customer names, keys or sample data in tracked files."}}

## Environment

{{ENVIRONMENT: secrets file name and how to get it, required local services, anything that fails silently without setup. Keep it to what a new session actually trips on.}}
