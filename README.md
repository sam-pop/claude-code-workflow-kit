# Claude Kit

A drop-in working system for AI-assisted development with [Claude Code](https://claude.com/claude-code). You install it into a repo, a Claude Code session tailors it to that repo's stack, and from then on every change runs through a short, checkable process instead of a long chat.

It is built for people who **review code more than they write it**: tech leads, fractional CTOs, solo founders running several codebases. It optimises for fewer tokens, fewer silent decisions by the model, and a written trail of what was checked.

## The idea in six rules

1. **Mechanical before judgment.** Anything a tool can check lives in `scripts/check.sh` (lint, types, tests, secret scan, SAST), never in a prompt. Models only get what needs judgment.
2. **Decisions have one home.** `docs/decisions.md` holds what's decided; `docs/open.md` holds what isn't, with IDs. Agents never pick a value for an open item; they flag it.
3. **Few agents, clear handoffs.** A planner (read-only) writes one decisive blueprint, a writer implements and verifies, a reviewer (read-only) reports findings with confidence. A security auditor joins on sensitive work.
4. **Honest reports.** The writer says "unverified" when it couldn't run a check, and lists the defaults it picked that nobody specified. The reviewer only reports at 85%+ confidence and separates *Standards* (does it follow the rules) from *Spec* (does it do what was asked).
5. **`CLAUDE.md` is an index, not a log.** Capped at 150 lines and checked in CI. It's loaded on every turn; every line costs on every call.
6. **The kit has to earn its place.** Metrics and kill criteria are written down before you start (`docs/rollout.md`). If it isn't lowering your hours per change or your escaped defects, you shrink it.

## Quick start

```bash
git clone https://github.com/<you>/claude-kit
claude-kit/scripts/install.sh /path/to/your-repo   # never overwrites; existing files get a .kit twin
cd /path/to/your-repo && claude
```

Then tell Claude Code:

> Read TAILOR.md and tailor the kit to this repo.

It explores the repo, asks you one round of questions (each with a recommended answer), fills every placeholder, writes stack-specific lint rules, deletes what doesn't apply, runs `scripts/check.sh all`, and reports. Review the result and commit.

**Recommended once per machine:**

```bash
claude plugin install mattpocock-skills@claude-plugins-official   # companion skills, see HOW-TO-USE.md
brew install gitleaks && pip install semgrep                      # used by check.sh security
```

Full usage, daily commands and upkeep: **[HOW-TO-USE.md](HOW-TO-USE.md)**.

## Tiers

Pick one per repo; the tailoring session asks.

| Tier | When | What you get |
|---|---|---|
| Script | Automations, glue code | `CLAUDE.md`, `check.sh`, short conventions |
| Solo | One engineer, low blast radius | Writer + reviewer, planner for big work |
| Shared | Client work, money or personal data, a second contributor | Everything, reviewer required before merge, security auditor before releases |
| Review-only | Other people write the code; you are the reviewer of record | Reviewer + security auditor on their PRs, nothing else |

## What's inside

| Path | Purpose |
|---|---|
| `TAILOR.md` | Instructions for the session that adapts the kit to a repo. Deleted after tailoring |
| `HOW-TO-USE.md` | Install, daily commands, what you own, monthly upkeep |
| `CLAUDE.md` | Template for the repo's index: stack, commands, layout, rules, workflow |
| `docs/conventions.md` | Architecture rules and anti-patterns; each row is *mechanical* (named check) or *judgment* (reviewer) |
| `docs/decisions.md` · `docs/open.md` | Decided vs undecided, with IDs |
| `docs/glossary.md` | The project's shared terms; one word instead of a sentence, in code and prompts |
| `docs/rollout.md` | Tiers, cadence, metrics, kill criteria, token discipline |
| `docs/reviews/` | Review log, written automatically; you mark findings fixed, dismissed or deferred |
| `handoff.md` | Session-to-session state, rewritten at the end of each session |
| `.claude/agents/` | `planner`, `writer`, `reviewer`, `security-auditor` |
| `.claude/settings.json` | Hooks: block destructive git, lint after edits, save review reports, handoff reminder |
| `scripts/check.sh` | The one verification entry point: `lint`, `test`, `build`, `security`, `doctor`, `all` |
| `scripts/doctor.sh` | Kit hygiene: `CLAUDE.md` size, leftover placeholders, orphan open-item IDs, review stats |
| `scripts/capture-review.sh` · `block-dangerous-git.sh` | Hook scripts |
| `scripts/install.sh` | Copies the kit into a repo without overwriting |
| `.github/workflows/check.yml` | CI runs `check.sh all` |

## How it gets better

Every reviewer and auditor report is saved to `docs/reviews/`. You mark each finding. Once a month `scripts/check.sh doctor` surfaces what keeps recurring: a finding seen three times becomes a lint rule, a dismissal seen twice becomes an entry in the reviewer's false-positives list. Thresholds are fixed in advance so the loop can't drift, and the human approves every change to the rules.

## Status

v1.2, early. The structure is drawn from a working multi-agent setup on a production mobile app; this generic version has not yet been tailored against many stacks, so expect the first `TAILOR.md` run on your repo to find something to fix. The hook scripts read fields from Claude Code's hook input that are still being verified against current docs; check the [hooks](https://docs.claude.com/en/docs/claude-code/hooks) and [subagents](https://docs.claude.com/en/docs/claude-code/sub-agents) references if something doesn't fire.

Issues and pull requests welcome, especially tailored `conventions.md` examples for specific stacks.

## Credits

- The grilling question format, the two-axis review, the test anti-patterns, the agent-writing guidance and the git guardrail hook are adapted from [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). Install that plugin alongside this kit; they're designed to complement each other.

## License

[MIT](LICENSE)
