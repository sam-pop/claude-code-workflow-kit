# How to use the Claude Kit

## Before the first repo

Read "Pre-committed tests of the kit itself" in `docs/rollout.md` and accept the kill criteria. Then spend two weeks logging your current baseline (cost and your minutes per merged change) so the kit has something to beat.

## Once per machine

```bash
brew install gitleaks      # secret scan (check.sh security fails without it)
pip install semgrep        # SAST
```

On Linux, the same two tools (as in `.github/workflows/check.yml`), with the gitleaks download checked against its sha256 before it is unpacked:

```bash
curl -sSfL -o gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  gitleaks.tgz" | sha256sum -c -
sudo tar -xzf gitleaks.tgz -C /usr/local/bin gitleaks
pipx install semgrep==1.184.0
```

Optional: the [Codex CLI](https://learn.chatgpt.com/docs/non-interactive-mode), only if you turn on cross-model review (see Models).

Optional companion skills: install per [that repo's README](https://github.com/mattpocock/skills) (see the bottom of this file).

## Per repo: install and tailor (about 30 minutes)

1. **Install.**

   ```bash
   /path/to/claude-code-workflow-kit/scripts/install.sh /path/to/your-repo
   ```

   Nothing is overwritten. Where a file already existed, the kit's version lands beside it as `*.kit` to merge by hand. The install also writes `.claude/kit-version` and `.claude/kit-manifest` (commit both); they are what lets `--upgrade` later tell an untouched file from a tailored one.

   **Review-only** (other people commit to the repo): install into a separate review workspace instead, never into their repo. Hooks run shell commands on your machine, and a PR could change them. `TAILOR.md` sets this up.

2. **Tailor.** Open Claude Code in the repo and say:
   > Read TAILOR.md and tailor the kit to this repo.

   It explores the repo, asks one round of questions with recommended answers, fills placeholders, wires `check.sh` to the real commands, deletes what doesn't apply, runs `scripts/check.sh all` and pastes the output. Until `check.sh` is configured, every check fails on purpose, so nobody can report a pass that never ran.

3. **Review and commit.** Read `CLAUDE.md`, `docs/conventions.md` and the agent files as a stranger would. Commit. The report's **Follow-ups** list the lint rules still to write; schedule them like any other task.

## Models

The kit ships on the **standard** profile. Switch with `scripts/set-models.sh <lite|standard|max> [--cross]`; each cell is model/effort.

| Profile | planner | writer | reviewer | security-auditor |
|---|---|---|---|---|
| **lite** (Pro $20 plans) | sonnet/high | sonnet/high | opus/medium | opus/high |
| **standard** (default) | opus/high | sonnet/high | opus/high | opus/xhigh |
| **max** (plans with Fable; experimental) | opus/high | opus/medium | fable/high | fable/high |

`--cross` also turns on the codex-reviewer, a Codex second opinion on High-risk diffs and before a release (off by default). It sends those diffs to OpenAI; on client work get the client's OK first. It needs gitleaks (it refuses to send anything without it) and refuses when the change edits its own script or agent file; the reviewer checklist it sends comes from the base branch, not the change. It is not available on Review-only (the script reviews its own repo, not someone else's PR). Fable bills usage credits on Pro and standard Team plans from the first request, and `claude -p` does so without asking; set a cap in `/usage-credits`. Review effort scales with risk and the writer escalates when stuck: both are defined in `CLAUDE.md` (Workflow), which needs Claude Code v2.1.292 or later. Details and sources: `docs/rollout.md`, Model profiles, and [the research report](https://github.com/sam-pop/claude-code-workflow-kit/blob/main/docs/research/coding-agent-model-effort-combos.md).

## Daily

| You want | Say |
|---|---|
| A small fix (1–2 files) | "Fix X, run check.sh all, then the reviewer agent." |
| A larger change | "Run the planner on X." Answer its questions (reply "yes" to accept all recommendations). "Now the writer, then the reviewer, and show me the findings." |
| To understand code first | "Explore how X works." (built-in Explore agent) |
| A Review-only PR | In the review workspace: "Review PR #42 in <repo>." |
| A High-risk change (auth, money, personal data, secrets, migrations, `.claude/` `scripts/` CI) | "Run the planner, the writer, then the reviewer at the High tier (see CLAUDE.md)." If cross-model review is on, add: "then the codex-reviewer." |
| A release (Shared, Review-only) | "Run codex-reviewer in release mode (if on), then the security auditor, and write the report to docs/security.md." After the audit, fill in the `served:` model from `/tasks`. |
| To end the session | "Update handoff.md." Nothing does this for you; make it the last thing you ask. |
| To decide an open item | "O7 is decided: <decision>. Record it." |

What comes back:

- **Writer:** files, tests and the bug each catches, each check's exit code with the last lines of its output pasted, and **Defaults I picked**, which are decisions nobody made. Read that list.
- **Reviewer:** a re-run of the checks compared against the writer's claims, then Standards and Spec findings with confidence numbers, and a **Considered, below threshold** list so you can see what it held back.

Agents run one at a time in the foreground; the kit turns off fork mode so Claude waits for each.

When Claude finishes a turn after files changed since the last passing `scripts/check.sh all`, a one-line warning names those files ("scripts/check.sh all has not passed since these changes: …"). It is a reminder, not a block: run `scripts/check.sh all` (or ask Claude to) before you trust a "checks passed" claim or commit. Nothing is shown while the tree matches the last passing run or HEAD.

## After every review

Reports save themselves to `docs/reviews/` (from the report's first line): `-review.md`, `-security.md`, `-codex.md` for the Codex second opinion, and `-stuck.md` when a writer hit a stop rule and the ladder took over. Fill in `served:` on audit reports from `/tasks`. Mark each finding in the saved file: tick when fixed; `dismissed: <reason>` when it isn't real (same wording each time); or add an O-id when deferred. If reviews run but the folder stays empty, the capture hook is broken: fix that before trusting any metric.

Each saved review and Codex report ends with a `### Verification` block written by `scripts/verify-review.sh`. Read it before the findings: an `unverified` quote means the reviewer cited text that is not at that line (check that finding first, it may describe code that is not there); files listed after `not in ### Coverage` were changed but not read; `status: incomplete` names the missing sections. When any of these is off, the session also shows a one-line summary as the report is saved.

## Upgrading the kit

When the kit has a new version, from the kit repo:

```bash
scripts/install.sh --upgrade --dry-run /path/to/your-repo   # shows the classification, writes nothing
scripts/install.sh --upgrade /path/to/your-repo
```

Each kit file ends up in one class: **replaced** (you never touched it: updated in place), **current** (already matches), **tailored** (you changed it: the kit's version lands beside it as `*.kit`), **tailored (kit unchanged)** (you changed it, the kit did not: kept, no `.kit`), **new** (installed), **skipped** (you deleted it earlier: not re-added), **retired** (no longer in the kit: listed, never deleted), or **never re-added** (`TAILOR.md`, `HOW-TO-USE.md`). A repo from before 1.4 has no manifest, so every existing file that differs from the kit becomes `*.kit` once; the manifest is written at the end and later upgrades are quiet.

Then open Claude Code in the repo and say: **Read .claude/kit-upgrade.md**. That file holds the merge prompt, the classification and the CHANGELOG sections since your version. The session merges each `*.kit`, re-applies your model profile, runs the checks, records the upgrade and deletes the file. `scripts/check.sh doctor` warns about unmerged `*.kit` files and while `.claude/kit-upgrade.md` is present. `--upgrade` refuses to run while a previous merge is unfinished (`.claude/kit-upgrade.md` or a `.kit` file still present); `--force` runs it anyway, keeps files with a `.kit` sibling as tailored and keeps the earlier starting version.

## Monthly, ten minutes

- `scripts/check.sh doctor`: fails on a bloated `CLAUDE.md`, leftover kit placeholders, unconfigured checks, orphan O-ids, or more than 15 open items; warns on overdue items; prints the agreement rate and recurring dismissals.
- A finding recurring 3+ times becomes a lint rule, and its conventions row becomes **mechanical**. A dismissal recurring 2+ times goes into the reviewer's false-positives list.
- Add a line to the kit repo's `METRICS.md`: cost per merged change, agreement rate, escaped defects (flagged / silent / outside scope), verification honesty.
- `scripts/install.sh --upgrade --dry-run /path/to/repo` from the kit to see what changed in the kit; push your improvements back to the kit.

## What you own

- **Pushes and merges.** The kit's deny rules stop agents from pushing, resetting, cleaning, moving branches (`git branch -f`, `git update-ref`), and from `gh pr create`, `gh pr merge`, `gh repo create`, `gh repo sync`, `gh repo edit`, `gh repo archive` and `gh repo delete`. They prevent accidents but aren't a sandbox: a reworded command can slip past them.
- **The Stop warning.** After each turn, if files changed since `scripts/check.sh all` last passed, Claude Code shows a one-line warning with the count and up to three names. Committing makes it go quiet even when checks did not pass on that commit. If `check.sh all` cannot pass on your machine (for example semgrep is not installed), the warning appears on every turn with changes: install the tool or make that check `skip` with a reason.
- **Open items** and **accepted risks** (a Critical or High security finding you choose not to fix goes in `docs/decisions.md` with a date and reason).
- **The reviewer's two lists.** Add what you have corrected twice; prune quarterly.

## Companion skills (optional)

[mattpocock/skills](https://github.com/mattpocock/skills) installs per its README. The kit works without it. Worth knowing:

| Skill | When |
|---|---|
| `/grill-me` | Before a change you haven't fully thought through. Same question format the planner uses. |
| `/retro` | After a session that went badly. Proposes fixes to the environment (a check, a pointer) rather than the prompt. |
| `/to-questionnaire` | An open item a non-technical owner must decide. |
| `/handoff` | Handing a session to someone else. |
| `/wizard` | A setup step only a human can do (CI secrets, a vendor dashboard). |

Full detail on tiers, cadence and metrics: `docs/rollout.md`.
