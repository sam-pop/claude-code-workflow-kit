# How to use the Claude Kit

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

Optional: the [Codex CLI](https://learn.chatgpt.com/docs/non-interactive-mode), only if you turn on the codex extra (see Extras).

Optional companion skills: install per [that repo's README](https://github.com/mattpocock/skills) (see the bottom of this file).

## Per repo: install and tailor (about 30 minutes)

1. **Install.**

   ```bash
   /path/to/claude-code-workflow-kit/scripts/install.sh /path/to/your-repo
   ```

   Nothing is overwritten. Where a file already existed, the kit's version lands beside it as `*.kit` to merge by hand. The install also writes `.claude/kit-version` and `.claude/kit-manifest` (commit both); they are what lets `--upgrade` later tell an untouched file from a tailored one.

   **Review-only** (other people commit to the repo): install into a separate review workspace instead, never into their repo. Hooks run shell commands on your machine, including your linters and the config files they load, and a PR could change them. `TAILOR.md` sets this up. On a shared repo with outside contributors, review a branch's changes to `.claude/`, `scripts/` and every file your hooks, linters, formatters, tests or build execute before opening Claude Code on it.

2. **Tailor.** Open Claude Code in the repo and say:
   > Read TAILOR.md and tailor the kit to this repo.

   It explores the repo, asks one round of questions with recommended answers, fills placeholders, wires `check.sh` to the real commands, deletes what doesn't apply, runs `scripts/check.sh all` and pastes the output. Until `check.sh` is configured, every check fails on purpose, so nobody can report a pass that never ran.

3. **Review and commit.** Read `CLAUDE.md`, `docs/conventions.md` and the agent files as a stranger would. Commit. The report's **Follow-ups** list the lint rules still to write; schedule them like any other task.

## Extras

A fresh install is the core: the process, the agents, `scripts/check.sh`, the lint hook and the review capture hook. Everything below is off until you switch it on, and `docs/rollout.md` (Extras) has one section per extra. Start with none for the first two weeks, then add one when you can say what it should fix.

```bash
scripts/extras.sh status        # which are on; warn: lines for anything half-enabled
scripts/extras.sh on <name>     # or: off <name>
```

Record each choice in `docs/decisions.md`. An upgrade keeps each extra as your repo had it.

| Extra | Adds | Cost or egress | Switch on |
|---|---|---|---|
| `profiles` | Model and effort per agent (lite, standard or max), risk-scaled review effort, the writer ladder, a repeated-failure counter. Needs Claude Code v2.1.292 or later. | Model spend follows the profile; `max` bills Fable credits on Pro and standard Team plans, and `claude -p` does so without asking (set a cap in `/usage-credits`) | `scripts/extras.sh on profiles`, then `scripts/set-models.sh <lite\|standard\|max>` |
| `codex` | A Codex second opinion: on the planner's blueprint, on High-risk diffs and before a release. Never blocks. | Sends the plan text, diffs and tracked code to OpenAI; on client work get the client's OK first. Needs gitleaks and refuses when the change edits its own script. Takes its trusted config only from the base branch (set `BASE_BRANCH` for another, in the session environment, e.g. the `env` block of `.claude/settings.json`); filtered files leave as stored. Not available on Review-only. | `scripts/extras.sh on codex` |
| `stop-warning` | A one-line warning at the end of a turn naming files that changed since `check.sh all` last passed | A short git scan each turn | `scripts/extras.sh on stop-warning` |
| `verify-review` | A `### Verification` block on each saved review | None | `scripts/extras.sh on verify-review` |
| `metrics` | Review-log counts and the agreement rate in `check.sh doctor` | None | `scripts/extras.sh on metrics` |

The profile table (model/effort per agent) and the reasons for it: `docs/rollout.md`, Extras, profiles, and [the research report](https://github.com/sam-pop/claude-code-workflow-kit/blob/main/docs/research/coding-agent-model-effort-combos.md). With **metrics**, spend two weeks logging your current cost and minutes per merged change first, so the kit has a baseline to beat; the kill criteria are in `docs/rollout.md`, metrics.

## Daily

| You want | Say |
|---|---|
| A small fix (1–2 files) | "Fix X, run check.sh all, then the reviewer agent." |
| A larger change | "Run the planner on X." Answer its questions (reply "yes" to accept all recommendations). "Now the writer, then the reviewer, and show me the findings." |
| To understand code first | "Explore how X works." (built-in Explore agent) |
| A Review-only PR | In the review workspace: "Review PR #42 in <repo>." |
| A High-risk change (auth, money, personal data, secrets, migrations, `.claude/` `scripts/` CI) | "Run the planner, the writer, then the reviewer at the High tier (see `docs/rollout.md`, Risk tiers)." If the codex extra is on, add: "then the codex-reviewer." |
| A release (Shared, Review-only) | "Run codex-reviewer in release mode (if on), then the security auditor, and write the report to docs/security.md." After the audit, fill in the `served:` model from `/tasks`. |
| To decide an open item | "O7 is decided: <decision>. Record it." |

What comes back:

- **Writer:** files, tests and the bug each catches, each check's exit code with the last lines of its output pasted, and **Defaults I picked**, which are decisions nobody made. Read that list.
- **Reviewer:** a re-run of the checks compared against the writer's claims, then Standards and Spec findings with confidence numbers, a **Risks probed** section answering the blueprint's risks to probe, and a **Considered, below threshold** list so you can see what it held back.

Agents run one at a time in the foreground; the kit turns off fork mode so Claude waits for each.

**Handing work to another agent or person.** When you switch agents mid-task, write a brief status note: where things stand, what's next, and which open items block it. Point the next agent at it plus `docs/decisions.md` and `docs/open.md`. Keep secrets and private plans out of it.

**Stop warning (stop-warning extra).** When Claude finishes a turn after files changed since the last passing `scripts/check.sh all`, a one-line warning names those files ("scripts/check.sh all has not passed since these changes: …"). It is a reminder, not a block: run `scripts/check.sh all` (or ask Claude to) before you trust a "checks passed" claim or commit. Nothing is shown while the tree matches the last passing run, committed or not.

## After every review

Reports save themselves to `docs/reviews/` (from the report's first line): `-review.md`, `-security.md`, `-codex.md` and `-codex-plan.md` for the Codex second opinion, and `-stuck.md` when a writer hit a stop rule and the ladder took over. Fill in `served:` on audit reports from `/tasks`. Mark each finding in the saved file: tick when fixed; `dismissed: <reason>` when it isn't real (same wording each time); or add an O-id when deferred. If reviews run but the folder stays empty, the capture hook is broken: fix that before trusting any metric.

With the verify-review extra on, each saved review and Codex report ends with a `### Verification` block written by `scripts/verify-review.sh`. Read it before the findings: an `unverified` quote means the reviewer cited text that is not at that line (check that finding first, it may describe code that is not there); files listed after `not in ### Coverage` were changed but not read; `status: incomplete` names the missing sections. When any of these is off, the session also shows a one-line summary as the report is saved.

## Upgrading the kit

When the kit has a new version, from the kit repo:

```bash
scripts/install.sh --upgrade --dry-run /path/to/your-repo   # shows the classification, writes nothing
scripts/install.sh --upgrade /path/to/your-repo
```

Each kit file ends up in one class: **replaced** (you never touched it: updated in place), **current** (already matches), **tailored** (you changed it: the kit's version lands beside it as `*.kit`, and the kit's copy from the version you installed as `*.kit-base` when it can be read from the kit's git history), **tailored (kit unchanged)** (you changed it, the kit did not: kept, no `.kit`), **new** (installed), **skipped** (you deleted it earlier: not re-added), **retired** (no longer in the kit: listed, never deleted), or **never re-added** (`TAILOR.md`, `HOW-TO-USE.md`). A repo from before 1.4 has no manifest, so every existing file that differs from the kit becomes `*.kit` once; the manifest is written at the end and later upgrades are quiet.

Then open Claude Code in the repo and say: **Read .claude/kit-upgrade.md**. That file holds the merge prompt, the classification and the CHANGELOG sections since your version. The session merges each `*.kit`, re-applies your model profile and extras, runs the checks, records the upgrade and deletes the file. The session merges a file that has a `*.kit-base` three-way (`git merge-file`), so only lines you and the kit both changed are conflicts; without one it merges two-way, and `.claude/kit-upgrade.md` says why. A repo from before 1.4 can pass `--base <kit commit you installed from>` to `--upgrade` to get the `*.kit-base` files. `scripts/check.sh doctor` warns about unmerged `*.kit` and `*.kit-base` files and while `.claude/kit-upgrade.md` is present. `--upgrade` refuses to run while a previous merge is unfinished (`.claude/kit-upgrade.md`, a `.kit` or a `.kit-base` file still present); `--force` runs it anyway, keeps files with a `.kit` sibling as tailored, keeps the earlier starting version and the earlier `.kit-base` files.

## Monthly, ten minutes

- `scripts/check.sh doctor`: fails on a bloated `CLAUDE.md`, leftover kit placeholders, unconfigured checks, orphan O-ids, or more than 15 open items; warns on overdue items; with the metrics extra on, prints the agreement rate and recurring dismissals.
- A finding recurring 3+ times becomes a lint rule, and its conventions row becomes **mechanical**. A dismissal recurring 2+ times goes into the reviewer's false-positives list.
- With metrics on, note once a month: cost per merged change, agreement rate, escaped defects (flagged / silent / outside scope), verification honesty.
- `scripts/install.sh --upgrade --dry-run /path/to/repo` from the kit to see what changed in the kit; push your improvements back to the kit.

## What you own

- **Pushes and merges.** The kit's deny rules stop agents from pushing, resetting, cleaning, moving branches (`git branch -f`, `git update-ref`), and from `gh pr create`, `gh pr merge`, `gh repo create`, `gh repo sync`, `gh repo edit`, `gh repo archive` and `gh repo delete`. They prevent accidents but aren't a sandbox: a reworded command can slip past them.
- **The Stop warning** (stop-warning extra). After each turn, if files changed since `scripts/check.sh all` last passed, Claude Code shows a one-line warning with the count and up to three names. Committing unchecked changes does not silence it. If `check.sh all` cannot pass on your machine (for example semgrep is not installed), the warning appears on every turn with changes: install the tool or make that check `skip` with a reason.
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
