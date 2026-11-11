# Rollout and maintenance

## Tiers

Pick one per repo. The tailoring session asks which.

| Tier | When | Kit pieces |
|---|---|---|
| **Script** | Automations, one-file tools, glue | `CLAUDE.md`, `check.sh`, conventions (short) |
| **Solo** | One engineer, side product, low blast radius | Full docs, main session + reviewer; planner and writer for 3+ file changes |
| **Shared** | Client work, a second contributor, money or personal data in play | Everything; planner on anything beyond a small fix; reviewer required before merge; security auditor before each release and quarterly |
| **Review-only** | Other people write the code (a contractor team, an agency); you are the reviewer of record | Reviewer + security auditor, conventions and the two lists, in a **separate review workspace**, not in their repo (see below) |

`check.sh security` (secret scan, dependency audit, SAST) runs at every tier; the auditor agent is Shared and Review-only.

Review-only is often the highest-value tier when you are accountable for code you don't write: the kit becomes your review arm, and the review log becomes a written trail you can show the people who rely on that code.

### Review-only: keep the kit out of their repo

Hooks in `.claude/settings.json` and `scripts/` run shell commands on your machine, and the lint hook runs your linters after every edit. In a repo other people commit to, a PR that edits those files, or any file the linters, formatters, tests or build execute, runs its code the next time you open Claude Code there. So for Review-only:

- Keep the agents, `docs/conventions.md` and the two lists in your own review workspace (a folder or private repo), with the client repo checked out read-only beside it, or reviewed through `gh pr diff <n>`.
- Install no hooks in the client repo. If the client wants `check.sh` and CI, that is a normal PR they review.
- The reviewer treats any change to `.claude/`, `scripts/`, CI or hook config, and to files those tools execute, as blocking.

The same caution applies on Shared repos with outside contributors. Before opening Claude Code on a branch from someone you don't fully trust, review its changes to `.claude/`, `scripts/` and every file your hooks, linters, formatters, tests or build execute (e.g. `eslint.config.js`, `conftest.py`, `package.json` scripts, a `Makefile`). The lint hook runs your linters after every edit.

## Risk tiers

The planner states a tier for each larger change and the main session confirms it with the owner. A small fix made in the main session is Low.

| Tier | Change |
|---|---|
| Low | Small fix in the main session |
| Medium | Normal blueprint change |
| High | Auth, tenancy, money, personal data, secrets, migrations or destructive writes, concurrency, `.claude/` `scripts/` or CI, or any escalated writer output |

With the **profiles** extra on, the tier also sets the reviewer's effort (see Extras, profiles).

## Extras

The kit's core is the process, the agents, `scripts/check.sh`, the lint hook and the capture hook. Everything else is an extra, off in a fresh install. An extra is its files: dormant in `.claude/optional/`, active at `.claude/agents/<file>.md` or `scripts/<file>.sh`. Core scripts call an extra's script only when it is active.

```bash
scripts/extras.sh status        # one line per extra, then a warn: line for anything half-enabled
scripts/extras.sh on <name>     # move the extra's file to its active path
scripts/extras.sh off <name>
```

Every extra is exactly one file; switching moves it and edits nothing else. Record the choice in `docs/decisions.md`. `scripts/install.sh --upgrade` keeps each extra as the repo had it, and `check.sh doctor` shows the `status` warnings. Start with none for the first two weeks and add one when you can say what it should fix. Two extras were retired in 1.8, the stop-warning hook and the repeated-failure counter: a repo that had them keeps their files, `extras.sh` no longer lists them, and `scripts/extras.sh on stop-warning` says so.

| Extra | Adds | Cost or egress |
|---|---|---|
| `codex` | A Codex second opinion on the plan, on High-risk diffs and before a release | Sends the plan text or the diff (with 20 lines of context) to OpenAI |
| `profiles` | Model and effort per agent (`set-models.sh`), risk-scaled review effort, the writer ladder | Model spend follows the profile; `max` bills Fable credits |
| `verify-review` | A `### Verification` block on each saved review | None |
| `metrics` | Review-log counts in `check.sh doctor` | None |

### codex

`scripts/extras.sh on codex` moves the codex-reviewer from `.claude/optional/` into `.claude/agents/`. It needs the Codex CLI and gitleaks, and is not available on Review-only: the script reviews its own repo, not someone else's PR. It never blocks.

- **Plan review.** On a larger change, save the planner's blueprint as a `*.md` file at a path that is not git-ignored (for example `docs/plans/<change>.md`) and run codex-reviewer on it (`scripts/codex-review.sh plan <file>`, `gpt-6.1-sol`, effort `high`) before the owner's question round. Show its objections (gaps, wrong assumptions, the risk tier, missing tests, a simpler alternative) next to the planner's questions. Only the plan text leaves for OpenAI, after the same gitleaks scan; no repository files and no diff.
- **Diffs and releases.** After the reviewer on High-risk diffs (`scripts/codex-review.sh high <base>`) and once before a release (`scripts/codex-review.sh release`), both `gpt-6.1-sol` at effort `high`. Never `ultra`. A ChatGPT Plus subscription gives it a separate quota, which stretches a Pro plan further.
- **Triage, never a gate.** Show the owner where it agrees with the Claude reviewer (confidence goes up) and what only Codex raised. Check each finding against the diff. If it raises no unique accepted finding across 8+ High-risk diffs, move it to pre-release only.
- **Egress.** Codex receives one prompt and nothing else: the plan text, or the diff (20 lines of context, removed lines and new untracked text files included) with the reviewer checklist and `docs/conventions.md` from the base branch. It starts in an empty directory, so it has no repository file to open; its read-only sandbox limits writes, not reads, so a model steered to a path your user account can read could still read it. Tracked changes and the diff still leave for OpenAI; on client work, get the client's OK first and record it in `docs/decisions.md`. The scan is a **best-effort guard against accidents, not a security boundary**: it is gitleaks' pattern matching. These guarantees hold, each with a test in `tests/codex-review.bats` named after its number:
  1. Nothing is sent with the extra off, or without `codex` or `gitleaks` installed.
  2. Only the prompt leaves, and Codex starts in an empty directory.
  3. No git-ignored file is in the prompt.
  4. The prompt is scanned once, with inline `gitleaks:allow` markers ignored, no path exemption (it is scanned under a neutral name) and no `.gitleaksignore`, using the `.gitleaks.toml` of the merge-base of the base branch and `HEAD` (`origin/<base>`, else the local base; `BASE_BRANCH` for another, set in the session environment because the guard allows no `VAR=…` prefix). A finding, or a gitleaks that cannot run or load that config, refuses the run (exit 5). To silence a false positive, add a `regexes` or `stopwords` allowlist to the base branch's `.gitleaks.toml`.
  5. A changed, deleted or untracked file named like a secrets file (`.env`, `*.pem`, `*.p12`, `id_rsa`, `id_ed25519`) refuses the run (exit 5).
  6. A tracked file behind a filter driver (git-crypt, LFS) appears as git stores it, never as plaintext (no textconv, no external diff). Untracked filtered files, symlinks, directories and binaries are named, not sent.
  7. The run refuses (exit 5) when `scripts/codex-review.sh` or `codex-reviewer.md` differ from the merge-base; review that change first.
  8. The checklist and `docs/conventions.md` come from the merge-base, not from the working tree; if the base has no `reviewer.md`, the working-tree copy is used and the report header says so.

  Blind spots (documented, not fixed in code):
  - Unprefixed secrets (a bare password) pass.
  - UTF-16 text passes.
  - Encoded or compressed text (base64, gzip, zip) passes.
  - gitleaks rules scoped to a file name (`nuget.config`, `.npmrc`) do not fire: the prompt has a neutral name.
  - A permissive base `.gitleaks.toml` (an allow-all path or regex) is trusted.
  - Without `origin/<base>`, anything committed on the local base is trusted.
  - Codex's sandbox limits writes, not reads.
  - An uncommitted `.gitattributes` edit that drops a filter (git-crypt) on an unlocked repo puts that file's plaintext in the diff.
  - A `TMPDIR` inside the repo and not git-ignored puts the script's own temporary files in the diff as untracked files.
- **Reports from another transport.** A Codex report that did not come from `scripts/codex-review.sh` is saved as `docs/reviews/<date>-<time>-<sha>-codex.md` starting with `## Codex review:`; with verify-review on, run `scripts/verify-review.sh <file>` and append its output.
- **Unverified with the real CLI.** The script has not been run against the real Codex CLI, and the codex-reviewer's frontmatter `PreToolUse` guard has been tested by script, not observed firing in a live session. Run `scripts/codex-review.sh high` and `plan` once with the real CLI before relying on it.

### profiles

`scripts/extras.sh on profiles` installs `scripts/set-models.sh`. Tiers decide which agents run; profiles decide which models and efforts they run on. Pick a profile by what your plan and budget cover and switch with `scripts/set-models.sh <lite|standard|max>`, unless `docs/decisions.md` records tailored seats (an agent whose model or effort you set by hand): then edit those files yourself. The script refuses to overwrite a seat that is none of the profiles' values for its role (exit 1, nothing changed) and says which; `--force` overrides. Record the choice in `docs/decisions.md`.

| Profile | planner | writer | reviewer | security-auditor | For |
|---|---|---|---|---|---|
| **lite** | sonnet/high | sonnet/high | opus/medium | opus/high | Pro ($20) plans. Sonnet plans and writes, Opus reviews and audits. |
| **standard** (default) | opus/high | sonnet/high | opus/high | opus/xhigh | Any plan with Opus access. |
| **max** (experimental) | opus/high | opus/medium | fable/high | fable/high | Plans or budgets that include Fable. A hypothesis: there is no comparative Fable-vs-Opus data for reviewing or auditing. |

Why: the model that wrote the code never reviews it, so writer and reviewer are on different models in every profile. The reviewer never runs below `medium` (Opus at `low` scored 34 points below `medium` at finding bugs). Never set Sonnet below `high`: Sonnet 5.5 at `medium` dropped about 7 points on SWE-bench Pro and about 15 (77.8% to 62.7%) on Anthropic's internal agentic-coding benchmark; both are Anthropic's own measurements. On cost (Anthropic's directional figures, API list prices): Sonnet 5.5 `high` solved 87.6% of tasks at $0.11 per solved task, Opus 5.5 `medium` 92.8% at $0.22, so the Sonnet writer in lite and standard costs about half as much per solved task, at a lower first-try solve rate (87.6% vs 92.8%, Anthropic's measurement). The effort-only ladder below is meant to recover some of that gap, but it is unmeasured for Sonnet. Full reasoning and sources: [the research report](https://github.com/sam-pop/claude-code-workflow-kit/blob/main/docs/research/coding-agent-model-effort-combos.md).

Agents use model aliases, so they move to new model versions automatically. **Fable billing**: on Pro and standard Team plans Fable bills usage credits from the first request. Interactive sessions ask for consent first, but `claude -p` and Agent SDK runs bill **without asking**, and background or Remote sessions drop the turn after 5 minutes waiting for consent. Set a cap in `/usage-credits` before choosing **max**. `scripts/check.sh doctor` warns about settings that silently undo the setup (`CLAUDE_CODE_EFFORT_LEVEL`, forced subagent models, a reviewer on the writer's model).

**Reviewer effort by risk tier.** Pass it as the Agent tool's `effort` parameter; this section authorises that. Never below `medium`, and never a different `model`: the reviewer stays off the writer's model.

| Tier | Reviewer `effort` |
|---|---|
| Low | `medium` |
| Medium | the reviewer's frontmatter effort (`high`; `medium` on lite) |
| High | `xhigh`, or `high` when the reviewer runs on Fable (max) |

A Fable reviewer stays at `high` on High risk because Fable lost only about 1.8 points of bug-finding from `high` to `low` (Anthropic's measurement, [the research report](https://github.com/sam-pop/claude-code-workflow-kit/blob/main/docs/research/coding-agent-model-effort-combos.md)): extra effort buys little on the most expensive model. `xhigh` on High risk for an Opus reviewer is a hypothesis: no review-effort ablation exists for Claude. If across 8+ High-risk reviews `xhigh` shows no higher accepted-finding rate than `high`, drop it to `high`. Any escaped defect on a High-risk change: revisit the tier definitions before the costs.

**Writer ladder.** Rung 1 is the writer as defined. Escalate on any of:

- the same check failing 3 times with the same error, or still failing after the writer's own fixes;
- the reviewer's re-run disagreeing with the writer's report;
- a blocking finding surviving one repair pass at the same rung;
- a `## STUCK:` report from the writer;
- the owner reporting a rung that used more than 3x its usual tokens.

NOT CONFIGURED checks and Warnings never trigger escalation. Each rung is a fresh writer one effort step up (Agent `effort`) on the same model, given the blueprint and a failure brief; never resume the failed one. The tree holds the last attempt: keep, fix or revert from it.

| Profile | Rung 1 | Rung 2 | Rung 3 | Then |
|---|---|---|---|---|
| lite, standard | sonnet/high | sonnet/xhigh | none | stop |
| max | opus/medium | opus/high | opus/xhigh | stop |

Stop means the briefs go to the planner and the owner is told. Name the rung and the trigger in each writer and reviewer prompt; the reviewer records them in its `### Run` line. Never pass Agent `model`: an escalated writer must not land on the reviewer's model. The measured gain came from re-running failures at higher effort; switching models mid-ladder was never measured (the research report above).

### verify-review

`scripts/extras.sh on verify-review` makes `scripts/capture-review.sh` append a `### Verification` block to each saved review and Codex report, and show a one-line message when something is off. The reviewer writes a quote under every finding and a `### Coverage` section; `scripts/verify-review.sh` checks that each quote is in the file it cites and that every changed file is named as read. Read the block before the findings: an `unverified` quote means the reviewer may be describing code that is not there; files listed after `not in ### Coverage` were changed but not read; `status: incomplete` names the missing sections. Pass all three on to the owner with the findings.

### metrics

`scripts/extras.sh on metrics` makes `check.sh doctor` print counts from `docs/reviews/`: findings fixed, dismissed and unmarked, the agreement rate, incomplete reports, unverified quotes, Codex reports and escalations in the last 30 days. Decide what you will measure before you turn the agents on, so the kit cannot talk you into keeping it.

**Baseline first.** For two weeks before turning the agents on, log the same three numbers for your current way of working. Without a baseline, every later number is unfalsifiable. Read this section before the first repo.

**Metrics** (monthly):

1. **Cost per merged change**: tokens or dollars (`/cost` at session end, or Claude Code's OpenTelemetry metrics) plus your own minutes from request to merge, including list upkeep. Must be at or below the baseline within 60 days.
2. **Reviewer precision and misses**: agreement rate (findings fixed ÷ fixed + dismissed; `doctor` prints it), and escaped defects per month, each classed as *reviewer flagged*, *reviewer silent* or *outside scope*. A rising *reviewer silent* count with stable precision means the confidence thresholds are hiding real issues.
3. **Verification honesty**: share of writer reports whose claimed check results match what the reviewer got re-running them. Below 95% means the writer's self-report cannot be trusted and the reviewer must always re-run.

**Kill criteria**:

- Cost per merged change above baseline after 60 days on the first repo → stop rolling out; shrink the kit (drop the planner, then the writer) before trying again.
- Agreement rate under 40% for two months → drop the reviewer to a lint-only gate and rework the two lists.
- Review log empty for 30 days **while reviews ran** (check that `docs/reviews/` gets new files; if it doesn't, the hook is broken, not the loop) → drop the loop and keep the rest.

Compare medians, not means: a single-owner repo produces tens of tasks a month. Subscription quota weighting per model is unpublished, so measure spend with `/usage` and the served model with `/tasks`.

## Rollout order

1. Tailor the kit on the most active repo and work in it for two weeks before touching another.
2. Fold what you had to fix back into the kit. The kit is wrong until a real repo has corrected it at least once.
3. Roll out to the next repo. Repeat.
4. Keep the kit in its own repo so every target repo can diff against it.

## Cadence

| When | Do |
|---|---|
| Every session end | Move any decision made into `decisions.md`; any new question into `open.md`. |
| Every merge | Reviewer findings recorded with what was done about each. Spot-check one finding the reviewer did *not* raise. |
| Monthly | `CLAUDE.md` under 150 lines; prune. Run `scripts/install.sh --upgrade --dry-run /path/to/repo` from the kit to see what changed. Promote any rule the reviewer keeps catching into a mechanical check. |
| Before each release (Shared, Review-only) | Run the security auditor. Critical/High fixed or explicitly accepted in `docs/decisions.md`. |
| Quarterly | Reread the reviewer's "Subtle violations" and "False positives" lists; drop what no longer fires, add what you have corrected twice. Run the security auditor even if nothing sensitive changed. |

## Token and cost discipline

- `CLAUDE.md` is loaded every turn; every line costs on every call. Keep it an index.
- Subagents load `CLAUDE.md` and a git-status snapshot automatically. The planner, reviewer and auditor set `omitClaudeMd: true` and read only what their Setup lists; the writer keeps `CLAUDE.md` because it needs the commands.
- Small fixes skip the planner and writer: main session plus reviewer is two contexts instead of four.
- The planner and reviewer have no edit tools and a bounded job; the writer is where cost accumulates. Give it a blueprint so it does not re-decide.
- Mechanical checks are free. Anything grep can find should never reach a model.
- Review effort scales with risk; never below `medium`.
