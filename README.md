<p align="center"><img src="docs/assets/social-preview.png" alt="Claude Kit" width="640"></p>

<h1 align="center">Claude Kit</h1>

<p align="center">
  <strong>A drop-in engineering workflow for <a href="https://claude.com/claude-code">Claude Code</a>.</strong><br>
  Fewer tokens, fewer silent decisions, and a written trail of what was actually checked.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href="https://github.com/sam-pop/claude-code-workflow-kit/actions/workflows/check.yml"><img alt="check" src="https://github.com/sam-pop/claude-code-workflow-kit/actions/workflows/check.yml/badge.svg"></a>
  <img alt="Version" src="https://img.shields.io/badge/version-1.6-informational">
  <img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-v2.1.292%2B-d97757">
  <img alt="Status" src="https://img.shields.io/badge/status-early-yellow">
</p>

<p align="center">
  This repo passes its own checks: the kit is installed at its root, and CI runs <code>scripts/check.sh all</code> on Linux and the test suite under macOS <code>/bin/bash</code> 3.2 on every change.
</p>

---

Claude Kit is a set of templates, agents, hooks and scripts you install into a repository. A Claude Code session then **tailors it to that repo's stack**, and from that point every change runs through a short, verifiable process: plan, implement, check, review. Claude follows that process instead of improvising one each time.

It's for anyone using Claude Code on real projects who needs to **trust the result**: to know what the agent decided on its own, what was actually tested, and what still needs a human eye. It works the same whether you code alone, on a team, or mostly review code that others (or agents) wrote.

## TL;DR

**Get started.** You need Claude Code v2.1.292 or later, `git`, `bash` and `python3`; `gitleaks` and `semgrep` for the security check.

```bash
git clone https://github.com/sam-pop/claude-code-workflow-kit.git
claude-code-workflow-kit/scripts/install.sh /path/to/your-repo
```

Then open Claude Code in your repo and say **Read TAILOR.md and tailor the kit to this repo.** It asks one round of questions, wires `scripts/check.sh` to your real lint, test and build commands, and runs it. Review and commit the result. If other people commit to that repo, read [Choosing a tier](#choosing-a-tier) first: hooks run code on your machine.

**Use it.** For a small fix, say "Fix X, run check.sh all, then the reviewer agent." For a larger change, say "Run the planner on X", answer its questions, then "Now the writer, then the reviewer."

**Upgrade.** Update your clone of the kit, then run the installer in upgrade mode:

```bash
git -C claude-code-workflow-kit pull
claude-code-workflow-kit/scripts/install.sh --upgrade /path/to/your-repo
```

Then say **Read .claude/kit-upgrade.md** in your repo. Files you changed are never overwritten: the kit's new version arrives beside them as `.kit` files, and that session merges them. What changed in each release: [CHANGELOG.md](CHANGELOG.md).

**Extras.** A fresh install is the core process. Model profiles, a Codex second opinion, a stop-warning hook, review verification and review stats are extras, off until you run `scripts/extras.sh on <name>`; see [Core and extras](#core-and-extras).

Details for each step: [Quick start](#quick-start), [Daily use](#daily-use), [Upgrading the kit](#upgrading-the-kit).

---

## Contents

- [TL;DR](#tldr)
- [What makes it different](#what-makes-it-different)
- [Core and extras](#core-and-extras)
- [Why this exists](#why-this-exists)
- [Principles](#principles)
- [How it works](#how-it-works)
- [Quick start](#quick-start)
- [Choosing a tier](#choosing-a-tier)
- [Cross-model review (Codex)](#cross-model-review-codex)
- [Daily use](#daily-use)
- [Repository layout](#repository-layout)
- [What's in the box](#whats-in-the-box)
- [The agents](#the-agents)
- [Hooks and guardrails](#hooks-and-guardrails)
- [The improvement loop](#the-improvement-loop)
- [Measuring whether it works](#measuring-whether-it-works)
- [Model profiles and cost (vendor measurements)](#model-profiles-and-cost-vendor-measurements)
- [When things go wrong](#when-things-go-wrong)
- [Upgrading the kit](#upgrading-the-kit)
- [Security model and limitations](#security-model-and-limitations)
- [FAQ](#faq)
- [Contributing](#contributing)
- [Credits](#credits)
- [Disclaimer](#disclaimer)
- [License](#license)

## What makes it different

- **One verification contract.** Every agent, hook and CI run checks through `scripts/check.sh`. A check nobody configured exits 2 (`NOT CONFIGURED`) instead of passing, so no report can say "lint passed" for a check that never ran.
- **Decided and open are separate, and dated.** `docs/decisions.md` holds what is decided, with dates; `docs/open.md` holds what is not, each with an owner and a decide-by date. Agents design around open items and list every default they picked.
- **Kill criteria before you start.** With the metrics extra, you commit to a baseline and to the conditions under which you shrink the kit, before the first change goes through it.
- **Codex egress by design.** With the codex extra on, nothing is sent without a gitleaks scan, the model works in a fresh copy of HEAD with no `.git`, and a finding refuses the run. A plan review, before your question round, sends the plan text only. See [Cross-model review](#cross-model-review-codex).

Only *what was actually tested* is checked mechanically: the reviewer re-runs the checks and compares exit codes and test counts. *What the agent decided* and *what still needs a human* are lists the agents write themselves; the reviewer reads them, nothing verifies them.

## Core and extras

The kit is a baseline of good engineering practice for Claude Code, not a replacement for how you already work. A fresh install is the **core**:

- the planner, writer, reviewer and security-auditor agents, and the rule for when each runs;
- `scripts/check.sh` as the single verification entry point, and `scripts/doctor.sh` for kit hygiene;
- the lint hook and the hook that saves each review to `docs/reviews/`;
- `docs/conventions.md`, `docs/decisions.md`, `docs/open.md` and the risk tiers in `docs/rollout.md`.

Everything else is an **extra**, off in a fresh install. An extra is its files: dormant in `.claude/optional/`, active at `.claude/agents/` or `scripts/`. Core scripts call an extra's script only when it is active, so with every extra off the core keeps no state. Start with none for the first two weeks, then add one when you can say what it should fix.

| Extra | Adds | Switch on |
|---|---|---|
| `profiles` | Model and effort per agent, risk-scaled review effort, the writer ladder, a counter that says `same failure N times` | `scripts/extras.sh on profiles`, then `scripts/set-models.sh <lite\|standard\|max>` |
| `codex` | A Codex second opinion on the plan, on High-risk diffs and before a release | `scripts/extras.sh on codex` |
| `stop-warning` | A warning at the end of a turn that names files changed since `check.sh all` last passed | `scripts/extras.sh on stop-warning` |
| `verify-review` | A `### Verification` block on each saved review: are the quoted lines in the files, was every changed file read | `scripts/extras.sh on verify-review` |
| `metrics` | Review-log counts and the agreement rate in `check.sh doctor` | `scripts/extras.sh on metrics` |

`scripts/extras.sh status` shows which are on and warns about a half-enabled one; `off <name>` switches one back. Switching moves files and changes only the kit's own hook entry in `.claude/settings.json` (the rest of the file is kept, re-written with 2-space indentation). Record the choice in `docs/decisions.md`. One section per extra: `docs/rollout.md`, Extras.

**Upgrades keep what each repo had.** A repo installed from 1.5 keeps every extra it ran; one installed from 1.4 gets `profiles` and `metrics` on, `stop-warning` and `verify-review` off, and `codex` as it was. See [Upgrading the kit](#upgrading-the-kit).

## Why this exists

Coding agents fail in predictable ways:

| Failure | What it looks like | How the kit answers it |
|---|---|---|
| **Silent decisions** | The agent quietly picks a timeout, a library, a product behaviour nobody asked for | `docs/open.md` holds what is undecided; agents design around it. The writer must list every default it picked. |
| **Claimed verification** | "All tests pass" when tests were skipped, filtered, or never configured | Unconfigured checks fail by design. The writer pastes real output. The reviewer re-runs the checks and compares. |
| **Context bloat** | A `CLAUDE.md` that grew into a 300-line changelog, loaded on every turn | `CLAUDE.md` is an index capped at 150 lines and checked in CI. Agents without edit tools skip it entirely. |
| **Prompt-encoded linting** | Agents spending expensive tokens on what `grep` could catch | Every rule is either **mechanical** (in `scripts/check.sh`) or **judgment** (for the reviewer). Never both, never neither. |
| **Self-grading** | The model that wrote the code also decides it's fine | A separate reviewer with no edit tools and a fresh context reads the diff *before* the plan. |
| **Process theatre** | Rules nobody maintains, metrics nobody reads | With the metrics extra, metrics and kill criteria are fixed before you start. If the kit doesn't pay for itself, you shrink it. |

## Principles

1. **Mechanical before judgment.** If a tool can check it, it lives in `scripts/check.sh`, never in a prompt.
2. **Decisions have one home.** Decided things go in `docs/decisions.md`; undecided things go in `docs/open.md`, with an ID, an owner and a decide-by date.
3. **Few agents, clear handoffs.** Planner, writer, reviewer, and a security auditor for releases, plus an optional fifth: a Codex second opinion, off by default. Each has a defined input and a defined output.
4. **Honest reports, independently checked.** Nothing is "verified" until a second context has re-run it.
5. **`CLAUDE.md` is an index, not a log.** History belongs in git.
6. **The human is the gate.** Pushes, merges, open items and accepted risks belong to a person.
7. **The kit has to earn its place.** It is measured against your pre-kit baseline and cut back if it loses.

## How it works

```mermaid
flowchart LR
    R[Request] --> S{Size?}
    S -- "1–2 files" --> M[Main session<br/>edits + check.sh all]
    S -- "3+ files or migration" --> P[Planner<br/>no edit tools]
    P -- "questions + blueprint" --> O((Owner<br/>confirms))
    O --> W[Writer<br/>code, tests, check.sh]
    M --> V[Reviewer<br/>no edit tools, re-runs checks]
    W --> V
    V -- "Standards + Spec findings" --> H((Owner<br/>merges))
    H -. "before release" .-> A[Security auditor]
    V -. "High-risk / release, if codex is on" .-> X[Codex reviewer<br/>second opinion]
    P -. "plan text only, if codex is on" .-> X
    W -. "STUCK → next rung (profiles)" .-> W
    V -. "report saved" .-> L[(docs/reviews/)]
    L -. "monthly: doctor" .-> K[New lint rules,<br/>reviewer lists]
```

- **Small changes** skip the planner and writer: the main session edits, runs the checks, and the reviewer looks at the diff. Two contexts instead of four.
- **Larger changes** start with a planner that commits to one approach, names the alternative it rejected, and returns questions with recommended answers for you to confirm in a single reply.
- **Every review** is saved automatically. Once a month, recurring findings become lint rules and recurring false alarms become reviewer exceptions.

### One change, checked twice

The writer reports its own check results; the reviewer doesn't take them on trust.

```mermaid
sequenceDiagram
    autonumber
    actor O as Owner
    participant M as Main session
    participant P as Planner
    participant W as Writer
    participant C as check.sh
    participant R as Reviewer
    O->>M: Request
    M->>P: Brief: change, files, base branch
    P-->>M: Blueprint + questions with recommended answers
    M->>O: One round of questions
    O-->>M: "yes" (or corrections)
    M->>W: Confirmed blueprint
    W->>C: lint, test, build
    C-->>W: Exit codes + output
    W-->>M: Report: pasted check output, defaults it picked
    M->>R: Diff + blueprint + writer's report
    Note over R: Reads the diff before the plan
    R->>C: Re-run lint and test
    C-->>R: Exit codes + test counts
    R-->>M: Claims vs re-run, Standards, Spec, held-back findings
    M->>O: Findings and what was done with each
    Note over O: Owner merges
```

## Quick start

### Requirements

- [Claude Code](https://claude.com/claude-code) v2.1.292 or later (the Agent tool's per-call `effort`, used by the profiles extra's writer ladder and risk-scaled review)
- `git`, `bash`, `python3`
- [`gitleaks`](https://github.com/gitleaks/gitleaks) and [`semgrep`](https://semgrep.dev) for `check.sh security`

```bash
brew install gitleaks
pip install semgrep
```

On Linux (as in `template/.github/workflows/check.yml`), check the download against its published sha256 before unpacking it:

```bash
curl -sSfL -o gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tgz" | sha256sum -c -
sudo tar -xzf gitleaks.tgz -C /usr/local/bin gitleaks
pipx install semgrep==1.184.0
```

semgrep is pinned by version only (PyPI publishes no checksum the workflow checks); gitleaks is pinned by version and sha256.

### Install into a repository

```bash
git clone https://github.com/sam-pop/claude-code-workflow-kit.git
claude-code-workflow-kit/scripts/install.sh /path/to/your-repo
```

The installer **never overwrites**. If a file already exists, the kit's version is written beside it as `<name>.kit` for you to merge. It also writes `.claude/kit-version` and `.claude/kit-manifest` so a later [upgrade](#upgrading-the-kit) can tell an untouched file from a tailored one; commit both.

### Tailor it

```bash
cd /path/to/your-repo
claude
```

Then tell Claude Code:

> Read TAILOR.md and tailor the kit to this repo.

The tailoring session will:

1. Explore the stack, commands, existing conventions and layout.
2. Ask you one round of questions, each with a recommended answer (reply "yes" to accept them all).
3. Fill every placeholder, wire `scripts/check.sh` to your real lint, test and build commands, and remove what your tier doesn't use.
4. Run `scripts/check.sh all` and paste the output into its report, along with follow-ups (lint rules still to write, checks still unconfigured).

Review the result, commit it, and you're running.

> [!IMPORTANT]
> Until `scripts/check.sh` is configured, every check **fails on purpose**. That way nobody can report "lint passed" for a check that never ran.

## Choosing a tier

The tailoring session asks which tier fits. Pick by blast radius, not by repo size.

| Tier | Use when | What's installed |
|---|---|---|
| **Script** | Automations, glue code, one-file tools | `CLAUDE.md`, `check.sh`, short conventions |
| **Solo** | One engineer, low blast radius | Full docs; main session + reviewer; planner and writer for larger changes |
| **Shared** | Client work, money or personal data, a second contributor | Everything; reviewer required before merge; security auditor before releases |
| **Review-only** | Other people write the code; you are the reviewer of record | Reviewer + security auditor in **your own workspace**, with nothing installed in their repo |

> [!WARNING]
> **Review-only repos get no hooks.** Hooks run shell commands on your machine. In a repo others commit to, a PR that edits `.claude/settings.json` or `scripts/` would run its code the next time you open Claude Code there. See [Security model](#security-model-and-limitations).

## Cross-model review (Codex)

Off by default; an extra. `scripts/extras.sh on codex` moves `codex-reviewer` from `.claude/optional/` into `.claude/agents/` (`off` moves it back).

- **When it runs.** On the planner's blueprint, before your question round (`scripts/codex-review.sh plan <file>`: gaps, wrong assumptions, the risk tier, missing tests, a simpler alternative; only the plan text is sent); after the reviewer on High-risk diffs; and once before a release. It is a **second opinion to triage, never a gate**: where it agrees with the Claude reviewer, confidence goes up; what only it raised gets your attention.
- **How.** The agent only relays `scripts/codex-review.sh`: `gpt-6.1-sol` at effort `high` for plans and High-risk diffs, `gpt-6-astra` at `high` for a release (one retry on `gpt-6.1-sol` at `xhigh` if Astra fails). Astra for release is *experimental*: it rests on one secondhand, non-coding benchmark and scored below Sol on the coding one; no code-review benchmark exists for either. Never `ultra`, which fans out to subagents. A ChatGPT Plus subscription gives it a quota separate from your Claude plan.
- **Egress.** Codex works in a fresh copy of HEAD (checked out through a temporary index) plus your uncommitted changes, with no `.git`: git-ignored files and history are kept out of the directory Codex works in; Codex's read-only sandbox limits writes, not reads, so treat anything your user account can read as reachable. gitleaks is required (without it nothing is sent): that copy and the final prompt (which holds the diff, removed lines included) are scanned first for known-pattern secrets, with the `.gitleaks.toml` and `.gitleaksignore` from a commit on the base branch (`origin/<base>`, or the local base without one; never from the change under review); every changed or untracked file is scanned from a copy without its inline `gitleaks:allow` markers, so a new marker never exempts it, even in a file marked `-diff` or `binary`; and a finding **refuses the run**. The scan is pattern-based: an unprefixed password can pass. A tracked `.env`, `*.pem`, `*.p12` or SSH key also refuses the run; symlinks and a `.codex/` directory are removed, and an `AGENTS.md` is named in the report. The reviewer checklist sent to Codex comes from the base, and the run refuses when the change edits `scripts/codex-review.sh` or `codex-reviewer.md` (review that change first); a base branch is taken from `origin/<base>` when that exists, and any other ref (`HEAD~1`, a tag) is used only when it is on the base branch (else exit 2; when your base is not the default branch, set `BASE_BRANCH` in the session environment (the guard allows no `VAR=…` prefix on the command; use the `env` block of `.claude/settings.json`)). Filtered files (git-crypt, transcrypt, LFS) are sent as stored in git: encrypted blobs stay encrypted and LFS files stay pointers, and an untracked file behind a filter driver is named in the report, not sent. Limitation: a base `.gitleaks.toml` with a relative `[extend] path` cannot be resolved, and the run is refused as if secrets were found. The tracked code and the diff leave for OpenAI; on client work, get the client's OK first.
- **Not on Review-only**: the script reviews its own repo, not someone else's PR.

## Daily use

| You want | Say to Claude Code |
|---|---|
| A small fix | "Fix X, run check.sh all, then the reviewer agent." |
| A larger change | "Run the planner on X." → answer its questions → "Now the writer, then the reviewer. Show me the findings." |
| To understand code first | "Explore how X works." |
| To review someone's PR (Review-only) | "Review PR #42 in <repo>." |
| A High-risk change (auth, money, personal data, secrets, migrations, `.claude/` `scripts/` CI) | "Run the planner, the writer, then the reviewer at the High tier (see `docs/rollout.md`, Risk tiers)." With the codex extra on, add "then the codex-reviewer." |
| A release check | "Run codex-reviewer in release mode (if the codex extra is on), then the security auditor, and write the report to docs/security.md." Fill in the `served:` model from `/tasks`. |
| To record a decision | "O7 is decided: <decision>. Record it." |

**What you get back:**

- **From the writer:** the files changed, the tests added and the bug each one catches, the exit code and last lines of every check, and a **Defaults I picked** list of the decisions nobody made. Read that list.
- **From the reviewer:** its own re-run of the checks against the writer's claims, then **Standards** findings (does it follow the rules) and **Spec** findings (does it do what was asked), each with a confidence score, plus a **Considered, below threshold** list so you can see what it held back.

<details>
<summary><strong>Example reviewer report</strong> (illustrative; the Verification block appears with the verify-review extra)</summary>

A sample of the format, on a made-up change that adds a CSV export to a multi-tenant app:

```markdown
## Review: Add invoice CSV export

### Summary
Adds a per-tenant CSV export of invoices. Not merge-ready: one data-isolation
issue and one test that cannot fail.

### Run
tier: High · writer rung: 1 (trigger: none) · requested: opus/xhigh

### Checks
lint: 0 (writer said 0) · test: 142 passed / 0 skipped vs base 138 / 0 · build: 0

### Standards
- [ ] [92] `src/app/api/invoices/export/route.ts:18` — tenant ID is read from the
      query string → take it from the session; as written, any signed-in user
      can export another tenant's invoices.
  > const tenantId = req.nextUrl.searchParams.get("tenant");
- [ ] [88] `src/lib/invoices/export.test.ts:41` — expected CSV is built with the
      same toCsvRow() the code uses (tautological) → assert against a literal
      fixture.
  > const expected = rows.map(toCsvRow).join("\n");

### Spec
- [ ] [86] `src/app/api/invoices/export/route.ts:30` — "Exports are limited to the
      selected date range" → the range is parsed but never applied.
  > const { from, to } = parseRange(req); … db.invoice.findMany({ where: { tenantId } })

### Considered, below threshold
- [70] src/lib/invoices/export.ts:12 — loads all rows into memory; fine at
      current volume, worth streaming above ~50k invoices.

### Not reviewed
Column order and headers against what finance expects.

### Coverage
read: src/app/api/invoices/export/route.ts, src/lib/invoices/export.ts, src/lib/invoices/export.test.ts
not read (reason): none

### Verification
checked: 2026-11-09 14:02 · base: main@1a2b3c4 · scripts/verify-review.sh
status: complete
quotes: 3 verified, 0 unverified, 0 unquoted
coverage: 3 changed files, 0 not in ### Coverage
```

The checks line is the point: the reviewer re-ran the checks and compared them with the writer's claim. A mismatch there is a blocking finding in itself. The `### Verification` block (verify-review extra) is not written by the reviewer: when the report is saved, `scripts/verify-review.sh` looks up each quoted line in the file it cites and checks that every changed file is named on the `read:` line of `### Coverage`. It checks form, not judgment: a quote that exists, a path that was listed. A quote it cannot find means the finding may describe code that is not there, so you read that one first.

</details>

Full guide: [template/HOW-TO-USE.md](template/HOW-TO-USE.md).

## Repository layout

Only `template/` is installed. `scripts/install.sh` copies the files under `template/` into your repository at the same paths, and nothing else: not this README, the changelog, the research notes or this repo's own tests.

The rest of the root is how this repo maintains itself with the kit, in the open. The root is an ordinary install of `template/`, tailored to the kit's own stack (bash, python3, Markdown), so the kit runs its own workflow and its own checks on every change. When a file under `template/` changes, `scripts/install.sh --upgrade .` brings the root copy up to date, and a test fails if the two drift apart unexpectedly. Maintainer working state (saved review reports and local notes) is kept locally and is not part of the repository.

## What's in the box

```text
template/                      # Everything here is installed, at the same paths; nothing else is
├── CLAUDE.md                  # Index template: stack, commands, layout, rules, workflow
├── TAILOR.md                  # Instructions for the session that adapts the kit (deleted after)
├── HOW-TO-USE.md              # Operator guide: daily commands, extras, upkeep, ownership
├── docs/
│   ├── conventions.md         # Rules and anti-patterns, each marked mechanical or judgment
│   ├── decisions.md           # What's decided, dated
│   ├── open.md                # What isn't, with owner and decide-by date
│   ├── rollout.md             # Tiers, risk tiers, one section per extra, cadence
│   └── reviews/README.md      # Review log; reports are written here automatically
├── .claude/
│   ├── settings.json          # Deny rules, hooks, sequential agents
│   ├── agents/
│   │   ├── planner.md
│   │   ├── writer.md
│   │   ├── reviewer.md
│   │   └── security-auditor.md
│   └── optional/              # The extras, dormant: extras.sh on <name> moves a file to its active path
│       ├── codex-reviewer.md  # codex: -> .claude/agents/
│       ├── set-models.sh      # profiles: model and effort per agent -> scripts/
│       ├── stuck-detect.sh    # profiles: counts identical check failures -> scripts/
│       ├── check-stamp.sh     # stop-warning: warns at Stop when files changed since check.sh all passed -> scripts/
│       ├── verify-review.sh   # verify-review: checks a saved review's quotes and coverage -> scripts/
│       └── review-stats.sh    # metrics: review-log counts for doctor -> scripts/
├── scripts/
│   ├── check.sh               # The single verification entry point
│   ├── extras.sh              # Switches extras on and off, reports which are on
│   ├── doctor.sh              # Kit hygiene checks
│   ├── lint-hook.sh           # Shows lint failures to Claude after each edit
│   ├── capture-review.sh      # Saves reviewer, auditor, Codex and STUCK reports
│   └── codex-review.sh        # Codex second opinion + the agent's Bash guard (used by the codex extra)
└── .github/
    ├── workflows/check.yml    # CI runs check.sh all (actions pinned by SHA, gitleaks checksum-verified)
    └── dependabot.yml         # Keeps the pinned actions current
```

The installer adds `.claude/kit-version` and `.claude/kit-manifest` (the version installed and the sha256 of each file as installed). The root of this repo holds `scripts/install.sh`, `scripts/kit-upgrade-prompt.md` (the merge-session prompt `--upgrade` embeds), the changelog, the research notes under `docs/research/` and the kit's own tests; none of these are installed.

### `scripts/check.sh`

Everything verifies through one script, so agents, hooks and CI always check the same thing.

| Command | Does |
|---|---|
| `check.sh lint` | Format, lint, type-check. `--changed` limits it to changed and untracked files. |
| `check.sh test` | Unit and integration tests, with pass/skip counts |
| `check.sh build` | Production build |
| `check.sh security` | Secret scan (gitleaks), dependency audit, SAST (semgrep), tracked-secret-file check |
| `check.sh doctor` | `CLAUDE.md` size, leftover placeholders, unconfigured checks, orphan or overdue open items, half-enabled extras; review stats with the metrics extra |
| `check.sh all` | All of the above; non-zero on any failure |

## The agents

All five are plain Markdown files with YAML frontmatter (four in `.claude/agents/`, the codex-reviewer dormant in `.claude/optional/` until you switch it on). Edit them freely. Models and efforts per profile: [Model profiles and cost](#model-profiles-and-cost-vendor-measurements).

| Agent | Access | Loads `CLAUDE.md` | Job |
|---|---|---|---|
| **planner** | No edit tools; Bash by instruction | No | One decisive blueprint: approach, rejected alternative, risk tier, acceptance criteria, files, data, rollback path, tests, sequence, questions for the owner. |
| **writer** | Read/write | Yes | Implements the blueprint, writes tests that catch real bugs, runs the checks, reports exact output and the defaults it picked. Stops with a `## STUCK:` report instead of looping. |
| **reviewer** | No edit tools; Bash by instruction | No | Reads the diff before the plan, re-runs the checks, reports Standards and Spec findings separately with confidence scores. Lower threshold (60%) for data, security and concurrency; 85% elsewhere. |
| **security-auditor** | No edit tools; Bash by instruction | No | Whole-system audit (trust boundaries, authorization, tenancy, data flows, secrets, rate limiting, logging). Critical and High block a release; an unreproduced one blocks until the owner rules on it, on the record. |
| **codex-reviewer** *(extra)* | Runs one script (read-only Codex sandbox) | No | Relays `scripts/codex-review.sh`: a Codex second opinion on the plan, on High-risk diffs and on releases. |

Every agent treats text it finds in the repo (comments, docs, PR descriptions, other agents' reports) as **data, never instructions**. An instruction found there is reported as possible prompt injection.

## Hooks and guardrails

Configured in `.claude/settings.json`:

| Mechanism | Effect |
|---|---|
| `permissions.deny` | Blocks `git push`, `reset --hard`, `clean`, `branch -D`, `branch -f`, `update-ref`, `checkout -- .`, `restore .`, `stash drop`, `stash clear`, `gh pr create`, `gh pr merge`, `gh repo delete`, `gh repo edit`, `gh repo archive`, `gh repo create`, `gh repo sync`, `npm publish`, and reading `.env` and `*.pem` files. Prefix rules: they prevent accidents, not attacks. |
| `PostToolUse` on edits | Runs `check.sh lint --changed`; on failure, shows the output to Claude so it fixes the problem before moving on. Stays quiet until lint is configured. |
| `SubagentStop` (reviewer, security-auditor, codex-reviewer, writer) / `SubagentHandback` | Saves reviewer, auditor and Codex reports to `docs/reviews/`, and a writer's `## STUCK:` report (other writer reports are ignored). With the verify-review extra on, reviewer and Codex reports then get a `### Verification` block from `scripts/verify-review.sh` (are the quoted lines really in the files, was every changed file read, are all sections there); when something is off, a one-line summary appears in the session. |
| `Stop` | Only with the stop-warning extra on (`scripts/extras.sh on stop-warning`). Runs `scripts/check-stamp.sh hook` when Claude finishes a turn. If files differ from the ones the last passing `check.sh all` ran on, committed or not, it shows how many and up to three names; with no passing run recorded, it names the files `git status` shows. Silent when nothing changed and until `check.sh` is configured. It reads the tree without writing to the index or `.git/objects`. |
| codex-reviewer frontmatter `PreToolUse` (codex extra) | Allows Bash only for `scripts/codex-review.sh plan <file>` (a relative `*.md` path inside the repo; the script also refuses git-ignored paths, plan paths through a symlink and secrets-file names) and `high\|release [ref]`; the script itself refuses when the change edits the review tooling. Tested by script, not yet observed firing in a live session. |
| `CLAUDE_CODE_FORK_SUBAGENT=0` | Agents run in sequence, and Claude waits for each report |

## The improvement loop

The kit is meant to get sharper with use, under your control:

```mermaid
flowchart LR
    A[Reviewer or auditor<br/>report] -->|hook saves it| B[(docs/reviews/)]
    B --> C[You mark each finding:<br/>fixed · dismissed · deferred]
    C --> D[check.sh doctor<br/>monthly]
    D -->|same finding 3+ times| E[New lint rule<br/>row becomes mechanical]
    D -->|same dismissal 2+ times| F[Reviewer<br/>false-positive entry]
    E --> G[Fewer, sharper findings]
    F --> G
    G -.-> A
```

1. **Capture.** Each review is saved to `docs/reviews/`.
2. **Mark.** You tick findings you fixed, add `dismissed: <reason>` to false alarms, or attach an open-item ID to deferred ones.
3. **Measure.** With the metrics extra on, `check.sh doctor` reports the agreement rate and recurring dismissal reasons.
4. **Promote**, monthly, by fixed thresholds:
   - A finding seen **3+ times** becomes a lint rule, and its conventions row becomes *mechanical*.
   - A dismissal seen **2+ times** becomes an entry in the reviewer's false-positives list.

Thresholds are written down in advance so the loop can't drift, and you approve every rule change. The numbers themselves (3+, 2+, and the 60%/85% confidence, 40% agreement and 95% honesty thresholds) are starting points to tune, not evidence.

## Measuring whether it works

With the metrics extra, `docs/rollout.md` (Extras, metrics) commits you to three metrics **before** you start, measured against a two-week baseline of your current workflow:

| Metric | What it tells you |
|---|---|
| **Cost per merged change** | Tokens or dollars plus your own minutes, request to merge. Must be at or below baseline within 60 days. |
| **Reviewer precision and misses** | Agreement rate (`check.sh doctor` prints it), plus escaped defects classed as *reviewer flagged*, *reviewer silent* or *outside scope* |
| **Verification honesty** | Share of writer reports whose claimed results match the reviewer's re-run. Below 95%, the writer's self-report can't be trusted. |

It also sets **kill criteria**. If cost per change is above baseline after 60 days, or the reviewer's agreement rate stays under 40%, you shrink the kit rather than defend it.

## Model profiles and cost (vendor measurements)

The `profiles` extra (`scripts/extras.sh on profiles`) sets the model and effort of each agent. Tiers decide which agents run; profiles decide what they run on. The figures on this page come from the model vendors' own published measurements, not from measuring this kit: Anthropic's are internal, directional, on a SWE-bench Pro subset, at API list prices (†); OpenAI's are API list prices, uncached (‡). Subscription accounting is unpublished. Sources and caveats: [the research report](docs/research/coding-agent-model-effort-combos.md).

```bash
scripts/set-models.sh standard   # or: lite | max
```

| Profile | Planner | Writer | Reviewer | Security auditor | Best for |
|---|---|---|---|---|---|
| **lite** | Sonnet / high | Sonnet / high | Opus / medium | Opus / high | Pro ($20) plans. Sonnet plans and writes; Opus reviews and audits. |
| **standard** *(default)* | Opus / high | Sonnet / high | Opus / high | Opus / xhigh | Any plan with Opus access. Sonnet writes, Opus reviews. |
| **max** | Opus / high | Opus / medium | Fable / high | Fable / high | *Experimental.* Plans or budgets that include Fable, used to review and audit what Opus wrote. No comparative Fable-vs-Opus data exists for reviewing or auditing, so this is a hypothesis to test, not a measured gain. |

**The model that wrote the code never reviews it**, so writer and reviewer are on different models in every profile; `check.sh doctor` warns when they are not. The reviewer never runs below `medium`. Review effort scales with risk (Low `medium`, Medium the reviewer's own effort, High `xhigh`, or `high` on a Fable reviewer; `xhigh` is a hypothesis, since no review-effort ablation exists for Claude). The writer ladder raises effort only and never changes the model, so an escalated writer cannot land on the reviewer's model: lite and standard go sonnet/high, then sonnet/xhigh, then stop; max goes opus/medium, then opus/high, then opus/xhigh, then stop. Both are defined in `docs/rollout.md`, Extras, profiles. Never set Sonnet below `high`: at `medium` it dropped about 7 points on SWE-bench Pro and about 15 on Anthropic's internal agentic-coding benchmark.

Agents use model aliases (`sonnet`, `opus`, `fable`), so they move to new versions automatically. Aliases differ by provider: on Amazon Bedrock, Google Vertex or Microsoft Foundry an alias can point to an older model, and an effort level the model lacks falls back silently. `check.sh doctor` warns when one of those providers is selected.

> [!NOTE]
> On Pro and standard Team plans, Fable bills **usage credits** from the first request. Interactive sessions ask before they do; `claude -p` and Agent SDK runs **do not**, and background or Remote sessions drop the turn after 5 minutes waiting for consent. Set a cap in `/usage-credits` before running **max** in automation.

| Comparison | Result |
|---|---|
| Opus 5.5 `medium` (the **max** writer) vs Fable 5.1 `high` | 92.8% solved at $0.22 per solved task† vs 92.3% at $1.19† |
| Anthropic's 2-rung, effort-only retry graded by hidden tests (`medium`, failures re-run at `high`) vs fixed `high` | 96.0–97.1% at ~$0.24 per task† vs 94.8–95.8% at $0.29 per task† |
| Sonnet 5.5 `high` (the **lite** and **standard** writer) vs Opus 5.5 `medium` (the **max** writer) | 87.6% at $0.11 per solved task† vs 92.8% at $0.22† |
| Codex review of 100K input and 5K output tokens (a floor: reasoning tokens bill as output, and a real review uses several times 5K) | `gpt-6.1-sol` ≈ $0.25‡; `gpt-6-astra` ≈ $1.25‡ |

Rows 1 and 3 are per solved task, row 2 per task. In row 2 the gain comes from re-running failures (re-running at `high` after `high` also beats fixed `high`); starting at `medium` is the smaller, cost-only saving. The kit's ladder, triggered by self-written tests and reviewer findings, is untested; switching models mid-ladder was never measured, which is why it raises effort only. How a subscription weights each model against its quota is unpublished, so measure with `/usage` (`docs/rollout.md`, Extras, metrics).

## When things go wrong

- **A writer reports `## STUCK:`** (`same failure N times` in the check output, the same file edited four times with no change in the test result, or a check still failing after its own repairs). The report is saved to `docs/reviews/` and, with the profiles extra on, the main session re-spawns the work one effort step up. The ladder is in `docs/rollout.md`, Extras, profiles.
- **The writer's report and the reviewer's re-run disagree.** The re-run is the ground truth, and the disagreement is itself an escalation trigger.
- **Checks fail right after tailoring.** An unconfigured check exits 2 (`NOT CONFIGURED`) by design: wire it in `scripts/check.sh`. `check.sh security` fails while gitleaks or semgrep is missing. `check.sh doctor` prints what is wrong, one line each. The lint hook stays quiet until lint is configured, so silence there is not a pass.

## Upgrading the kit

Three steps: pull the kit, run the installer in upgrade mode, then open Claude Code in your repo and say **Read .claude/kit-upgrade.md**.

```bash
git -C claude-code-workflow-kit pull
claude-code-workflow-kit/scripts/install.sh --upgrade --dry-run /path/to/your-repo   # optional: classify, write nothing
claude-code-workflow-kit/scripts/install.sh --upgrade /path/to/your-repo
```

The installer records the version and each file's hash in `.claude/kit-version` and `.claude/kit-manifest` (commit both). On upgrade every kit file lands in one class:

| Class | Meaning |
|---|---|
| **replaced** | Unmodified since install: updated in place |
| **current** | Already matches the kit |
| **tailored** | You changed it: the kit's version is saved beside it as `<name>.kit` |
| **tailored (kit unchanged)** | You changed it, the kit did not: kept as is, no `.kit` |
| **new** | Added by this version: installed |
| **skipped** | You deleted it earlier: not re-added |
| **retired** | No longer in the kit: listed, never deleted (1.6 retires `handoff.md` and `docs/glossary.md`; yours stay as your own files) |
| **never re-added** | `TAILOR.md`, `HOW-TO-USE.md` and `README.md` (the README is never installed) |

Extras follow the repo: a file of an extra that is on is updated in place, one you switched off stays off, and the installer finishes with `scripts/extras.sh sync` so the move leaves no extra half-enabled. A tailored `scripts/check.sh` that lacks a line an extra needs stays half-enabled until you merge it, and `scripts/extras.sh status` (shown by `check.sh doctor`) warns. A pre-1.4 repo has no manifest, so every existing file that differs from the kit becomes `.kit` once; the manifest is written at the end and later upgrades are quiet. Then open Claude Code in the repo and say **Read .claude/kit-upgrade.md**: that file starts with the merge prompt, then the classification and the CHANGELOG sections since your version. The session merges each `.kit` file, deletes new files your tier does not use, re-applies your extras and model profile, runs `scripts/check.sh all`, records the upgrade in `docs/decisions.md` and deletes `.claude/kit-upgrade.md`. `check.sh doctor` warns about unmerged `.kit` files and while `.claude/kit-upgrade.md` is present. `--upgrade` refuses to run while a previous merge is unfinished (`.claude/kit-upgrade.md` or a `.kit` file still present); `--force` runs it anyway, keeps files with a `.kit` sibling as tailored and keeps the earlier starting version. What changed per version: [CHANGELOG.md](CHANGELOG.md).

## Security model and limitations

Be clear about what this does and doesn't protect against.

- **Deny rules prevent accidents, not attacks.** They match command prefixes; a reworded command such as `git -C . push` can slip past them. They are not a sandbox.
- **Hooks execute repository code.** Anything in `.claude/settings.json` or `scripts/` runs on your machine. Only install the kit in repos whose committers you trust, use the Review-only tier otherwise, and review changes to those paths before opening Claude Code on a branch.
- **The security auditor is a first pass, not a pen test.** It makes routine review cheap and consistent; client-facing systems still need human security review. Opus 5.5 reroutes most security work to Opus 4.8, so the audit report records the served model (from `/tasks`) instead of assuming it.
- **Fable bills credits.** On Pro and standard Team plans from the first request; `claude -p` does so without asking. Set a cap in `/usage-credits`.
- **Codex egress.** Git-ignored files and history are kept out of the directory Codex works in; Codex's read-only sandbox limits writes, not reads, so treat anything your user account can read as reachable. Tracked code and the diff leave for OpenAI; on client work, get the client's consent. Cross-model review (the codex extra) is not available on Review-only.
- **Confidence scores are the model's own estimate.** The "below threshold" list and the escaped-defect metric exist so you can tune them from evidence.
- **Not yet battle-tested across many stacks.** Expect your first tailoring to find something to fix, and please send it back.

## FAQ

<details>
<summary><strong>Does this work with models other than Claude?</strong></summary>

The agent files and hooks use Claude Code's formats, but a second opinion from another model family is built in: `scripts/extras.sh on codex` turns on an optional Codex reviewer. An `AGENTS.md` for other tools is under consideration. The process (decisions vs open items, mechanical vs judgment rules, `check.sh` as the single entry point) is tool-agnostic and ports easily.
</details>

<details>
<summary><strong>Isn't five agents expensive?</strong></summary>

Small changes use two contexts (main session + reviewer). Agents without edit tools skip `CLAUDE.md` and read only what they need. The planner and writer only run for changes touching three or more files. The fifth agent, the Codex reviewer, is off by default and runs only on the plan, on High-risk diffs and before releases. And the cost metric above exists so you can check rather than guess.
</details>

<details>
<summary><strong>Why does the reviewer run at higher effort than the writer?</strong></summary>

Review is bounded: it reads one diff and emits findings once, while the writer iterates. Its effort is never `low` (Opus at `low` scored 34 points below `medium` at finding bugs) and rises to `xhigh` on High-risk changes (`high` when the reviewer runs on Fable), which is a hypothesis: no review-effort ablation exists for Claude. It also reviews in a fresh context and on a different model from the writer (the shipped agent files already differ, and `check.sh doctor` warns if they match), so the model that wrote the code is not grading it. `docs/rollout.md`, Extras, metrics, sets the measures that tell you whether the settings pay off on your own diffs.
</details>

<details>
<summary><strong>Can I use it on a repo that already has a CLAUDE.md?</strong></summary>

Yes. The installer keeps your file and writes the kit's version as `CLAUDE.md.kit` (upgrades work the same way); the tailoring session merges your existing rules in rather than replacing them.
</details>

<details>
<summary><strong>What if I stop maintaining the review log?</strong></summary>

Then the improvement loop stops, and the kill criteria tell you to remove it. The checks, agents and guardrails keep working without it.
</details>

## Contributing

Issues and pull requests are welcome. Especially useful:

- Tailored `docs/conventions.md` and reviewer lists for specific stacks (Next.js, Django, Rails, Swift, Go, …)
- `check.sh` recipes for stacks the comments don't cover
- Reports from real tailoring runs: what `TAILOR.md` got wrong

Please keep changes small and explain the failure mode a change prevents. How to set up, test and sync a change: [CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

The question format, the two-axis (Standards / Spec) review, the test anti-patterns and the agent-writing guidance are adapted from [**mattpocock/skills**](https://github.com/mattpocock/skills) (MIT). That plugin makes a good companion to this kit; install it per [the repo's instructions](https://github.com/mattpocock/skills).

## Disclaimer

Claude Kit is an independent community project. It is not affiliated with, endorsed by, or supported by Anthropic. "Claude" and "Claude Code" are trademarks of Anthropic.

## License

[MIT](LICENSE) © 2026 Sam P.
