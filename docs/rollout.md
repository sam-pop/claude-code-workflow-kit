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

Tiers decide which agents run; profiles decide which models they run on. Pick a profile by what your plan and budget cover, and switch any time with `scripts/set-models.sh <profile>`.

| Profile | planner | writer | reviewer | security-auditor | For |
|---|---|---|---|---|---|
| **standard** (default) | opus | sonnet | opus | opus | Any plan with Opus access. The writer does the most tokens, so it gets the cheaper model; judgment roles get Opus. |
| **max** | opus | opus | fable | fable | Plans or budgets that include Fable. Fable reviews the diff once per change, where its extra capability buys the most for the fewest tokens. |

Agents use model aliases, so they move to new model versions automatically. Fable can bill usage credits depending on plan and seat: interactive sessions ask for consent first, but `claude -p` and Agent SDK runs bill **without asking**. Check your `/model` picker for "Requires usage credits" before choosing **max** for any automated run.

Move a repo up a tier when someone else touches it or when a mistake would cost a client. Rarely move down.

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
| Monthly | `CLAUDE.md` under 150 lines; prune. Diff `.claude/agents/` and `check.sh` against the kit. Promote any rule the reviewer keeps catching into a mechanical check. |
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

**First-month experiment** (if Fable is available to you): the same five diffs through the reviewer under **standard** and **max**. Count findings you agreed with and the cost of each run. Pick the profile from the result and record it in `docs/decisions.md`.

## Token and cost discipline

- `CLAUDE.md` is loaded every turn; every line costs on every call. Keep it an index.
- Subagents load `CLAUDE.md` and a git-status snapshot automatically. The planner, reviewer and auditor set `omitClaudeMd: true` and read only what their Setup lists; the writer keeps `CLAUDE.md` because it needs the commands.
- Small fixes skip the planner and writer: main session plus reviewer is two contexts instead of four.
- The planner and reviewer are read-only and bounded; the writer is where cost accumulates. Give it a blueprint so it does not re-decide.
- Mechanical checks are free. Anything grep can find should never reach a model.
- Prefer one round of a stronger reviewer over three rounds of a weaker one.
