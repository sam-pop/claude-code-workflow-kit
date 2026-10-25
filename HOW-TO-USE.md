# How to use the Claude Kit

## One-time: keep the kit in its own repo

```bash
git init claude-kit && cd claude-kit
# unzip the kit contents here
git add . && git commit -m "Claude kit v1"
```

Every repo you tailor will teach you something; fold it back here so the next repo starts from the corrected version.

## Per repo: install and tailor (about 30 minutes)

1. **Install.** From the kit folder:
   ```bash
   scripts/install.sh /path/to/your-repo
   ```
   Nothing you already have is overwritten. If a file existed, the kit's version is saved beside it as `*.kit` for you to merge by hand.

2. **Tailor.** Open Claude Code in the repo and say:
   > Read TAILOR.md and tailor the kit to this repo.

   It explores the repo, asks you one batch of questions (tier, reviewer model, rules you want, anything intentionally odd), fills every placeholder, writes the lint rules, deletes what doesn't apply, runs `scripts/check.sh all`, and reports.

3. **Review and commit.** Read `CLAUDE.md`, `docs/conventions.md` and the agent files once as a stranger would. Fix anything wrong. Commit. Delete `TAILOR.md`, `HOW-TO-USE.md`, `README.md` (the kit's) and `scripts/install.sh` from the repo if the tailoring session didn't.

4. **Install the tools `check.sh` expects** (once per machine):
   ```bash
   brew install gitleaks        # secret scan
   pip install semgrep          # SAST
   # plus the stack's own linter, formatter and audit tool
   ```

## Once per machine: install the companion skills

The kit holds roles (planner, writer, reviewer, auditor). Matt Pocock's skills hold verbs, and the two fit together. Install once; the plugin updates itself:

```bash
claude plugin install mattpocock-skills@claude-plugins-official
```

The ones that matter here, and when:

| Skill | Use it when |
|---|---|
| `/grill-me` | Before any plan over an hour. Relentless questions with a recommended answer each; replaces guessing at what you want. The planner and `TAILOR.md` use its format. |
| `/grill-with-docs` | Same, but it builds `docs/glossary.md` and records ADRs as you go. Use on a repo's first big feature. |
| `/retro` | End of a session that went badly or took too long. Proposes environment fixes (a lint rule, a pointer, a guardrail) rather than blaming the model. This is the per-session half of the improvement loop; the monthly `doctor` pass is the other half. |
| `/handoff` | Before closing a session someone else will continue. |
| `/to-questionnaire` | A decision in `docs/open.md` that belongs to a product owner: turn it into a questionnaire they can answer without you. |
| `/wizard` | Any setup only a human can do (CI secrets, a vendor dashboard, installing gitleaks). |
| `writing-for-agents` | Whenever you edit an agent file or `CLAUDE.md`. Model-invoked; it loads itself. |

Skip the rest for now: `to-spec`, `to-tickets`, `triage` and `wayfinder` assume an issue-tracker workflow you have not adopted, and `improve-codebase-architecture` is an occasional survey, not a routine.

## Daily: working in a tailored repo

Start a session. Claude reads `CLAUDE.md` automatically and `handoff.md` first. Then:

| You want | Say |
|---|---|
| A small, obvious fix | "Fix X. Writer, then reviewer." |
| A feature or anything over an hour | "Plan X." → read the blueprint → "Implement it. Writer, then reviewer, and give me the findings." |
| To understand existing code first | "Explore how X works" (built-in Explore agent), then plan. |
| A security-sensitive change (auth, payments, tenancy, input, export) | Add "then security-auditor" after the reviewer. |
| A release (Shared tier) | "Run the security auditor and write the report to docs/security.md." |
| To end the session | "Update handoff.md." The Stop hook reminds you if you forget. |
| To decide an open item | "O7 is decided: <decision>. Record it." Claude moves it from `open.md` to `decisions.md`. |

What you should expect back from every writer run: a list of files, the tests and the bug each catches, and `check.sh` results per sub-command or the word **unverified** with a reason. From every reviewer run: findings with a confidence number, nothing under 85%.

## What you own

- **Merges.** Nothing merges without you reading the reviewer's findings and what was done about each.
- **Open items.** Agents never decide them. If one shows up resolved in code without a decision line, that's a bug in the process.
- **The reviewer's two lists** (`Subtle violations`, `False positives`). Add to them when you've corrected the same thing twice. Prune quarterly.
- **Accepted risks.** A Critical or High security finding you choose not to fix goes in `docs/decisions.md` with the date and reason.

## After every review

Reports save themselves to `docs/reviews/`. Mark each finding in the saved file: tick it when fixed, `dismissed: <reason>` when it isn't real (same wording each time), or leave it with an O-id when deferred. Details in `docs/reviews/README.md`.

## Monthly, ten minutes

- `scripts/check.sh doctor` — fails on a bloated `CLAUDE.md`, leftover placeholders or orphan O-ids; prints review stats and recurring dismissals.
- Finding recurring 3+ times → lint rule, conventions row becomes **mechanical**. Dismissal recurring 2+ times → reviewer's false-positives list.
- `diff -r` the repo's `.claude/` and `scripts/` against the kit; push improvements in either direction.

## Tiers in one line each

- **Script:** `CLAUDE.md`, `check.sh`, short conventions. No agents.
- **Solo:** full docs, writer + reviewer (Opus), planner for big work, `handoff.md` git-ignored.
- **Shared:** everything, reviewer on Fable, security auditor, `handoff.md` committed.
- **Review-only:** others write the code; reviewer + security auditor on their PRs, nothing else. "Review PR #42" is the whole workflow.

Before the first repo, read the "Pre-committed tests of the kit itself" section of `docs/rollout.md` and accept the kill criteria. The kit has to earn its place.

Full detail in `docs/rollout.md`.
