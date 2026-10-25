# How to use the Claude Kit

## Before the first repo

Read "Pre-committed tests of the kit itself" in `docs/rollout.md` and accept the kill criteria. Then spend two weeks logging your current baseline (cost and your minutes per merged change) so the kit has something to beat.

## Once per machine

```bash
brew install gitleaks      # secret scan (check.sh security fails without it)
pip install semgrep        # SAST
```

Optional companion skills (see the bottom of this file):

```bash
claude plugin install mattpocock-skills@claude-plugins-official
```

## Per repo: install and tailor (about 30 minutes)

1. **Install.**
   ```bash
   /path/to/claude-kit/scripts/install.sh /path/to/your-repo
   ```
   Nothing is overwritten. Where a file already existed, the kit's version lands beside it as `*.kit` to merge by hand.

   **Review-only** (other people commit to the repo): install into a separate review workspace instead, never into their repo. Hooks run shell commands on your machine, and a PR could change them. `TAILOR.md` sets this up.

2. **Tailor.** Open Claude Code in the repo and say:
   > Read TAILOR.md and tailor the kit to this repo.

   It explores the repo, asks one round of questions with recommended answers, fills placeholders, wires `check.sh` to the real commands, deletes what doesn't apply, runs `scripts/check.sh all` and pastes the output. Until `check.sh` is configured, every check fails on purpose, so nobody can report a pass that never ran.

3. **Review and commit.** Read `CLAUDE.md`, `docs/conventions.md` and the agent files as a stranger would. Commit. The report's **Follow-ups** list the lint rules still to write; schedule them like any other task.

## Daily

| You want | Say |
|---|---|
| A small fix (1–2 files) | "Fix X, run check.sh all, then the reviewer agent." |
| A larger change | "Run the planner on X." Answer its questions (reply "yes" to accept all recommendations). "Now the writer, then the reviewer, and show me the findings." |
| To understand code first | "Explore how X works." (built-in Explore agent) |
| A Review-only PR | In the review workspace: "Review PR #42 in <repo>." |
| A release (Shared, Review-only) | "Run the security auditor and write the report to docs/security.md." |
| To end the session | "Update handoff.md." Nothing does this for you; make it the last thing you ask. |
| To decide an open item | "O7 is decided: <decision>. Record it." |

What comes back:

- **Writer:** files, tests and the bug each catches, each check's exit code with the last lines of its output pasted, and **Defaults I picked**, which are decisions nobody made. Read that list.
- **Reviewer:** a re-run of the checks compared against the writer's claims, then Standards and Spec findings with confidence numbers, and a **Considered, below threshold** list so you can see what it held back.

Agents run one at a time in the foreground; the kit turns off fork mode so Claude waits for each.

## After every review

Reports save themselves to `docs/reviews/` (from the reviewer's `## Review:` heading). Mark each finding in the saved file: tick when fixed; `dismissed: <reason>` when it isn't real (same wording each time); or add an O-id when deferred. If reviews run but the folder stays empty, the capture hook is broken: fix that before trusting any metric.

## Monthly, ten minutes

- `scripts/check.sh doctor`: fails on a bloated `CLAUDE.md`, leftover kit placeholders, unconfigured checks, orphan O-ids, or more than 15 open items; warns on overdue items; prints the agreement rate and recurring dismissals.
- A finding recurring 3+ times becomes a lint rule, and its conventions row becomes **mechanical**. A dismissal recurring 2+ times goes into the reviewer's false-positives list.
- Add a line to the kit repo's `METRICS.md`: cost per merged change, agreement rate, escaped defects (flagged / silent / outside scope), verification honesty.
- `diff -r` the repo's `.claude/` and `scripts/` against the kit and push improvements both ways.

## What you own

- **Pushes and merges.** The kit's deny rules stop agents from pushing, resetting or cleaning. They prevent accidents but aren't a sandbox: a reworded command can slip past them.
- **Open items** and **accepted risks** (a Critical or High security finding you choose not to fix goes in `docs/decisions.md` with a date and reason).
- **The reviewer's two lists.** Add what you have corrected twice; prune quarterly.

## Companion skills (optional)

[mattpocock/skills](https://github.com/mattpocock/skills) installs with the command above (per that repo's README). The kit works without it. Worth knowing:

| Skill | When |
|---|---|
| `/grill-me` | Before a change you haven't fully thought through. Same question format the planner uses. |
| `/retro` | After a session that went badly. Proposes fixes to the environment (a check, a pointer) rather than the prompt. |
| `/to-questionnaire` | An open item a non-technical owner must decide. |
| `/handoff` | Handing a session to someone else. |
| `/wizard` | A setup step only a human can do (CI secrets, a vendor dashboard). |

Full detail on tiers, cadence and metrics: `docs/rollout.md`.
