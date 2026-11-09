# OpenAI Codex (CLI and models): reasoning effort, pricing, and use as a second-opinion reviewer (as of 2026-11-09)

Source note: the old developers.openai.com/codex/* doc URLs now return 308 redirects to learn.chatgpt.com/docs/*. I fetched the learn.chatgpt.com pages directly on 2026-11-09. The openai.com launch posts returned HTTP 403 to the fetcher, so the launch-post benchmark numbers below come from a secondary write-up of them, and they are labelled that way. Third-party blogs (codex.danielvaughan.com, morphllm, aggregators) are labelled and should not be treated as authoritative.

## 1. Which models Codex uses (Nov 2026), API prices, and ChatGPT-plan vs API-key billing

### Takeaway
Codex is now on the GPT-6 family. The recommended models are `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6.1-terra` and `gpt-6-luna`. With ChatGPT sign-in, `gpt-6.1-sol` is the recommended model on paid plans. At $2/$10 per 1M tokens it is the cost-performance pick for a reviewer, and `gpt-6-astra` ($10/$50) is the top-capability option. GPT-5.x models have been retired for ChatGPT sign-in but stay available with an API key. Billing has two modes. With ChatGPT sign-in, usage comes out of the plan's 5-hour and weekly allowances (and credits once those run out). With `CODEX_API_KEY`, every token is billed at API rates.

### Cited Findings
**Model line-up (official Codex models page)**
- Recommended Codex models, with CLI commands: Astra `codex -m gpt-6-astra` ("Highest capability, for the hardest end-to-end work"); 6.1 Sol `codex -m gpt-6.1-sol` ("Close to Astra on complex work, at lower cost"); 6.1 Terra `codex -m gpt-6.1-terra` ("Fast and efficient for writing, visual tasks, and computer use", requires Codex CLI 0.159.0 or later); 6 Luna `codex -m gpt-6-luna` ("Most efficient, for focused, high-volume tasks") — [Codex models](https://learn.chatgpt.com/docs/models)
- For ChatGPT sign-in, the page recommends GPT-6.1 Sol on paid plans and GPT-6 Luna on Free and Go. The config example is `model = "gpt-6.1-sol"`. The CLI, desktop app and IDE extension share one `config.toml` — [Codex models](https://learn.chatgpt.com/docs/models)
- Retirements for ChatGPT sign-in: gpt-5.4 and gpt-5.4-mini on 2026-08-31; gpt-5.3-codex-spark on 2026-09-14; GPT-5.5 on 2026-10-14 at 19:00 UTC; gpt-5.2 and gpt-5.3-codex "already deprecated". "The OpenAI API and Codex sessions authenticated with an API key aren't affected." "With API-key authentication, model availability follows your API organization and project." — [Codex models](https://learn.chatgpt.com/docs/models)
- GPT-6.1 Sol release date: 2026-09-29, per the system card addendum title "OpenAI Addendum: GPT-6.1 Sol System Card 2026-09-29" — [System card PDF](https://deploymentsafety.openai.com/gpt-6-1-sol/gpt-6-1-sol.pdf) (seen in a search result, not opened); also [Vals AI](https://www.vals.ai/models/openai_gpt-6.1-sol)
- OpenAI's launch post is at [Introducing GPT-6.1 Sol](https://openai.com/index/introducing-gpt-6-1-sol/) (returned 403 to the fetcher, not read directly). Search summaries say it positions 6.1 Sol as close to Astra on coding at a fraction of the price, with an "Ultrafast" variant announced for later.

**API prices, per 1M tokens: input / cached input / output (official pricing page, no date shown on it)**
| Model | Standard (≤272K input) | Long context (>272K) | Batch / Flex | Fast (formerly Priority) |
|---|---|---|---|---|
| gpt-6-astra | $10.00 / $1.00 / $50.00 | $20 / $2 / $75 | $5 / $0.50 / $25 | $20 / $2 / $100 |
| gpt-6.1-sol | $2.00 / $0.10 / $10.00 | $4 / $0.20 / $15 | $1 / $0.05 / $5 | $4 / $0.20 / $20 |
| gpt-6-sol | $2.00 / $0.20 / $10.00 | $4 / $0.40 / $15 | $1 / $0.10 / $5 | not listed |
| gpt-6.1-terra | $1.00 / $0.05 / $5.00 | $2 / $0.10 / $7.50 | $0.50 / $0.025 / $2.50 | $2 / $0.10 / $10 |
| gpt-6-luna | $0.10 / $0.01 / $0.50 | $0.20 / $0.02 / $0.75 | $0.05 / $0.005 / $0.25 | $0.20 / $0.02 / $1 |
| gpt-5.5 (older) | $5.00 / $0.50 / $30.00 | $10 / $1 / $45 | $2.50 / $0.25 / $15 | $12.50 / $1.25 / $75 |
| gpt-5.4 (older) | $2.50 / $0.25 / $15.00 | $5 / $0.50 / $22.50 | $1.25 / $0.13 / $7.50 | $5 / $0.50 / $30 |
| gpt-5.3-codex (older, "Specialized models") | $1.75 / $0.175 / $14.00 | not listed | not listed | $3.50 / $0.35 / $28 |
  — [OpenAI API pricing](https://developers.openai.com/api/docs/pricing). Priority was renamed Fast mode on 2026-07-30. Data-residency and FedRAMP endpoints add 10% — same page.
- gpt-5.3-codex is the only "codex"-named model left on the price page. No GPT-6-era "-codex" variant appears — [OpenAI API pricing](https://developers.openai.com/api/docs/pricing)
- Conflict: pricepertoken lists gpt-6.1-sol at $1/$5. That matches the official Batch/Flex rate, not Standard — [pricepertoken](https://pricepertoken.com/pricing-page/model/openai-gpt-6.1-sol) vs [OpenAI API pricing](https://developers.openai.com/api/docs/pricing)

**ChatGPT plan vs API key (official Codex pricing page)**
- Codex is included in ChatGPT Free, Go ($8/mo), Plus ($20/mo), Pro (from $100/mo), Business ($20/user/mo billed annually, 2+ users), Edu and Enterprise — [Codex pricing](https://learn.chatgpt.com/docs/pricing)
- API key: "Pay for Codex usage based on API pricing." API-key Codex has no cloud features, and its usage doesn't count against plan limits — [Codex pricing](https://learn.chatgpt.com/docs/pricing)
- Estimated local messages per 5 hours on Plus and Standard Business: Astra 5–45; 6.1 Sol 15–160; 6.1 Terra 35–285; 6 Sol 15–150; Luna 350–3,000. Weekly limits may also apply. Pro "currently [has] no five-hour limit". Enterprise/Edu on flexible pricing have no fixed rate limits — [Codex pricing](https://learn.chatgpt.com/docs/pricing)
- Fast mode uses 2.5x the included usage. Ultrafast uses 8x on Astra and 6.1 Sol. Purchased credits are charged at 2x (Fast) and 6x (Ultrafast) — [Codex pricing](https://learn.chatgpt.com/docs/pricing)
- Credits per 1M input tokens at Standard speed: 6.1 Sol 50, Terra 25, Luna 2.5, Astra 250. The page also says "A typical GPT-5.6 Sol task may use 2–15 credits". "GPT-5.6 Sol" looks like a typo in the docs, since no such model appears anywhere else — [Codex pricing](https://learn.chatgpt.com/docs/pricing)
- "Model choice, context, reasoning, tool use, retrieval, and caching all affect usage." The page doesn't put a number on reasoning effort's effect on limits — [Codex pricing](https://learn.chatgpt.com/docs/pricing)
- Code review: reviews run through GitHub count as a separate "Code Review usage" category. "Reviews run locally or outside of GitHub count toward your general usage limits" — [Codex pricing](https://learn.chatgpt.com/docs/pricing). So `codex exec` and `codex review` called from our script use general limits.

### Inferences
- For a scripted cross-model reviewer, `gpt-6.1-sol` is the natural default. It's recommended for paid ChatGPT plans, costs 1/5 of Astra per token, and scored at or above Astra High on DeepSWE in OpenAI's own numbers (section 3). Use `gpt-6-astra` for high-stakes reviews such as releases and security.
- A typical review prompt (diff plus some repo reads, say 50–150K input tokens with partial caching, and a few thousand output tokens including reasoning) should cost cents per run on 6.1 Sol at API rates. This is an estimate, not a measured figure.
- If the workflow runs in CI with an API key, pin the model explicitly with `-m`. Model availability then follows the API project, not the ChatGPT plan.

### Gaps
- No GPT-6-era "*-codex" model was found. It's unclear whether OpenAI still ships codex-tuned variants.
- The Codex docs don't name a fixed default model when none is configured. They only say a "recommended model" is used.
- Per-plan weekly limit numbers were not given.

## 2. `model_reasoning_effort` levels, defaults and what they change; `model_reasoning_summary`; verbosity

### Takeaway
In Codex, `model_reasoning_effort` takes whatever levels the selected model advertises. The config reference lists `low`, `medium`, `high`, `xhigh`, `max` and `ultra`. In the API, GPT-6.1 Sol supports `low`, `medium` (default), `high`, `xhigh` and `max`, with no `none`, no `minimal` and no `ultra`. In Codex, `ultra` means fanning work out to subagents, and Luna does not support it. `minimal` is effectively gone: OpenAI says to use `low` instead.

### Cited Findings
- Config reference: `model_reasoning_effort` (string) is the "Reasoning effort advertised by the selected model, such as `low`, `medium`, `high`, `xhigh`, `max`, or `ultra`." `plan_mode_reasoning_effort` is the "Plan-mode-specific reasoning override using a level supported by the selected model." — [Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- Meaning of each level in the UI. Light (app/IDE) or Low (CLI): "quick, well-scoped tasks". Medium: "balances speed and depth for tasks that need more planning". High and Extra High: "difficult work with multiple steps, sources, or tradeoffs". Max: "gives the selected model more time to reason about a single task". Ultra: "uses subagents to handle separate parts of a complex task in parallel" — [Codex models](https://learn.chatgpt.com/docs/models)
- "Reasoning efforts don't map exactly between model generations." "GPT-6 Luna supports reasoning efforts up to Max, but not Ultra." "Some paid plans omit Astra Extra High." "In configuration, Astra's Light setting is `low`." In the CLI, `/model` then **More reasoning…** shows each model's Max and Ultra options — [Codex models](https://learn.chatgpt.com/docs/models)
- Starting-point guidance: for GPT-6.1 Sol, "start with the client's default effort". For Luna, start at High. For Astra, Light (`low`) is the starting point — [Codex models](https://learn.chatgpt.com/docs/models)
- API: GPT-6.1 Sol "supports `low`, `medium` (default), `high`, `xhigh`, and `max`". GPT-6.1 Terra supports `none`, `low`, `medium` (default), `high`, `xhigh`, `max`. GPT-6 Astra does "not support the `none` reasoning effort" (use `low`). Luna supports `none`. For `minimal`, OpenAI advises starting with `low`. For Terra, start at `medium` and raise effort only if the quality gain justifies the extra time and tokens — [Using GPT-6](https://developers.openai.com/api/docs/guides/latest-model)
- In the API, a `configuration_update` input item can change effort mid-conversation without rewriting the prompt prefix, which keeps the cache intact — [Using GPT-6](https://developers.openai.com/api/docs/guides/latest-model)
- `model_reasoning_summary`: `auto | concise | detailed | none`, "Select reasoning summary detail or disable summaries entirely." — [Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- `model_verbosity`: `low | medium | high`, "Optional GPT-5 Responses API verbosity override; when unset, the selected model/preset default is used." (The wording still says "GPT-5".) — [Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- `service_tier`: "Use `fast` or another tier advertised by the active model; `fast` maps to the request value `priority`." — [Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- Profiles: `$CODEX_HOME/profile-name.config.toml`, selected with `--profile`/`-p`. Project-local `.codex/config.toml` cannot set `profile`/`profiles` — [Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference); [Developer commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli)

### Inferences
- For `codex exec`, set effort with `-c model_reasoning_effort="high"`, since `-c` is a documented `exec` flag. Use `xhigh` or `max` for deeper reviews.
- Avoid `ultra` in a scripted reviewer. It spawns subagents, so cost and latency are unbounded and output is less reproducible, and it isn't supported on Luna or in the API effort list for Sol.
- Set `model_reasoning_summary="none"` or `"concise"` and `model_verbosity="low"` to keep the final review message short. This is untested; the defaults depend on the model.

### Gaps
- The Codex docs don't state the default effort Codex CLI uses for 6.1 Sol. The API default is `medium`.
- Astra's full API effort list and its default were not found. Whether `ultra` works under `codex exec` (as opposed to interactive use) is not documented.
- There is no official mapping from GPT-5.x levels (`minimal`/`low`/`medium`/`high`/`xhigh`) to GPT-6 levels beyond "don't map exactly".

## 3. Benchmarks by effort level; token usage and latency per level

### Takeaway
OpenAI reports GPT-6.1 Sol benchmarks at a single effort level per benchmark, not as effort sweeps. The headline coding number is DeepSWE 1.1 at High: 75.2% at $0.65 per task, versus GPT-6 Astra High at 73.2% and $3.92. OpenAI publishes no SWE-bench Verified or Pro number for 6.1 Sol. Independent Terminal-Bench 4.0 scores conflict (56.1% vs 58.2%). No source gives per-effort token or latency curves.

### Cited Findings
- From OpenAI's launch report, via a secondary write-up (the primary page returned 403):
  - DeepSWE 1.1 at High: 6.1 Sol 75.2% at $0.65/task vs Astra High 73.2% at $3.92
  - Terminal-Bench Science 0.1 at Max: 6.1 Sol 57.0% at $5.47/task vs Astra Max 68.1% at $23.80; "Opus 5.5 with fallbacks" 63.3% at $23.21
  - OSWorld 2.0 offline at Max: 71.4% (partial reward) at $1.27 vs Astra Max 73.5% at $9.44
  - AutomationBench 1.0.6 at Medium: 31.7% at $0.19 vs GPT-6 Sol Medium 26.9% at $0.21
  - Factuality challenge set at Low: 7.7% of answers contain an error vs GPT-6 Sol Low 11.4%
  - Output tokens were not reported for these rows. Costs are averages per task and may include failed attempts.
  — [Kingy AI summary of OpenAI launch report](https://kingy.ai/blog/gpt-6-1-sol-specs-benchmarks-pricing-task-costs/). Terminal-Bench Science 57.0% at Max is also reported by [AlphaCorp](https://alphacorp.ai/blog/gpt-6-1-sol-launch-benchmarks-pricing-and-everything-you-need-to-know)
- Elma says OpenAI's DeepSWE comparison uses a lower effort for 6.1 Sol than GPT-6 Sol's best run — [Elma](https://elma.sh/blog/gpt-6-1-sol-coding-benchmark)
- SWE-bench Verified/Pro: one guide says OpenAI doesn't publish them for this model — [MyClaw](https://myclaw.ai/blog/gpt-6-1-sol-for-coding). Another says the public SWE-bench leaderboard doesn't list it — [Elma](https://elma.sh/blog/gpt-6-1-sol-coding-benchmark)
- Terminal-Bench 4.0 (independent; effort not stated): 56.1% per [MyClaw](https://myclaw.ai/blog/gpt-6-1-sol-for-coding); contradicted by 58.2% (tied with GPT-6 Astra) per [Elma](https://elma.sh/blog/gpt-6-1-sol-coding-benchmark) and [CodingFleet](https://codingfleet.com/blog/terminal-bench-4-leaderboard-2026/)
- Artificial Analysis Intelligence Index v4.3.2 at Max: score 52, about $0.72 per index task, about 67M output tokens (including reasoning) for the full index run — as reported by [Kingy AI](https://kingy.ai/blog/gpt-6-1-sol-specs-benchmarks-pricing-task-costs/) (not verified on artificialanalysis.ai)
- OpenAI says Astra got stronger results in several evaluations "using substantially fewer output tokens", without tying this to an effort level — [Using GPT-6](https://developers.openai.com/api/docs/guides/latest-model)
- Higher effort costs more time and tokens, so raise it only when the quality gain justifies it — [Using GPT-6](https://developers.openai.com/api/docs/guides/latest-model)

### Inferences
- OpenAI's own headline coding number for 6.1 Sol uses High effort, and it beats Astra High there at roughly 1/6 the cost per task. That points to High as a reasonable default for a review pass. Reserve Max for hard or terminal-heavy tasks, where Astra's lead is larger (11.1 points on Terminal-Bench Science).

### Gaps
- No official or independent sweep of the same benchmark across effort levels (low→max) for GPT-6.x was found.
- No latency (wall-clock) figures per effort level were found.
- No code-review-specific benchmark result by effort level was found.
- The launch-post numbers could not be checked against the primary page (403).

## 4. Codex code-review features and non-interactive scripting

### Takeaway
There are three routes. (a) `codex review` is a dedicated non-interactive subcommand with mutually exclusive `--uncommitted`, `--base <branch>`, `--commit <sha>` or a custom PROMPT. (b) `/review` works interactively in the CLI, IDE and app. (c) `@codex review` and automatic reviews on GitHub. To get machine-readable output, wrap a review prompt in `codex exec`, which is read-only by default and supports `--json`, `-o/--output-last-message` and `--output-schema`. Those output flags are documented for `exec`, not for `review`.

### Cited Findings
**`codex review` (CLI developer-commands page)**
- `--uncommitted`: "Review staged, unstaged, and untracked changes." `--base`: "Review changes against the specified base branch." `--commit`: "Review the changes introduced by the specified commit." `--title`: "Set the commit title shown in the review summary. Requires `--commit`." `PROMPT`: "Custom review instructions. Use `-` to read the instructions from stdin." "`--uncommitted`, `--base`, `--commit`, and a custom `PROMPT` conflict with one another." Also `--strict-config` — [Developer commands (CLI)](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
- `--json` and `-o` are not documented for `codex review`. Most global flags "propagate to subcommands", but the page says to check command help for exceptions. Whether `codex review` accepts `-c` or `-m` is not confirmed — [Developer commands (CLI)](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
- `CODEX_API_KEY` is documented as working with `codex exec`, `codex review`, the TypeScript SDK and `codex exec-server --remote`. The docs warn: "Don't set it as a job-level environment variable in workflows that run repository-controlled code." — [Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)

**`/review` and the review model**
- `/review` opens presets. Codex "reads the selected diff and reports prioritized, actionable findings without changing your working tree." The IDE and app offer "Review against a base branch" and "Review uncommitted changes". The app adds "Review a commit" and "Custom review instructions" — [Codex code review](https://learn.chatgpt.com/docs/code-review)
- `review_model`: "Optional model override used by `/review` (defaults to the current session model)." — [Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- GitHub: cloud reviews are triggered with `@codex review`, and Codex "can review a GitHub pull request before you open it" with the required setup. Review instructions live in app Settings > Code Review — [Codex code review](https://learn.chatgpt.com/docs/code-review)
- The page gives no guidance on reasoning effort for reviews and names no default review effort. It advises: "Check the review findings against the diff." — [Codex code review](https://learn.chatgpt.com/docs/code-review)
- Older third-party example (March 2026, GPT-5 era, not authoritative): a `deep-review` profile using `xhigh` effort, and an MCP review server with `REVIEW_REASONING_EFFORT = "xhigh"` — [Daniel Vaughan blog](https://codex.danielvaughan.com/2026/03/30/codex-cli-review-command-code-review-workflows/). Its model name `gpt-5-codex-max` and its `--full-auto` and `--sandbox-mode` flags are outdated or suspect: `--full-auto` is "no longer supported", and the real flag is `--sandbox`/`-s`.

**`codex exec` (non-interactive)**
- "By default, `codex exec` runs in a read-only sandbox." `--sandbox workspace-write` allows edits. `--sandbox danger-full-access` should only be used in a controlled environment. `--full-auto` is "no longer supported". `--approve-for-me` routes approvals through automatic review under workspace-write — [Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
- Output: `--json` gives a JSONL stream on stdout (events: `thread.started`, `turn.started`, `turn.completed`, `turn.failed`, `item.*` such as `item.started`/`item.completed`, `error`; item types include agent messages, reasoning, command executions, file changes, MCP tool calls, web searches and plan updates). `-o/--output-last-message <path>` writes the final message to a file and still prints it to stdout. `--output-schema <file>` asks for a final response that conforms to a JSON Schema. `--ephemeral` keeps session rollout files off disk — [Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
- Other flags: `--ignore-user-config` (skip `$CODEX_HOME/config.toml`), `--ignore-rules`, `--skip-git-repo-check`. `codex exec resume --last "<prompt>"` / `codex exec resume <SESSION_ID>`. Stdin: a prompt plus piped stdin treats the stdin as context, and `codex exec -` reads the whole prompt from stdin — [Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
- `exec` flags: `-m/--model`, `-c/--config` (repeatable inline override), `-s/--sandbox`, `-p/--profile`, `-C/--cd`, `--output-schema` — [Developer commands (CLI)](https://learn.chatgpt.com/docs/developer-commands?surface=cli)
- Config values: `sandbox_mode` = `read-only | workspace-write | danger-full-access`; `approval_policy` = `on-request | never | { granular = {...} }` — [Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)

### Inferences
- A suggested script pattern, built from documented flags and not tested end to end:
  `git diff origin/main...HEAD | codex exec -m gpt-6.1-sol -c model_reasoning_effort="high" -s read-only --ephemeral --ignore-user-config --output-schema review.schema.json -o review.json "Review this diff for correctness bugs; report findings with file, line, severity, evidence."`
  The piped diff is added as context. Read-only is already the default, but being explicit costs nothing. `--ignore-user-config` makes runs reproducible across machines.
- `codex review --base main` is simpler, but its structured output (`--json`, `-o`) isn't documented. `codex exec` with `--output-schema` is the safer choice when another agent has to parse the result.

### Gaps
- The exact output format of `codex review`, and whether it honours `-m`, `-c` and `--json`, are not confirmed. Check with `codex review --help`.
- The documented severity scale for findings (a "P1" label shows up on the code-review page but isn't defined) and AGENTS.md "Review guidelines" support were not confirmed in current docs.
- No official guidance on which reasoning effort to use for reviews was found.

## 5. Reported quality of Codex as a reviewer (precision / false positives)

### Takeaway
Evidence is thin and mostly from vendors or blogs. OpenAI publishes no precision or false-positive figures for Codex review and tells users to verify findings against the diff. The few third-party numbers are low-to-moderate and mostly predate GPT-6: CR-bench gives Codex a 20.1% pass rate (the model isn't stated), Entelligence reports F1 45.4%, and Augment reports 68% precision and 29% recall. None of the third-party numbers were evaluated with GPT-6.1 Sol.

### Cited Findings
- OpenAI's code-review docs give no accuracy figures and say to check each finding "against the latest diff, expected behavior, and tests before deciding it needs a fix." — [Codex code review](https://learn.chatgpt.com/docs/code-review)
- CR-bench (Zhang et al., arXiv 2603.23448, March 2026): Codex 20.1% "out of the box", vs Claude Code 32.1%, Devin 24.8%, PR-Agent 23.1%. The model and effort aren't specified. CR-bench reports 84% of agent review comments as "genuinely useful", which is a usefulness rate, not precision — [Daniel Vaughan blog summary](https://codex.danielvaughan.com/2026/05/02/code-review-agent-benchmark-cr-bench-codex-cli-review-quality/); primary: [arXiv 2603.23448](https://arxiv.org/abs/2603.23448) (not fetched)
- Entelligence 2026 benchmark (run by a vendor that competes with Codex): Codex second on F1 at 45.4% of 8 tools, behind Entelligence 47.2% and ahead of Claude 42.8%. False positives: Entelligence 12 vs Codex 5 — [Entelligence](https://entelligence.ai/code-review-benchmark-2026) (search-snippet level only, not fetched)
- Augment vendor table: Codex Code Review 68% precision, 29% recall, 41% F1. Reported second-hand and not verified against the original — via search results ([DEV Community comparison](https://dev.to/mcrolly/codex-code-review-vs-claude-code-ai-code-review-comparison-58jk) / [gitautoreview](https://gitautoreview.com/blog/ai-code-review-benchmark-2026)). Treat it as unverified.
- OpenAI customer story: [GPT-6.1 Sol helps CodeRabbit strengthen security across complex codebases](https://openai.com/index/gpt-6-1-sol-coderabbit-code-security/). It returned 403, so no numbers were extracted.

### Inferences
- The available numbers (moderate precision, low recall) suggest Codex works better as a second opinion that adds independent findings than as a gate. Its findings should be triaged against the diff, as OpenAI itself advises. The low false-positive count in the Entelligence comparison, if accurate, supports using it as a cross-check.

### Gaps
- No independent, GPT-6.x-era precision or false-positive measurement of Codex review was found.
- No data was found on how reasoning effort affects review precision or recall.
- The Entelligence, Augment and CodeRabbit figures could not be confirmed against primary pages.
