# Rollout and maintenance

## Tiers

Pick one per repo. The tailoring session asks which.

| Tier | When | Kit pieces | `handoff.md` | Reviewer model |
|---|---|---|---|---|
| **Script** | Automations, one-file tools, glue | `CLAUDE.md`, `check.sh`, conventions (short) | none | none; `check.sh` only |
| **Solo** | One engineer, side product, low blast radius | Full docs, writer + reviewer; planner only for work over a day | git-ignored | Opus |
| **Shared** | Client work, a second contributor, money or personal data in play | Everything; planner on anything beyond a small fix; reviewer required before merge; security auditor on sensitive changes, before each release and quarterly | committed, or mirrored to the issue tracker | Fable |
| **Review-only** | Other people write the code (a contractor team, an agency); you are the reviewer of record | `CLAUDE.md`, conventions, `check.sh`, reviewer + security auditor only. No planner, no writer. The reviewer runs on each PR with the PR description as data; your two lists encode what you keep catching in *their* work | none | Fable |

`check.sh security` (secret scan, dependency audit, SAST) runs at every tier; the auditor agent is Shared and Review-only.

Review-only is often the highest-value tier for a fractional CTO: the kit becomes your review arm, and the review log becomes the written trail a client can see.

Move a repo up a tier when someone else touches it or when a mistake would cost a client. Rarely move down.

## Rollout order

1. Tailor the kit on the most active repo and work in it for two weeks before touching another.
2. Fold what you had to fix back into the kit. The kit is wrong until a real repo has corrected it at least once.
3. Roll out to the next repo. Repeat.
4. Keep the kit in its own repo so every target repo can diff against it.

## Cadence

| When | Do |
|---|---|
| Every session end | Rewrite `handoff.md`. Move any decision made into `decisions.md`; any new question into `open.md`. |
| Every merge | Reviewer findings recorded with what was done about each. Spot-check one finding the reviewer did *not* raise. |
| Monthly | `CLAUDE.md` under 150 lines; prune. Diff `.claude/agents/` and `check.sh` against the kit. Promote any rule the reviewer keeps catching into a mechanical check. |
| Before each release (Shared) | Run the security auditor. Critical/High fixed or explicitly accepted in `docs/decisions.md`. |
| Quarterly | Reread the reviewer's "Subtle violations" and "False positives" lists; drop what no longer fires, add what you have corrected twice. Run the security auditor on Shared repos even if nothing sensitive changed. |

## Pre-committed tests of the kit itself

Decide these before the first repo, so the kit cannot talk you into keeping it.

**Metrics** (record monthly in the kit repo's `METRICS.md`, one line per repo):

1. **Escaped defects** — bugs found after merge, per month. The only metric that measures correctness.
2. **Agreement rate** — reviewer findings you fixed ÷ findings raised. Below 50% means the reviewer is noise; above 90% means it is only finding the easy stuff.
3. **Hours per merged change** — your time, blueprint to merge. The kit must lower this or it is overhead dressed as rigor.

**Kill criteria**:

- No finding marked (fixed or dismissed) in `docs/reviews/` for 30 days → delete the loop (capture hook, review log, monthly pass). Keep hooks, `check.sh` and the agents.
- Agreement rate under 40% for two months → drop the reviewer to a lint-only gate and rethink the two lists.
- Hours per change not down after 60 days on the first repo → stop rolling out; fix or shrink the kit first.

**Experiment to run in the first month**: the same five diffs through the reviewer on Opus and on Fable. Count findings you agreed with and the cost. Pick the model from the result, not from belief, and record it in `docs/decisions.md`.

## Token and cost discipline

- `CLAUDE.md` is loaded every turn; every line costs on every call. Keep it an index.
- Agents read `conventions.md` and the blueprint, not the whole `docs/` tree.
- The planner and reviewer are read-only and bounded; the writer is where cost accumulates. Give it a blueprint so it does not re-decide.
- Mechanical checks are free. Anything grep can find should never reach a model.
- Prefer one round of a stronger reviewer over three rounds of a weaker one.
