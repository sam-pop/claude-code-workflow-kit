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

Hooks in `.claude/settings.json` and `scripts/` run shell commands on your machine. In a repo other people commit to, a PR that edits those files runs its code the next time you open Claude Code there. So for Review-only:

- Keep the agents, `docs/conventions.md` and the two lists in your own review workspace (a folder or private repo), with the client repo checked out read-only beside it, or reviewed through `gh pr diff <n>`.
- Install no hooks in the client repo. If the client wants `check.sh` and CI, that is a normal PR they review.
- The reviewer treats any change to `.claude/`, `scripts/`, CI or hook config as blocking.

The same caution applies on Shared repos with outside contributors: review changes to `.claude/` and `scripts/` before opening Claude Code on that branch.

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
scripts/extras.sh on <name>     # move the files active and add the extra's hook, if it has one
scripts/extras.sh off <name>
```

Switching moves files and changes only the kit's own hook entry in `.claude/settings.json` (the rest is kept, re-written with 2-space indentation). Record the choice in `docs/decisions.md`. `scripts/install.sh --upgrade` keeps each extra as the repo had it, and `check.sh doctor` shows the `status` warnings. Start with none for the first two weeks and add one when you can say what it should fix.

| Extra | Adds | Cost or egress |
|---|---|---|
| `codex` | A Codex second opinion on the plan, on High-risk diffs and before a release | Sends the plan text, diffs and tracked code to OpenAI |
| `profiles` | Model and effort per agent (`set-models.sh`), risk-scaled review effort, the writer ladder, the repeated-failure counter | Model spend follows the profile; `max` bills Fable credits |
| `stop-warning` | A `Stop` hook that names files changed since `check.sh all` last passed | A short git scan each turn |
| `verify-review` | A `### Verification` block on each saved review | None |
| `metrics` | Review-log counts in `check.sh doctor` | None |

### codex

`scripts/extras.sh on codex` moves the codex-reviewer from `.claude/optional/` into `.claude/agents/`. It needs the Codex CLI and gitleaks, and is not available on Review-only: the script reviews its own repo, not someone else's PR. It never blocks.

- **Plan review.** On a larger change, save the planner's blueprint to a file in the repo and run codex-reviewer on it (`scripts/codex-review.sh plan <file>`, `gpt-6.1-sol`, effort `high`) before the owner's question round. Show its objections (gaps, wrong assumptions, the risk tier, missing tests, a simpler alternative) next to the planner's questions. Only the plan text leaves for OpenAI, after the same gitleaks scan; no repository files and no diff.
- **Diffs and releases.** After the reviewer on High-risk diffs (`scripts/codex-review.sh high <base>`, `gpt-6.1-sol`, effort `high`) and once before a release (`scripts/codex-review.sh release`, `gpt-6-astra`, effort `high`; if Astra is unavailable on your plan, one retry on `gpt-6.1-sol` at `xhigh`). Never `ultra`. Astra for release is experimental: it rests on one secondhand, non-coding benchmark, it scored below Sol on the coding one, and no code-review benchmark exists for either; Sol for both modes is the conservative choice. A ChatGPT Plus subscription gives it a separate quota, which stretches a Pro plan further.
- **Triage, never a gate.** Show the owner where it agrees with the Claude reviewer (confidence goes up) and what only Codex raised. Check each finding against the diff. If it raises no unique accepted finding across 8+ High-risk diffs, move it to pre-release only.
- **Egress.** Codex works in a fresh copy of HEAD (checked out through a temporary index) plus your uncommitted changes, with no `.git`: git-ignored files and history are kept out of the directory Codex works in; Codex's read-only sandbox limits writes, not reads, so treat anything your user account can read as reachable. gitleaks is required (without it the script refuses, exit 3) and scans that copy and the final prompt (with the diff) for known-pattern secrets first, using the base's `.gitleaks.toml` and `.gitleaksignore` and ignoring new inline `gitleaks:allow` markers; a finding refuses the run. It is pattern-based: an unprefixed password or key can pass. A tracked `.env`, `*.pem`, `*.p12` or SSH key refuses the run too; symlinks and a `.codex/` directory are removed; an `AGENTS.md` is named in the report header. The reviewer checklist sent to Codex comes from the base; the run refuses when the change itself edits `scripts/codex-review.sh` or `codex-reviewer.md` (review that change first; for a release, then pass a start ref after it), and in high mode when a local base is HEAD or ahead of it. Tracked code and the diff still leave for OpenAI; on client work, get the client's OK first and record it in `docs/decisions.md`.
- **Limits.** Astra on ChatGPT Plus allows roughly 5 to 45 local messages per 5 hours, enough for one release pass.
- **Unverified with the real CLI.** Whether Codex honours a project `.codex/config.toml` or `AGENTS.md` under `--skip-git-repo-check`, and whether the codex-reviewer's frontmatter `PreToolUse` guard fires in a live session (tested by script, not yet observed live). The script removes `.codex/` and names `AGENTS.md` either way.

### profiles

`scripts/extras.sh on profiles` installs `scripts/set-models.sh` and the repeated-failure counter. Tiers decide which agents run; profiles decide which models and efforts they run on. Pick a profile by what your plan and budget cover and switch with `scripts/set-models.sh <lite|standard|max>`, unless `docs/decisions.md` records tailored seats (an agent whose model or effort you set by hand): then edit those files yourself. The script refuses to overwrite a seat that is none of the profiles' values for its role (exit 1, nothing changed) and says which; `--force` overrides. Record the choice in `docs/decisions.md`.

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

- `scripts/check.sh` printing `same failure N times: …` in the pasted output, or the same check still failing after the writer's own fixes;
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

### stop-warning

`scripts/extras.sh on stop-warning` adds a `Stop` hook that runs `scripts/check-stamp.sh hook` when Claude finishes a turn. `scripts/check.sh all` records the files it passed on (paths and blob ids under `.git/kit`, never committed). When files differ from that run, committed or not, the session shows how many and up to three names. It is a reminder, not a block. It stays silent when nothing changed and until `check.sh` is configured.

- Limits: committing unchecked changes still warns, and if `check.sh all` cannot pass on your machine (a missing tool) the warning appears on every turn with changes: install the tool or make that check `skip` with a reason.
- On very large trees (about 200k files) the hook can reach its 30 s timeout. It never blocks; switch the extra off there.
- A tailored `scripts/check.sh` needs the two stamp lines (`scripts/check-stamp.sh tree` before lint, `record` after doctor); `extras.sh status` warns when they are missing.

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
