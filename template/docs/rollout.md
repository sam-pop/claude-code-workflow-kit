# Rollout and maintenance

## Tiers

Pick one per repo. The tailoring session asks which.

| Tier | When | Kit pieces | `handoff.md` |
|---|---|---|---|
| **Script** | Automations, one-file tools, glue | `CLAUDE.md`, `check.sh`, conventions (short) | none |
| **Solo** | One engineer, side product, low blast radius | Full docs, main session + reviewer; planner and writer for 3+ file changes | git-ignored |
| **Shared** | Client work, a second contributor, money or personal data in play | Everything; planner on anything beyond a small fix; reviewer required before merge; security auditor before each release and quarterly | committed, or mirrored to the issue tracker |
| **Review-only** | Other people write the code (a contractor team, an agency); you are the reviewer of record | Reviewer + security auditor, conventions and the two lists, in a **separate review workspace**, not in their repo (see below) | none |

`check.sh security` (secret scan, dependency audit, SAST) runs at every tier; the auditor agent is Shared and Review-only.

Review-only is often the highest-value tier when you are accountable for code you don't write: the kit becomes your review arm, and the review log becomes a written trail you can show the people who rely on that code.

### Review-only: keep the kit out of their repo

Hooks in `.claude/settings.json` and `scripts/` run shell commands on your machine. In a repo other people commit to, a PR that edits those files runs its code the next time you open Claude Code there. So for Review-only:

- Keep the agents, `docs/conventions.md` and the two lists in your own review workspace (a folder or private repo), with the client repo checked out read-only beside it, or reviewed through `gh pr diff <n>`.
- Install no hooks in the client repo. If the client wants `check.sh` and CI, that is a normal PR they review.
- The reviewer treats any change to `.claude/`, `scripts/`, CI or hook config as blocking.

The same caution applies on Shared repos with outside contributors: review changes to `.claude/` and `scripts/` before opening Claude Code on that branch.

## Model profiles

Tiers decide which agents run; profiles decide which models and efforts they run on. Pick a profile by what your plan and budget cover, and switch any time with `scripts/set-models.sh <lite|standard|max> [--cross]`. Record the choice in `docs/decisions.md`.

| Profile | planner | writer | reviewer | security-auditor | For |
|---|---|---|---|---|---|
| **lite** | sonnet/high | sonnet/high | sonnet/high | opus/high | Pro ($20) plans. About half the cost per solved task of standard's writer ($0.11 vs $0.22), at a lower first-try solve rate (87.6% vs 92.8%); the ladder catches failures. |
| **standard** (default) | opus/high | opus/medium | opus/high | opus/xhigh | Any plan with Opus access. |
| **max** | fable/high | opus/medium | opus/high | fable/high | Plans or budgets that include Fable. Fable only in the two rare roles. |
| `--cross` | | | | | Adds the codex-reviewer (Codex second opinion), off by default. |

Why: planner quality earns the writer a `medium` effort, and the escalation ladder (CLAUDE.md, Workflow) covers its failures; the reviewer never runs below `medium` (Opus at `low` scored 34 points below `medium` at finding bugs); Fable only in rare, low-volume roles (planner, auditor). Never set Sonnet below `high`: Sonnet 5.5 at `medium` fell from 77.8% to 62.7% on Anthropic's internal agentic-coding benchmark. Full reasoning and sources: [the research report](https://github.com/sam-pop/claude-code-workflow-kit/blob/main/docs/research/coding-agent-model-effort-combos.md).

Agents use model aliases, so they move to new model versions automatically. **Fable billing**: on Pro and standard Team plans Fable bills usage credits from the first request. Interactive sessions ask for consent first, but `claude -p` and Agent SDK runs bill **without asking**, and background or Remote sessions drop the turn after 5 minutes waiting for consent. Set a cap in `/usage-credits` before choosing **max**.

### Risk tiers and the ladder

Review effort scales with risk, and the writer escalates on objective triggers. The tier table and the ladder live in `CLAUDE.md` (Workflow); change them there, not here. `scripts/check.sh doctor` warns about settings that silently undo them (`CLAUDE_CODE_EFFORT_LEVEL`, forced subagent models, old Claude Code).

### Cross-model review (optional)

`scripts/set-models.sh <profile> --cross` moves the codex-reviewer from `.claude/optional/` into `.claude/agents/`. It runs on High-risk diffs (`gpt-6.1-sol`, effort `high`) and once before a release (`gpt-6-astra`, effort `high`; if Astra is unavailable on your plan, one retry on `gpt-6.1-sol` at `xhigh`). Never `ultra`. A ChatGPT Plus subscription gives it a separate quota, which stretches a Pro plan further.

- **Triage, never a gate.** Where it agrees with the Claude reviewer, confidence goes up; what only Codex raised gets your attention. Check each finding against the diff.
- **Egress.** Codex works in a fresh copy of HEAD (checked out through a temporary index) plus your uncommitted changes, with no `.git`: git-ignored files and history are kept out of the directory Codex works in; Codex's read-only sandbox limits writes, not reads, so treat anything your user account can read as reachable. gitleaks scans that copy and the final prompt (with the diff) first, using the base's `.gitleaks.toml` and `.gitleaksignore` and ignoring new inline `gitleaks:allow` markers, and a finding refuses the run. Tracked code and the diff still leave for OpenAI; on client work, get the client's OK first and record it in `docs/decisions.md`. **Not available on Review-only** in 1.4: the script reviews its own repo, not someone else's PR.
- **Limits.** Astra on ChatGPT Plus allows roughly 5 to 45 local messages per 5 hours, enough for one release pass.

## Rollout order

1. Tailor the kit on the most active repo and work in it for two weeks before touching another.
2. Fold what you had to fix back into the kit. The kit is wrong until a real repo has corrected it at least once.
3. Roll out to the next repo. Repeat.
4. Keep the kit in its own repo so every target repo can diff against it.

## Cadence

| When | Do |
|---|---|
| Every session end | Rewrite `handoff.md` (ask for it; nothing forces it). Move any decision made into `decisions.md`; any new question into `open.md`. |
| Every merge | Reviewer findings recorded with what was done about each. Spot-check one finding the reviewer did *not* raise. |
| Monthly | `CLAUDE.md` under 150 lines; prune. Run `scripts/install.sh --upgrade --dry-run /path/to/repo` from the kit to see what changed. Promote any rule the reviewer keeps catching into a mechanical check. |
| Before each release (Shared, Review-only) | Run the security auditor. Critical/High fixed or explicitly accepted in `docs/decisions.md`. |
| Quarterly | Reread the reviewer's "Subtle violations" and "False positives" lists; drop what no longer fires, add what you have corrected twice. Run the security auditor even if nothing sensitive changed. |

## Pre-committed tests of the kit itself

Decide these before the first repo, so the kit cannot talk you into keeping it.

**Baseline first.** For two weeks before turning the agents on, log the same three numbers for your current way of working. Without a baseline, every later number is unfalsifiable.

**Metrics** (monthly, one line per repo in the kit repo's `METRICS.md`):

1. **Cost per merged change**: tokens or dollars (`/cost` at session end, or Claude Code's OpenTelemetry metrics) plus your own minutes from request to merge, including list upkeep. Must be at or below the baseline within 60 days.
2. **Reviewer precision and misses**: agreement rate (findings fixed ÷ fixed + dismissed; `doctor` prints it), and escaped defects per month, each classed as *reviewer flagged*, *reviewer silent* or *outside scope*. A rising *reviewer silent* count with stable precision means the confidence thresholds are hiding real issues.
3. **Verification honesty**: share of writer reports whose claimed check results match what the reviewer got re-running them. Below 95% means the writer's self-report cannot be trusted and the reviewer must always re-run.

**Kill criteria**:

- Cost per merged change above baseline after 60 days on the first repo → stop rolling out; shrink the kit (drop the planner, then the writer) before trying again.
- Agreement rate under 40% for two months → drop the reviewer to a lint-only gate and rework the two lists.
- Review log empty for 30 days **while reviews ran** (check that `docs/reviews/` gets new files; if it doesn't, the hook is broken, not the loop) → drop the loop and keep the rest.

**First-month measures for the model setup.** Log sources: the reviewer's `### Run` line, `*-stuck.md`, `*-codex.md`, `/usage` (spend per subagent) and `/tasks` (served model). Compare medians, not means: a single-owner repo produces tens of tasks a month, and run-to-run spend varies up to 30 times. Subscription quota weighting per model is unpublished, so measure with `/usage`.

| Measure | Decision rule at month end |
|---|---|
| Rung-1 clearance rate (checks and review pass with no escalation) | Below 70%: fix blueprint quality or start at `high`. Above 95% over 15+ tasks: trial `low` as rung 1 on well-tested areas. |
| Rescue rate of rungs 2 and 3 | Rung 3 rescues fewer than one in three of its entries: drop it and go straight to re-plan. |
| Median cost and wall time per completed task, by rung | Sets the "3x median" trigger. |
| Reviewer accepted-finding rate by effort tier | `xhigh` on High-risk shows no higher acceptance or catch rate than `high`: drop it to `high`. |
| Escaped defects traced to a reviewed change | Any High-risk escape: revisit the tier definitions before the costs. |
| Codex unique accepted findings, false-positive rate, agreement rate | No unique accepted finding across 8+ High-risk diffs: move Codex to pre-release only. |
| Auditor served model, reproduced vs unreproduced Critical/High | Run `xhigh` and `max` once each on the same release commit and count validated findings. Note any reroute. |
| Fable credits spent, share of the weekly limit, consent-prompt drops | Fable uses a large share of the weekly window: move the planner back to Opus `high`. |

## Token and cost discipline

- `CLAUDE.md` is loaded every turn; every line costs on every call. Keep it an index.
- Subagents load `CLAUDE.md` and a git-status snapshot automatically. The planner, reviewer and auditor set `omitClaudeMd: true` and read only what their Setup lists; the writer keeps `CLAUDE.md` because it needs the commands.
- Small fixes skip the planner and writer: main session plus reviewer is two contexts instead of four.
- The planner and reviewer are read-only and bounded; the writer is where cost accumulates. Give it a blueprint so it does not re-decide.
- Mechanical checks are free. Anything grep can find should never reach a model.
- Review effort scales with risk; never below `medium`.
