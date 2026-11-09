# Claude model lineup and Claude Code effort levels (as of November 2026)

Scope note: research done 2026-11-09. Primary sources are Anthropic's docs (platform.claude.com, code.claude.com) and launch pages (anthropic.com). WebFetch returns model-summarized page content, so wording is paraphrased; numbers were checked against the raw page text where the full page was saved (Effort and Pricing pages). Third-party benchmark numbers come from secondary aggregators and are labeled as such. Anything about Opus 5 / Sonnet 5 / Fable 5 / 4.x models is previous-generation data and is labeled.

Current lineup (Nov 2026), per the Claude Code model docs and API pricing page:
- **Claude Fable 5.1** (`claude-fable-5-1`): the most capable model that is widely released. It is never the default; you select it explicitly.
- **Claude Mythos 5.1** (`claude-mythos-5-1`): same price as Fable 5.1, limited availability (verification programs and Project Glasswing only).
- **Claude Opus 5.5** (`claude-opus-5-5`): the default model in Claude Code on Pro/Max/Ultra/Team/Enterprise/API. Launched 2026-09-22.
- **Claude Sonnet 5.5** (`claude-sonnet-5-5`): launched 2026-09-28.
- **Claude Haiku 5.5** (`claude-haiku-5-5`): launched 2026-10-07, per secondary coverage.
- Still served (previous generation): Fable 5, Opus 5, Opus 4.8/4.7/4.6, Sonnet 5, Sonnet 4.6, Haiku 4.5.

---

## Q1. API prices for each current model, and how Fable is billed on Claude subscription plans

### Takeaway
Per MTok (input / output / cache read): Fable 5.1 is $10 / $50 / $0.25, Opus 5.5 is $4 / $20 / $0.20, Sonnet 5.5 is $2 / $10 / $0.10, and Haiku 5.5 is $0.10 / $0.50 / $0.01 for prompts up to 100K tokens (5x that above 100K). Output costs 5x input on all four. On subscriptions, Fable does not come out of the Pro or standard Team seat allowance; those users pay for it with usage credits from the first request. Max plans and premium Team/Enterprise seats can reportedly spend up to 50% of their weekly limit on Fable before credits apply.

### Cited Findings
**API list prices (USD per million tokens; first-party Claude API)** — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)

| Model | Input | 5m cache write | 1h cache write | Cache hit/refresh | Output |
|---|---|---|---|---|---|
| Fable 5.1 | $10 | $12.50 | $20 | $0.25 (0.025x input) | $50 |
| Mythos 5.1 (limited availability) | $10 | $12.50 | $20 | $0.25 | $50 |
| Fable 5 (prev.) | $10 | $12.50 | $20 | $1.00 | $50 |
| Opus 5.5 | $4 | $5 | $8 | $0.20 (0.05x input) | $20 |
| Opus 5 / 4.8 / 4.7 / 4.6 (prev.) | $5 | $6.25 | $10 | $0.50 | $25 |
| Sonnet 5.5 | $2 | $2.50 | $4 | $0.10 (0.05x input) | $10 |
| Sonnet 5 (prev.) | $2 | $2.50 | $4 | $0.20 | $10 |
| Sonnet 4.6 (prev.) | $3 | $3.75 | $6 | $0.30 | $15 |
| Haiku 5.5, prompt ≤100K tokens | $0.10 | $0.125 | $0.20 | $0.01 | $0.50 |
| Haiku 5.5, prompt >100K tokens | $0.50 | $0.625 | $1.00 | $0.05 | $2.50 |
| Haiku 4.5 (prev.) | $1 | $1.25 | $2 | $0.10 | $5 |

- Cache multipliers: cache hits on Fable 5.1 and Mythos 5.1 cost 0.025x base input, and on Opus 5.5 and Sonnet 5.5 they cost 0.05x. All other models use the standard 0.1x. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Haiku 5.5 tiering: a prompt is measured by all of its input tokens, including cache reads and writes. A request over 100,000 tokens pays the higher rate on everything, even if part of it was a cache hit. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing). Anthropic's cost guide puts it this way: "past 100,000 tokens, every token of the request costs 5 times as much, output included." — [Cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence.md)
- Long context: Claude 4.6 and later models, except Haiku 5.5, bill the full 1M context window at standard rates. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Batch API takes 50% off input and output (for example, Haiku 5.5 at ≤100K is $0.05 / $0.25). — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Fast mode on Opus 5.5 costs $8 / $40 per MTok (2x standard) and delivers up to 2.5x output tokens per second. On Opus 5 / 4.8 it costs $10 / $50. It cannot be used with the Batch API. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing); [Opus 5.5 launch](https://www.anthropic.com/news/claude-opus-5-5)
- Data residency: `inference_geo: "us"` multiplies all token categories by 1.1x on Claude 4.6 and later models. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Tokenizer: Claude 4.7 and later models use a tokenizer that produces about 30% more tokens for the same text. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- Opus 5.5 vs Opus 5 (prev.): $4/$20 against $5/$25, cache reads $0.20 against $0.50. Anthropic claims about 40% lower cost "on typical workloads at default settings." — [Opus 5.5 launch](https://www.anthropic.com/news/claude-opus-5-5)
- Sonnet 5.5 is "up to 30% less per task than Sonnet 5" and produces output more than 30% faster. — [Sonnet 5.5 page](https://www.anthropic.com/claude-sonnet-5-5)
- Sonnet 5 (prev.): the $2/$10 price announced as introductory became the standard price, and the planned 2026-09-01 increase to $3/$15 was cancelled. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing)

**Fable on subscription plans / usage credits**
- In Claude Code, Fable may be billed to usage credits instead of plan limits, depending on plan and seat tier. The `/model` picker labels the Fable row "Requires usage credits", and interactive sessions show a one-time consent prompt. — [Claude Code model config](https://code.claude.com/docs/en/model-config.md)
- In `-p` (non-interactive) mode, Claude Code bills Fable to credits **without asking**. In Remote Control, background, or teammate sessions, the consent prompt waits up to `dialogExpiry` (5 minutes by default). If nobody answers, the turn ends without sending the request. — [Claude Code model config](https://code.claude.com/docs/en/model-config.md)
- No plan or provider defaults to Fable; it must be selected with `/model fable` or `--model fable`. The `best` alias resolves to Fable where it is available and to Opus otherwise. — [Claude Code model config](https://code.claude.com/docs/en/model-config.md)
- Pro and standard Team seats: "Fable 5 and Fable 5.1 are not included in your plan's usage limits" (quoted from the Anthropic help center). Access requires usage credits. — [Notebookcheck](https://www.notebookcheck.net/Claude-Fable-5-1-is-not-included-in-your-Pro-subscription.1385320.0.html)
- Max, and premium Team/Enterprise seats: up to 50% of the weekly limit can go to Fable at no extra charge. This draws from the same weekly limit (it is not extra allowance), and Fable uses it up faster. — [Notebookcheck](https://www.notebookcheck.net/Claude-Fable-5-1-is-not-included-in-your-Pro-subscription.1385320.0.html); same claim in [vanja.io](https://vanja.io/fable-5-1-in-your-max-plan-not-free/) (secondary). I did not see the Anthropic help article "Claude Fable models on your plan" myself.
- Credits are billed at API rates. On Pro/Max/Ultra, `/usage-credits` opens claude.ai Settings > Usage, where you set a monthly spend limit. — [Claude Code costs](https://code.claude.com/docs/en/costs.md)
- Fable's safety classifiers (mostly cybersecurity and biology) can route a flagged request to another model, which keeps the same effort level. — [Claude Code model config](https://code.claude.com/docs/en/model-config.md). On Opus 5.5, "most cybersecurity tasks are rerouted to Opus 4.8." — [Opus 5.5 launch](https://www.anthropic.com/news/claude-opus-5-5)

### Inferences
- Running a security-auditor role on Fable or Opus 5.5 may hit cyber-classifier fallbacks: Opus 5.5 reroutes most cyber tasks to Opus 4.8, and Fable falls back to another model. In practice the security role may run on a different model than the one configured.
- Any Fable-backed role run headless (`claude -p`, CI) spends credits silently. A kit that defaults any role to Fable needs to flag this.
- Opus 5.5's 0.05x cache-read rate makes long, cache-heavy agent loops much cheaper on Opus 5.5 than on Opus 5 (prev.).

### Gaps
- I found no Anthropic-hosted page I could read that states the "50% of Max weekly limit" Fable cap. It comes from secondary sources quoting the help center.
- I could not confirm the exact Fable 5.1 launch date. The Anthropic news URL `/news/claude-fable-5-1` returned 404. Secondary coverage suggests about 2026-08-31.
- Haiku 5.5's launch date (2026-10-07) comes from secondary sources only.

---

## Q2. How Claude Code's `effort` setting works: what it changes, per-model defaults, and how to set it

### Takeaway
Effort is a behavioral signal, not a hard budget. It scales every output token: how often and how deeply the model thinks, how many tool calls it makes and how terse they are, and how verbose the text is. On the 5.5 generation and Fable, thinking is always on and cannot be disabled, so effort is the only reasoning control. Claude Code defaults to `medium` on Opus 5.5, Sonnet 5.5, and Haiku 5.5, and to `high` on Fable 5.1. Effort can be set from an env var (highest precedence), `/effort`, `--effort`, settings, subagent/skill frontmatter, and the Agent tool's per-call `effort` parameter.

### Cited Findings
**What effort does (API semantics)**
- Effort applies to **all tokens** in the response (thinking, text, tool calls), so it works with or without thinking. "Lower effort also means fewer and terser tool calls." — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- "Effort is a behavioral signal, not a strict token budget. At lower effort levels, Claude still thinks on sufficiently difficult problems, but thinks less than it would at higher effort levels." — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- Level descriptions — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md):
  - `max`: "Absolute maximum capability with no constraints on token spending." For the deepest reasoning.
  - `xhigh`: "Long-running agentic and coding tasks (over 30 minutes) with token budgets in the millions."
  - `high`: complex reasoning, difficult coding, agentic tasks.
  - `medium`: "Agentic tasks that require a balance of speed, cost, and performance."
  - `low`: "Simpler tasks that need the best speed and lowest costs, such as subagents."
- Lower effort gives "fewer and more-consolidated tool calls, less preamble, and terser confirmations." — Claude API reference skill bundled with Claude Code 2.1.319 (cached 2026-10-06), consistent with the [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md) page.
- Thinking cannot be turned off on Opus 5.5, Sonnet 5.5, Haiku 5.5, or the Fable models, so `MAX_THINKING_TOKENS=0` and `alwaysThinkingEnabled: false` do nothing on them. — [Claude Code model config](https://code.claude.com/docs/en/model-config.md); [Claude Code costs](https://code.claude.com/docs/en/costs.md)
  - API detail: on Opus 5.5, `thinking: {type:"disabled"}` returns a 400 at every effort level. — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
  - Sonnet 5.5 offers `thinking: {type:"between_tools"}` as its lowest setting, valid only at effort `high` or below. — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
  - Haiku 5.5 accepts `disabled` at `high` or below. — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)

**Default effort by model**

| Model | API default | Claude Code default | Source |
|---|---|---|---|
| Fable 5.1 | `high` | `high` ("most models") | [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md); [CC model config](https://code.claude.com/docs/en/model-config.md) |
| Opus 5.5 | `medium` | `medium` | same |
| Sonnet 5.5 | `high` (Claude Platform) | `medium` (Claude Code and Claude apps) | [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md); [Sonnet 5.5 page](https://www.anthropic.com/claude-sonnet-5-5); [CC model config](https://code.claude.com/docs/en/model-config.md) |
| Haiku 5.5 | `medium` | `medium` | same |
| Opus 5 / Sonnet 5 (prev.) | `high` | `high` | [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md) |
| Opus 4.7 (prev.) | `high` | `xhigh` | [CC model config](https://code.claude.com/docs/en/model-config.md) |

- Supported levels: Fable 5.1, Opus 5.5, Sonnet 5.5, and Haiku 5.5 all support `low`, `medium`, `high`, `xhigh`, `max`. Opus 4.6 and Sonnet 4.6 (prev.) have no `xhigh`. If you set a level the model doesn't support, Claude Code uses the highest supported level below it (for example, `xhigh` runs as `high` on Opus 4.6). — [CC model config](https://code.claude.com/docs/en/model-config.md)
- An organization's default model can carry its own default level. — [CC model config](https://code.claude.com/docs/en/model-config.md)

**How to set effort in Claude Code**
- Resolution order, first match wins — [CC model config](https://code.claude.com/docs/en/model-config.md):
  1. `CLAUDE_CODE_EFFORT_LEVEL` env var
  2. Level picked in the session (`/effort`, the `/model` slider, `applyFlagSettings()`)
  3. `--effort` CLI flag
  4. Settings: per-model `modelSettings` or the `effortLevel` key
  5. Model default
- Commands: `/effort` (slider), `/effort high`, `/effort auto` (clears the saved level). In the slider, `Enter` saves the level as default and `s` applies it to the current session only (v2.1.257+). — [CC model config](https://code.claude.com/docs/en/model-config.md)
- `CLAUDE_CODE_EFFORT_LEVEL=auto` (or `unset`) sends no level, so the API default applies. — [CC model config](https://code.claude.com/docs/en/model-config.md)
- Settings keys: `effortLevel` accepts `low`/`medium`/`high`/`xhigh`. Neither `effortLevel` nor `modelSettings` accepts `max`. `max` lasts for the current session only, unless set through the env var. — [CC model config](https://code.claude.com/docs/en/model-config.md)
- "A top-level `effortLevel` in user settings doesn't apply to Opus 5.5" (it still applies to Opus 5, Fable 5.1, and earlier models). For Opus 5.5, use per-model `modelSettings`. — [CC model config](https://code.claude.com/docs/en/model-config.md)
- Managed caps: `maxEffortLevel`, or per-role limits on Enterprise. When both apply, the lower cap wins. — [CC model config](https://code.claude.com/docs/en/model-config.md)
- `ultrathink` in a prompt raises deeper reasoning for that turn only. Typed in the terminal (v2.1.311+), it can raise the turn to `xhigh`. Phrases like "think hard" are not keywords. — [CC model config](https://code.claude.com/docs/en/model-config.md)
- `ultracode` is a separate setting, not an effort level. It makes Claude orchestrate dynamic workflows. `claude --effort ultracode` starts at `xhigh` with ultracode on. — [CC model config](https://code.claude.com/docs/en/model-config.md)

**Subagents: frontmatter, Agent tool, env vars** — [Claude Code subagents](https://code.claude.com/docs/en/sub-agents.md)
- Frontmatter `model`: `sonnet`, `opus`, `haiku`, `fable`, a full ID such as `claude-opus-5-5`, or `inherit`.
- Frontmatter `effort`: `low`, `medium`, `high`, `xhigh`, `max`, subject to what the model supports. Example:
  ```yaml
  ---
  name: repo-auditor
  description: Audits a large repository and reports what it finds
  model: haiku
  effort: low
  ---
  ```
- Effort precedence: `CLAUDE_CODE_EFFORT_LEVEL` > Agent tool per-invocation `effort` (v2.1.292+; persists across resume) > frontmatter `effort` > session level.
- With no effort field or parameter, a subagent on the **main conversation's model** uses the session level. A subagent on **a different model** does not get the session level; it falls back to that model's default.
- Model resolution:
  1. Agent tool `model` parameter
  2. Frontmatter `model` (`inherit` = main model)
  3. `CLAUDE_CODE_SUBAGENT_MODEL`
  4. Main conversation model
  - Before v2.1.251, the env var took precedence over the other two.
- The Agent tool can pass `model` only as an alias (`sonnet`/`opus`/`haiku`/`fable`), never as a full ID or `inherit`. It can pass `effort` only for non-fork subagents.
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) forces one model onto every subagent and ignores frontmatter.
- Built-in subagents:
  - Explore runs on whatever the `opus` alias resolves to (on subscription, Console, or gateway).
  - Plan inherits the main model.
  - general-purpose uses the env var or the main model.
  - statusline-setup uses Sonnet; claude-code-guide uses Haiku.
- Extended thinking is inherited from the main conversation; there is no per-subagent thinking setting.
- `/tasks` shows the model and effort of a running subagent.
- Skill frontmatter `effort` lasts for its turn, or for the whole run with `context: fork`. — [CC model config](https://code.claude.com/docs/en/model-config.md)

**Aliases by provider** — [CC model config](https://code.claude.com/docs/en/model-config.md)
- On the Anthropic API, `opus` resolves to Opus 5.5, `sonnet` to Sonnet 5.5, and `haiku` to Haiku 5.5.
- On Bedrock and Google Cloud, `sonnet` resolves to Sonnet 4.5 and `haiku` to Haiku 4.5.
- On Claude Platform on AWS, `sonnet` resolves to Sonnet 4.6.
- On Foundry, `opus` resolves to Opus 4.6.
- `opusplan` runs Opus in plan mode and Sonnet for execution.

**Changing effort mid-conversation (API)**
- Per-message effort (beta `mid-conversation-output-config-2026-07-01`) works on Fable 5.1, Opus 5.5, Sonnet 5.5, and Haiku 5.5 and keeps the prompt cache. — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- A top-level effort change resets the cache and, on Fable 5.1, "steers the model less reliably." — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- A top-level effort change on a cached conversation of about 100K tokens cost up to $1.02 USD, 20 to 40 times the per-message form. — [Cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence.md)

### Inferences
- In a kit, the reliable way to pin per-role effort is the subagent frontmatter `effort:` plus `model:`. Two caveats:
  - A user's `CLAUDE_CODE_EFFORT_LEVEL` silently overrides every role.
  - A role on a different model than the main session does not inherit `/effort`.
- Because `effortLevel` in user settings is ignored for Opus 5.5, kit docs telling users to set `effortLevel` globally will not affect an Opus 5.5 main session. Point them to `modelSettings` or `/effort`.
- The defaults differ between Sonnet 5.5 in Claude Code (`medium`) and on the API (`high`), so benchmark numbers quoted "at default" on the API may be one level above what Claude Code runs.

### Gaps
- The docs do not give a token or thinking-budget figure for each effort level. Effort is described only behaviorally.
- I did not confirm the exact `modelSettings` JSON shape (the page was summarized). Check the settings reference before writing kit config.

---

## Q3. Benchmark results by effort level, with token use and latency

### Takeaway
Anthropic's own per-effort data (SWE-bench Pro subset) shows Opus 5.5 at:
- `low`: 87.4%, $0.11/task
- `medium` (default): 92.8%, $0.21/task
- `high`: 95.3%, $0.29/task
- `xhigh`: 96.7%, $0.74/task

Opus 5.5 at `medium` matched Fable 5.1 at its default for about a fifth of the cost per solved task. Sonnet 5.5 at its API default (`high`) roughly matched Opus 5.5 at `low` (87.6% vs 87.4%). Anthropic says Opus 5.5 at `medium` matches or exceeds Opus 5 (prev.) at `high`. I found no official SWE-bench Verified numbers for the 5.5 generation.

### Cited Findings
**Anthropic cost/effort study (SWE-bench Pro subset and internal benchmarks)** — all from [Cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence.md). Anthropic calls these internal and directional results.

Opus 5.5 by effort, SWE-bench Pro subset:

| Effort | Solved | Cost/task |
|---|---|---|
| low | 87.4% | $0.11 |
| medium (default) | 92.8% | $0.21 |
| high | 95.3% | $0.29 |
| xhigh (single run) | 96.7% | $0.74 |

Cross-model, SWE-bench Pro subset (cost per solved task):

| Model / effort | Solved | Cost per solved task |
|---|---|---|
| Sonnet 5.5 `high` (API default) | 87.6% | $0.11 |
| Opus 5.5 `low` | 87.4% | $0.12 |
| Opus 5.5 `medium` | 92.8% | $0.22 |
| Fable 5.1 `high` (single run) | 92.3% | $1.19 |

- Internal agentic-coding benchmark: Opus 5.5 `medium` scored 86.6% at $0.84/attempt; Fable 5.1 `medium` scored 84.2% at $2.68/attempt.
- Sonnet 5.5 `medium` vs `high`:
  - SWE-bench Pro subset: about 7 points lower at `medium`, for about 59% of the cost.
  - Internal agentic-coding benchmark: 62.7% vs 77.8%.
  - So `medium` costs Sonnet 5.5 noticeably on coding.
- Opus 5.5 `low` vs `medium` outside coding: DRACO −13.3 pts with 84% less time; HLE −3.4 pts with 30% less time; internal physics −14.0 pts with 47% less time.
- Internal defect-search (bug-finding) benchmark, 10 runs per setting:
  - Opus 5.5 `low` scored **34 points lower** than `medium`, for about a fifth of the cost.
  - Fable 5.1 `low` scored only 1.8 points below `high`, for about a quarter less cost.
- DeepResearch Bench II, Fable 5.1: `low` 60.5% ($3.47), `medium` 60.5% ($4.44), `high` 63.0% ($5.64). At default effort, Opus 5.5 scored +2.6 points over Sonnet 5.5 for 1.5x the cost, and Fable 5.1 scored +6.0 points for 5.8x the cost.
- GPQA Diamond: Haiku 5.5 (`medium`) 85%; Opus 5.5 and Sonnet 5.5 91% each. Haiku costs about 1/20 of Opus 5.5 and about 1/10 of Sonnet 5.5 per correct answer.
- Managed Agents task set (79 tasks): Haiku 5.5 `medium` passed 93% at about $0.011 per passed attempt. Haiku 4.5 (prev.) passed 62%.
- `max_tokens` matters, from an internal repo-task benchmark:
  - Opus 5.5 at a 16,384 cap was cut off on 25% of attempts and solved 57.6%. At 64,000 it solved 75.6%; at 128,000, 68.9%.
  - Fable 5.1 at 16,384 was cut off on 43% of attempts and solved 36.3%; at 64,000, 58.5%.
  - The page recommends 64,000 for agentic work.
- Upgrade deltas (prev. models, SWE-bench Pro subset):
  - Opus 5 `high` → Opus 5.5 `medium`: 91.9% → 92.8%, at 78% less per solved task.
  - Sonnet 5 → Sonnet 5.5: about +10 points, at 87% less per solved task.
  - Fable 5 → Fable 5.1: about the same score, at 43% less.
- Terminal-Bench 3 (prev. models, `high`): Opus 4.7 → 4.8 went from 7% to 15%; Opus 4.8 → Opus 5 from 15% to 41% ($63 → $28 per solved task).

**Launch-post benchmarks (Anthropic)**
- Opus 5.5 — [Opus 5.5 launch](https://www.anthropic.com/news/claude-opus-5-5). Max effort unless noted:

  | Benchmark | Opus 5.5 | Opus 5 (prev.) | Note |
  |---|---|---|---|
  | Terminal-Bench 4.0 | 66.4% | 52.3% | Opus 5.5 at `xhigh` |
  | FrontierCode v1.1 Main | 54.4% | 48.0% | 54.6% at `medium` per the text |
  | CursorBench 4.0 | 57.8% | 46.6% | 52.5% at `medium` |
  | GDPval-AA v2.1 | 1846 Elo | 1708 | |
  | HLE with tools | 67.7% | 63.6% | |
  | OSWorld 2.1 | 81.8% | 74.0% | |
  | Terminal-Bench-Science 0.1 | 58.7% | 29.0% | |

  - The page does not report SWE-bench Verified or SWE-bench Pro.
- Opus 5.5 effort statements from the launch post — [Opus 5.5 launch](https://www.anthropic.com/news/claude-opus-5-5):
  - "At default (medium) effort, Opus 5.5 beats Opus 5 at max effort on Terminal-Bench 4.0 for about a fifth of the cost."
  - On CursorBench, Opus 5.5 at `medium` (52.5%) edges Fable 5.1 at `max` (51.8%).
  - Customer reports:
    - Factory: Opus 5.5 `medium` matched Opus 5 `high` with 20–25% fewer output tokens.
    - Deloitte: Opus 5.5 at lowest effort caught 72% of known bugs, against 56% for Opus 5 at `high`.
    - Rogo: lowest effort beat Opus 5 `high` with about 60% fewer output tokens.
  - Output is more than 30% faster than Opus 5.
- Claude Code docs: "Opus 5.5 at `medium` reportedly matches or exceeds Opus 5 at `high` on coding and knowledge-work evaluations. When moving from Opus 5 to Opus 5.5, start at `medium`." — [CC model config](https://code.claude.com/docs/en/model-config.md)
- Sonnet 5.5 — [Sonnet 5.5 page](https://www.anthropic.com/claude-sonnet-5-5):
  - Scores: Terminal-Bench 4.0 70.6% (effort not stated; Sonnet 5 10.3%); FrontierCode 46.2% at `max`; CursorBench 55.5%; GDPval-AA 1844 (Opus 5.5 1846); OSWorld 2.1 80.1%; HLE with tools 64.5%.
  - Sonnet 5.5 at `medium` "far exceeds Sonnet 5's best score [Terminal-Bench 4.0] for under a tenth of the cost per task."
  - At `low` on CursorBench it beats Sonnet 5's best for under a tenth of the cost.
  - Its FrontierCode score is lower at `max` than at `xhigh`, because extra subagent code-review runs caused timeouts and out-of-scope edits.
- Fable 5.1: the Anthropic launch page could not be fetched (404). Secondary sources give Terminal-Bench-Science 0.1 at 52.6% — [Vellum](https://www.vellum.ai/blog/claude-fable-5-1-mythos-5-1-benchmarks-explained) (secondary).

**Independent / secondary trackers (lower confidence)**
- Opus 5.5 SWE-bench Pro 89.9%, SWE-bench Multilingual 93.9%, Multimodal 61.4%, via search-result aggregation over [benchlm.ai](https://benchlm.ai/models/claude-opus-5-5) and [benchmarklist.com](https://benchmarklist.com/models/anthropic-claude-opus-5.5/). Not verified against an Anthropic source.
- Opus 5.5 on Terminal-Bench 4.0: about 57.5% at `medium` (about $3/attempt), 64.8% at `max`, an independent 59.6%, and 63.1% in the Claude Code harness. These come from mixed aggregator sources ([llm-stats](https://llm-stats.com/blog/research/claude-opus-5-5-launch), [orcarouter](https://www.orcarouter.ai/blog/claude-opus-5-5-benchmark), [benchlm](https://benchlm.ai/md/models/claude-opus-5-5.md)) and conflict with each other.
- Artificial Analysis: Sonnet 5.5 was #1 on the Coding Agent Index (68) and #2 on the Intelligence Index (56) at launch. Haiku 5.5 scored 43 on the Intelligence Index (13th). Fable 5.1 (xhigh) is listed at 50 on AA's release page, which conflicts with another source's 66. — via search summaries citing [the-decoder](https://the-decoder.com/anthropics-claude-sonnet-5-5-nearly-matches-opus-5-5-on-benchmarks-while-costing-up-to-30-percent-less-per-task/), [computingforgeeks](https://computingforgeeks.com/claude-haiku-5-5-released-features-benchmarks/), and [Artificial Analysis](https://artificialanalysis.ai/models/releases/claude-fable-5-1). Not verified directly.

### Inferences
- **Writer/implementer role:**
  - Opus 5.5 `medium` (92.8%, $0.21) is the cost-effective default.
  - Opus 5.5 `high` buys +2.5 points for about 40% more cost.
  - `xhigh` buys another +1.4 points for 2.5x the cost of `high`.
  - Sonnet 5.5 `high` matches Opus 5.5 `low` for about the same cost per solved task.
- **Reviewer / security-auditor (defect finding):**
  - Opus 5.5 at `low` collapses on defect search (−34 points vs `medium`), so review roles should not run Opus 5.5 below `medium`.
  - Fable 5.1 is much less sensitive to effort here (−1.8 points at `low`).
- **Sonnet 5.5 roles:** Sonnet 5.5 loses much more going from `high` to `medium` on agentic coding (−15 points on the internal benchmark). Since Claude Code defaults Sonnet 5.5 to `medium`, a Sonnet-based writer or reviewer should likely be pinned to `high`.
- **Max effort:** the Sonnet 5.5 FrontierCode drop at `max` and the `max_tokens` results suggest `max` is risky as a default.

### Gaps
- I found no Anthropic-published SWE-bench Verified score for Fable 5.1, Opus 5.5, Sonnet 5.5, or Haiku 5.5.
- I found no official per-effort latency numbers (seconds) for coding tasks. The only time data is relative, from DRACO, HLE, and the physics set.
- I found no per-effort tokens-per-task tables, only dollar costs per task.
- I found no Haiku 5.5 coding benchmarks from Anthropic (SWE-bench, Terminal-Bench).
- Fable 5.1 by-effort coding data: only one run at `high` on the SWE-bench Pro subset, and one at `medium` on the internal benchmark.

---

## Q4. Anthropic's guidance on which effort to use for which task

### Takeaway
Anthropic's starting points:
- Opus 5.5 at `medium` is the default for most agent work. Raise it for hard tasks.
- Fable 5.1 at `high` is for frontier and long-horizon work.
- Sonnet 5.5 starts at `medium` for well-specified agentic coding and `high` for harder tasks.
- Haiku 5.5 starts at `medium`, with `low` for simple, high-volume subagents.
- Use `xhigh`/`max` only where evals show a gain.
- A cheaper policy that matches all-`high`: run at a low level and re-run only the failures at `high`.

### Cited Findings
- Starting points — [Cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence.md):
  - Default for most agent workloads: Opus 5.5 at default effort (`medium`).
  - High-volume work with checkable outputs: try Haiku 5.5.
  - Frontier or long-horizon work: Fable 5.1, or Opus 5.5 at higher effort.
  - "Compare on cost per completed task, not per token."
- Fable 5.1: "Start with `high`, the default. Step up to `xhigh` or `max` for the most capability-sensitive agentic and coding work, and step down to `medium` or `low` for routine or latency-sensitive work once your evals show quality holds." Set a large `max_tokens`. — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- Opus 5.5: `medium` is the default; "run an effort sweep on your own evals rather than carrying settings over"; set a large `max_tokens` at higher levels. — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- Sonnet 5.5: "For agentic coding and multistep tool use, start with `medium` for well-specified tasks and move to `high` for harder or longer ones. For chat… `medium` or `low`. Use `xhigh` or `max` only where your evals show a quality gain." For agentic coding, set `max_tokens` to 128,000. — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- Haiku 5.5: "Start with `medium` for most work, including agentic coding. Use `low`… for chat, short tool tasks, and simple, high-volume requests. In long agent prompts, the model is more likely to skip a search, stop early, or skip a check at `low`. Use `high` for knowledge work, longer agent tasks, and strict instruction following." — [Effort](https://platform.claude.com/docs/en/build-with-claude/effort.md)
- Claude Code guidance by level — [CC model config](https://code.claude.com/docs/en/model-config.md):
  - `low`: quick exchanges you review closely, small changes.
  - `medium`: day-to-day work with clear scope.
  - `high`: "work where verification matters, such as bug fixes in existing code."
  - `xhigh`: deeper reasoning at higher token cost.
  - `max`: hard problems; "may show diminishing returns and overthinking, so test before using it broadly."
- Re-running failures at higher effort, Opus 5.5 on the SWE-bench Pro subset — [Cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence.md):

  | Policy | Solved | Cost/task |
  |---|---|---|
  | `low`, failures re-run at `high` | ≈97% | ≈$0.17 |
  | `medium`, failures re-run at `high` | ≈97% | ≈$0.24 |
  | Everything at `high` | 95.3% | $0.29 |

  - Anthropic summarizes this as "about 40% lower cost than everything at `high`, at the same pass rate." It requires a failure signal such as tests.
- Orchestrator/subagent findings — [Cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence.md):
  - Opus 5.5 with Sonnet 5.5 subagents cost about a third less than an Opus 5.5 session, with about the same defect-search score.
  - Fable 5.1 as orchestrator cost 24% more with no gain.
  - Haiku 5.5 subagents under Opus 5.5 `medium` cost 32% less per attempt, with the pass rate about 4 points lower.
- Advisor pattern (Opus 5.5 `high` + Fable 5.1 advisor): +1.7 points, at the edge of noise, for about 2.1x the cost. — [Cost and intelligence](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence.md)
- Claude Code cost docs:
  - "Sonnet handles most coding tasks well and costs less than Opus. Reserve Opus for complex architectural decisions or multi-step reasoning."
  - Use `model: haiku` for simple subagent tasks.
  - Use Sonnet for agent-team teammates.
  - [Claude Code costs](https://code.claude.com/docs/en/costs.md). This general guidance predates the 5.5 lineup's price changes; note that the cost study above found Opus 5.5 `medium` cost-competitive.

### Inferences
Candidate defaults for the kit, to validate on its own evals:

| Role | Model + effort | Why |
|---|---|---|
| planner | Opus 5.5 `high` | Planning is reasoning-heavy and low-volume; "verification matters" |
| writer | Opus 5.5 `medium`, or Sonnet 5.5 `high` | Both have strong cost per solved task |
| reviewer | Opus 5.5 `high`, never `low` | Bug-finding collapses at `low` |
| security-auditor | Opus 5.5 `high`/`xhigh` | Runs rarely (pre-release, quarterly), so depth is affordable. Fable 5.1 `high` is an option, but beware credits billing and cyber-classifier fallbacks |

- Avoid `max` as any role's default.

### Gaps
- Anthropic gives no explicit per-role guidance for "planner" or "code reviewer". The closest is the defect-search benchmark and the Claude Code level table.
- I found no guidance specific to security review, beyond the classifier rerouting notes.

---

## Q5. Rate limits and plan quotas: what higher effort and stronger models cost in Claude Code

### Takeaway
On subscription plans, Claude Code draws from a seat allowance with a rolling 5-hour window and a weekly window, shared across all models and with claude.ai chat and Cowork. Higher effort and stronger models use up the allowance faster, because thinking is billed as output and every subagent's requests count. Fable is outside Pro and standard-seat allowances entirely, and is capped (reportedly at 50% of the weekly limit) on Max and premium seats. On the API, Claude Code traffic counts against org TPM/RPM limits, and Anthropic publishes per-user TPM recommendations.

### Cited Findings
- Team/Enterprise seat allowance — [Claude Code costs](https://code.claude.com/docs/en/costs.md):
  - Resets on a rolling five-hour window and a weekly window.
  - Shared with Claude chat and Cowork.
  - Size depends on seat tier (Standard/Premium).
- A "session limit" or "weekly limit" hit is shared across all models, so switching models doesn't help. A model-specific message ("You've hit your Opus limit") can be worked around by switching families with `/model`. — [Claude Code costs](https://code.claude.com/docs/en/costs.md)
- "Thinking tokens are billed as output tokens, and the default budget can be tens of thousands of tokens per request depending on the model." Lower effort reduces cost. — [Claude Code costs](https://code.claude.com/docs/en/costs.md)
- The `/usage` breakdown on subscription plans:
  - Attributes usage to subagents, skills, plugins, and MCP servers.
  - Recommends changes such as "Switch from max to high effort · /effort high".
  - Pressing `f` applies `/effort` recommendations (v2.1.305+).
  - [Claude Code costs](https://code.claude.com/docs/en/costs.md)
- Subagent and workflow requests count on top of the main conversation. Agent teams use about 7x more tokens than standard sessions when teammates run in plan mode. — [Claude Code costs](https://code.claude.com/docs/en/costs.md)
- Enterprise averages: about $13 per developer per active day and $150–250 per month; 90% of users stay under $30 per active day. These are not broken out by model or effort. — [Claude Code costs](https://code.claude.com/docs/en/costs.md)
- API per-user TPM/RPM recommendations — [Claude Code costs](https://code.claude.com/docs/en/costs.md):

  | Team size | TPM per user | RPM per user |
  |---|---|---|
  | 1–5 | 200k–300k | 5–7 |
  | 20–50 | 50k–75k | — |
  | 500+ | 10k–15k | — |

  - Claude Code's Console workspace counts toward org rate limits and can be capped with a workspace rate limit.
- At the Opus 5.5 launch, five-hour usage limits were raised on Pro, Max, Team, and seat-based Enterprise plans, and subscribers got a saveable rate-limit reset. — [Opus 5.5 launch](https://www.anthropic.com/news/claude-opus-5-5)
- Fast mode has its own rate limit, separate from standard Opus, and is billed at 2x. — [Pricing](https://platform.claude.com/docs/en/about-claude/pricing); Claude API skill reference
- Managed caps: admins can cap effort with `maxEffortLevel` or per-role limits on Enterprise. — [CC model config](https://code.claude.com/docs/en/model-config.md)
- Fable on Max: it uses the same weekly limit (not extra allowance) and depletes it faster. — [Notebookcheck](https://www.notebookcheck.net/Claude-Fable-5-1-is-not-included-in-your-Pro-subscription.1385320.0.html) (secondary)

### Inferences
- On a subscription, the relative cost of a role is roughly its token cost at API rates. Using the per-task costs in Q3, one Opus 5.5 `xhigh` writer task uses about 3.5x the allowance of a `medium` one. A Fable 5.1 task uses about 5x that of Opus 5.5 `medium` (assuming plan accounting tracks API cost, which is not documented).
- Several roles running in sequence (planner → writer → reviewer) each consume allowance. Keeping the reviewer and auditor on Opus 5.5 or Sonnet 5.5 rather than Fable protects the weekly window.
- If an org has set `maxEffortLevel`, a kit default of `xhigh` may be clamped silently.

### Gaps
- Anthropic does not publish how plan usage is computed (whether by token cost, or with different weights per model), or the absolute size of the 5-hour and weekly limits for each plan.
- I found no published per-model message or hour quotas for Claude Code on Pro, Max, or Ultra in Nov 2026.
- I could not confirm whether model-specific limits ("Opus limit") still exist on current plans. The docs mention the message, but not which plans have it.
