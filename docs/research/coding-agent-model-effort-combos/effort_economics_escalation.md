# Economics of Reasoning Effort in Agentic Coding Loops, and Escalation vs Fixed Effort

Research date: 2026-11-09. Dates are labeled on each finding; anything before 2025 is marked [OLDER]. Figures marked [SECONDARY] came through an aggregator or blog, and I could not check them against the primary source within this session's budget.

## 1. Cost per resolved task across models and effort levels: are stronger or higher-effort settings ever cheaper overall?

### Takeaway
Yes, in some cases, but not as a rule. The best-documented 2026 data is Anthropic's own guidance, which is internal, directional and covers its own models. In it, a newer or stronger model is often the cheapest lever per solved task. Raising effort inside one model mostly raises cost per solved task, with a sharp jump at the top level (xhigh). Independent work on OpenHands/SWE-bench shows accuracy peaking at intermediate token spend, and the most expensive runs are often the failures.

### Cited Findings
**Anthropic, "Optimizing for cost and intelligence" (platform docs, figures dated up to Oct 2026; Anthropic calls them "internal and directional")** — [Anthropic docs](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)
- Effort sweep for Claude Opus 5.5 on a SWE-bench Pro subset:

  | Effort | Solved | Cost per task |
  |---|---|---|
  | low | 87.4% | $0.11 |
  | medium (default) | 92.8% | $0.21 |
  | high | 95.3% | $0.29 |
  | xhigh | 96.7% (single run) | $0.74 |

  Going from high to xhigh adds about 1.4 points for about 2.5x the cost.
- Cost per solved task on the same subset:

  | Model and effort | Solved | Cost per solved task |
  |---|---|---|
  | Sonnet 5.5, high (default) | 87.6% | $0.11 |
  | Opus 5.5, low | 87.4% | $0.12 |
  | Opus 5.5, medium | 92.8% | $0.22 |
  | Fable 5.1, high | 92.3% | $1.19 |

  Opus 5.5 at default effort matched Fable 5.1 within noise for "about a fifth of the cost per solved task."
- Opus 5.5 at low solved about the same share as Sonnet 5.5 at default, for about 7% more per solved task, even though each Opus token price is twice Sonnet's. Anthropic's reading: "A more capable model can finish a task with less work, which can offset much of the per-token premium."
- On Sonnet 5.5, medium scored about 7 points below high on SWE-bench Pro, at about 59% of the cost per task.
- Model upgrades: Opus 5 to 5.5 cut cost per solved task by 78% on SWE-bench Pro, and Sonnet 5 to 5.5 cut it by 87%.
- Terminal-Bench 3: going from Opus 4.8 to Opus 5 raised tasks solved from 15% to 41% and cut cost per solved task from $63 to $28 (−56%). This is the clearest case where the stronger model was cheaper in total.
- On an internal agentic-coding benchmark, Opus 5.5 at medium scored 86.6% at $0.84 per attempt, and Fable 5.1 at medium scored 84.2% at $2.68 per attempt.
- Tokenizer caveat: "The same text costs about 30% more tokens on Claude 4.7 and later models," so per-token comparisons understate the newer models.
- `max_tokens` caps (internal repository tasks, Opus 5.5):

  | Cap | Solved | Cost per solved task |
  |---|---|---|
  | 16,384 | 57.6% (25% of attempts cut off) | $5.38 |
  | 64,000 | 75.6% | $5.38 |
  | 128,000 | 68.9% | $5.94 |

  Only 1 of the 66 attempts ended by the 16k cap still passed. A too-low cap wastes the whole attempt.
- "Price the tail": on one 20-problem WideSearch run, two problems carried 43% of the spend.

**Bai, Huang, Wang et al., arXiv 2604.22750 (Apr 2026, v3 Oct 2026). OpenHands on SWE-bench Verified, 8 models, 4 runs per task** — [SECONDARY via tokenade.net](https://tokenade.net/en/case-studies/swe-bench-agent-token-study). The page is from a token-optimization vendor and has internal date inconsistencies; verify on arXiv.
- Agentic coding averaged about 4.17M tokens and $1.857 per task, roughly 1000x or more what single-turn code reasoning uses.
- Total tokens on the same task varied by up to 30x across runs.
- Accuracy peaks at intermediate cost, then plateaus or declines. The highest-cost run is often worse, and high-cost runs re-view and re-edit the same files.
- The input-to-output token ratio was about 154:1. With caching, cache reads were the largest cost category for Sonnet-4.5.
- Kimi-K2 and Sonnet-4.5 used over 1.5M more tokens on average than GPT-5. On tasks every model failed, Kimi-K2 kept spending heavily, while GPT-5 and GPT-5.2 spent only modestly more than on their successes.
- Models predicted their own token use poorly: the best correlation was r=0.39, and all models underestimated.

**Aider architect/editor results [OLDER, Jan 2025]** — [Aider R1+Sonnet post](https://aider.chat/2025/01/24/r1-sonnet.html)
- DeepSeek R1 as architect with Sonnet 3.5 as editor scored 64.0% on the polyglot benchmark for $13.29, against o1 (high) alone at 61.7% for $186.5. That is about 14x cheaper for a higher score.
- o1 paired with a Sonnet editor did not beat o1 alone.
- Sept 2024 [OLDER]: o1-preview as architect with an o1-mini or DeepSeek editor scored 85%, against Sonnet alone at 84% on the earlier benchmark — [Aider architect post](https://aider.chat/2024/09/26/architect.html)

### Inferences
- The reliable rule is "a better model generation at default effort," not "more effort." Within one model, cost per solved task rises steadily with effort. Across generations or tiers, the stronger model can be cheaper per solved task because it uses fewer turns and tokens.
- Top effort levels (xhigh, max) look poor value for routine coding: a few points of success for 2–3x the cost.
- The 30x run-to-run token variance means a single run is a weak basis for comparing settings. Compare over repeated runs and look at the tail.

### Gaps
- I found no independent, non-vendor leaderboard that reports cost per *resolved* task by effort level for current (late-2026) models. The SWE-bench and Terminal-Bench leaderboards were not checked directly in this pass.
- The Artificial Analysis cost-per-task data was not retrieved.
- Cost-per-task rankings in secondary blogs ([DoiT](https://www.doit.com/research/economics-of-claude-openai-and-grok), [slash-digital](https://slash-digital.io/en/insights/reasoning-effort/)) were not verified and some use modeled token counts. They are excluded from the findings.

## 2. Test-time compute scaling for coding agents: diminishing returns, overthinking, plateaus

### Takeaway
Returns from extra compute are concave. The first extra attempt helps most, and gains plateau around 4–8 attempts unless a good verifier or selector is available. Extra serial reasoning inside one trajectory can hurt: "overthinking" reasoning models resolve fewer tasks.

### Cited Findings
- Cuadron et al., "The Danger of Overthinking" (arXiv 2502.08235, Feb 2025), used 4,018 OpenHands trajectories on SWE-bench Verified across 19 models.
  - Reasoning models favor internal deliberation over acting on the environment, and higher overthinking scores correlate with lower resolution.
  - The authors name three patterns: Analysis Paralysis, Rogue Actions and Premature Disengagement.
  - Picking the candidate with the lower overthinking score "can improve model performance by almost 30% while reducing computational costs by 43%."
  - [arXiv abstract](https://arxiv.org/abs/2502.08235)
- Kim et al., "Scaling Test-Time Compute for Agentic Coding" (arXiv 2604.16529, Apr 2026) [SECONDARY via blog]. Its RTV method summarizes rollouts and selects among them by tournament; PDR conditions the next attempt on those summaries.

  | Benchmark | Model | Baseline | With RTV+PDR |
  |---|---|---|---|
  | SWE-bench Verified | Claude 4.5 Opus | 70.9% | 77.6% |
  | SWE-bench Verified | Gemini 3.1 Pro | 72.0% | 77.0% |
  | Terminal-Bench 2.0 | Claude 4.5 Opus | 46.9% | 59.1% |
  | Terminal-Bench 2.0 | Gemini 3.1 Pro | 53.0% | 65.0% |

  - Marginal gains by attempt count: 1 to 2 attempts adds the most (+3–6 points on SWE-bench), 2 to 4 is moderate, and 4 to 8 plateaus without PDR.
  - Terminal-Bench benefits more from scaling than SWE-bench.
  - [Codex CLI blog summary](https://codex.danielvaughan.com/2026/06/20/scaling-test-time-compute-agentic-coding-codex-cli-rollout-retry-rtv-pdr-strategy/)
- The same blog cites a CMU paper (arXiv 2602.18998) reporting that agent performance peaks around 3–7 turns of retry and that context pollution dominates beyond that. Without an external verifier, parallel sampling gives diminishing returns. [SECONDARY] — [Codex CLI blog](https://codex.danielvaughan.com/2026/06/20/scaling-test-time-compute-agentic-coding-codex-cli-rollout-retry-rtv-pdr-strategy/); [Dev.to summary](https://dev.to/jangwook_kim_e31e7291ad98/agent-test-time-scaling-has-a-ceiling-cmu-research-2026-2bg5)
- GSO (arXiv 2505.23671, May 2025): parallel beat serial. Eight rollouts of 50 steps outperformed one rollout of 400 steps, and Opt@10 stayed under 20% with diminishing returns — [GSO paper](https://arxiv.org/pdf/2505.23671)
- CodeMonkeys (arXiv 2501.14723, Jan 2025): coverage grows log-linearly with the number of samples (69.8% coverage on SWE-bench Verified), but a selection step is needed. The resolved rate was 57.4% at about $2,300 total — [CodeMonkeys](https://arxiv.org/html/2501.14723v1)
- Within one session, Anthropic's high-to-xhigh step gives +1.4 points for 2.5x cost on SWE-bench Pro. On DeepResearch Bench II, Fable 5.1 at low and at medium scored the same (60.5%) at $3.47 vs $4.44 — [Anthropic docs](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)

### Inferences
- For a coding agent with tests, "one more attempt with failure context" is worth more than "think harder on the first attempt" past medium or high effort.
- Plan for 2 attempts, possibly up to about 4. Beyond that, expect context pollution and wasted spend.

### Gaps
- I did not read the primary text of arXiv 2604.16529 or 2602.18998, so their numbers here come from blog summaries.
- I found no study that maps exact effort-level knobs (low/medium/high) to overthinking rates in agent loops.

## 3. Cascades, routing and escalation: triggers and measured savings

### Takeaway
For checkable coding tasks, "cheap first, escalate on failure" beats fixed high settings. The cleanest number is Anthropic's: low effort first, then high effort on failures, reached about 97% solved at about $0.17 per task, against $0.29 for always-high at about 95%. Three conditions apply:
- The trigger must be a reliable external signal, such as tests or a judge. Self-confidence is weaker.
- Escalation is not always the right recovery. Cheap self-repair solves a distinct subset of failures.
- Advisor or consult patterns only pay off if the executor actually consults.

### Cited Findings
**Effort escalation (Anthropic, 2026)** — [Anthropic docs](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)
- Opus 5.5 on SWE-bench Pro (478 problems):

  | Policy | Solved | Cost per task |
  |---|---|---|
  | low, then high on its failures | 96.4–97.5% | ~$0.17 |
  | medium, then high on failures | 96.0–97.1% | ~$0.24 |
  | high, then high again on its failures | 96.9% | $0.31 |
  | everything at high | 94.8–95.8% | $0.29 |

  - Anthropic summarizes this as "about 40% less than running everything at high, at the same pass rate or slightly better."
  - Anthropic attributes the saving to the policy, not a quality lift, and says it requires a reliable failure signal.
- Advisor (stronger model consulted by the executor):
  - Opus 5.5 at high with a Fable 5.1 advisor scored +1.7 points, at the edge of noise, for about 2.1x the cost.
  - It averaged about 1.4 extra calls per attempt.
  - Where executors rarely consulted, results were within noise or worse. One Opus 5.5 run consulted on 1 of 300 tasks, and Sonnet 5.5 at high consulted on 0 of 20.
  - Anthropic's advice is to measure the consult rate first.
- Orchestration: Opus 5.5 orchestrating Sonnet 5.5 subagents cost about a third less than a single Opus 5.5 session, at about the same score, on work larger than one context window. For a single dependent chain, the orchestrator model alone at lower effort was ahead.

**CodeRescue (arXiv 2607.19338, Jul 2026)** — [CodeRescue](https://arxiv.org/html/2607.19338v1)
- Setup:
  - Cheap model: GPT-5.4-nano. Strong model: GPT-5.4.
  - Router: Qwen3.5-4B. After the cheap attempt fails, it chooses between reflect (repair using the failure trace), replan (fresh solution) and escalate.
  - Benchmarks: APPS, TACO, BigCodeBench, LiveCodeBench and CodeContests. These are function-level tasks, not repository agents.
- Trigger: the judge verdict (fail, timeout or compile_error).
- Holdout results (n=360):

  | Strategy | Solve rate | Mean cost |
  |---|---|---|
  | always-escalate | 0.686 | 7.22 m$ |
  | learned router | 0.817 | 5.51 m$ |
  | always-replan | 0.453 | 1.59 m$ |
  | always-reflect | 0.275 | 1.24 m$ |

  - At a budget-calibrated point, the router reached 0.717 at about 35% of always-escalate's cost.
  - A naive binary cascade reached 0.636 at comparable cost.
- Oracle split of failures: 28% are solvable only by cheap recovery, 45% only by escalation, and 27% by both.
- When escalation wastes money: on TACO-Medium, the strong model was not more reliable than the cheap one. On Very-Hard, neither model succeeded reliably. Escalation helped on Med-Hard and Hard.
- Prompt-only LLM routers did badly. Claude Sonnet 4.6 as router reached 0.453 at 6.67 m$.

**Older routing and cascade literature**
- FrugalGPT (2023) [OLDER]: up to 98% cost reduction at matched quality on its benchmarks, a best case. Secondary summaries put typical savings at 40–70%.
  - [SECONDARY summary](https://intuitionlabs.ai/articles/ai-model-routing-cost-quality)
  - Primary paper (not fetched): arXiv 2305.05176.
- RouteLLM (Jul 2024) [OLDER]: 95% of GPT-4 performance with 26% GPT-4 calls, about 48% cheaper than a random baseline. With augmented data it used 14% GPT-4 calls, about 75% cheaper than random. These are chat benchmarks, not coding agents — [LMSYS blog](https://lmsys.org/blog/2024-07-01-routellm/); [arXiv](https://arxiv.org/abs/2406.18665)
- AutoMix (2023) [OLDER]: I could not confirm a primary figure for its self-verification cascade.

**Other cascade work in 2026**
- Step-level escalation for computer-use agents recovered most of the strong model's performance at lower cost. The large model sets the ceiling and the small model controls cost — [arXiv 2604.27151](https://arxiv.org/pdf/2604.27151)
- Bayesian self-escalation: overconfident wrong answers suppress needed escalations — [arXiv 2608.24087](https://arxiv.org/pdf/2608.24087)
- Cascade depth theory — [arXiv 2605.06350](https://arxiv.org/html/2605.06350)

### Inferences
- In the coding cascade studies found, the triggers ranked by evidence are:
  1. Test or judge failure, which is strong.
  2. Repeated failure or stuck detection, which is plausible.
  3. Model self-assessment, which is weak. Overconfidence suppresses escalation, and executors rarely call advisors.
- Speculation: a three-way policy probably fits a coding agent better than a binary cascade. On a first test failure, let the same model repair from the trace. On a second failure, or a stuck flag, escalate effort or model with a structured failure summary. CodeRescue's 28/45/27 split supports doing cheap repair first. The ordering itself has not been tested on repository-level tasks.
- Escalate effort before escalating model. It is cheaper, and on Anthropic's numbers low-to-high effort already beats fixed high.

### Gaps
- I found no repository-level (SWE-bench-style) study of model-switch cascades with measured savings. CodeRescue covers function-level problems, and Anthropic's escalation data is an effort escalation within one model.
- I found no published data on Cursor's auto-routing or Sourcegraph Amp's model-switching economics.

## 4. Costs of escalation: context loss, re-reading, cache invalidation, handoff practices

### Takeaway
Escalation has real switching costs. Changing top-level effort mid-session rewrote most of a cached conversation in Anthropic's test, and a model switch cannot reuse the old model's cache (inferred). Agentic runs are about 99% input tokens, so the re-read dominates. The better pattern is a fresh attempt seeded with a compact structured summary of the failure, plus git and test state, rather than replaying the full trace.

### Cited Findings
- Anthropic's cache measurement (Oct 2026) used a cached 101,000-token conversation — [Anthropic docs](https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence)

  | Change | What the request did |
  |---|---|
  | Per-message effort change | Read all 101k from cache, wrote none |
  | Top-level effort change | Read the 20k system prompt, re-wrote 81k |
  | Edit at the front of the system prompt | Re-wrote all 101k |

  - Prompt-side cost of one request on Fable 5.1: a top-level effort change cost $1.02, against $0.025 for a per-message effort change.
  - Making changes mid-session cost $0.95 per session, against $0.75 when the same changes were made at a compaction boundary.
  - Anthropic recommends sweeping effort in separate sessions, because changing effort mid-session invalidates the cache.
- Input tokens dominate agentic coding (about 154:1 input to output), and cache reads were the largest cost category — [SECONDARY via tokenade.net, arXiv 2604.22750](https://tokenade.net/en/case-studies/swe-bench-agent-token-study)
- Handoff by summary works better than the raw trace. In RTV, each rollout becomes a structured summary of hypotheses, progress and failure modes, with trace noise dropped. Next attempts are conditioned on the selected summaries, which reportedly outperform full rollouts. [SECONDARY] — [Codex CLI blog on arXiv 2604.16529](https://codex.danielvaughan.com/2026/06/20/scaling-test-time-compute-agentic-coding-codex-cli-rollout-retry-rtv-pdr-strategy/)
- CodeRescue gave the escalated model the problem plus the weak model's error message, not the failed code or approach. Its router also did not see the failed code — [CodeRescue](https://arxiv.org/html/2607.19338v1)
- Anthropic's long-running harness (Nov 26, 2025) — [Anthropic Engineering](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
  - Handoff state between context windows lives in `claude-progress.txt`, git commits with descriptive messages, a JSON feature list and an `init.sh`.
  - The feature list is JSON because the model is less likely to inappropriately change or overwrite JSON than Markdown.
  - Each session reads the git log and progress file, then runs a basic end-to-end test before starting new work.
  - Observed failure modes: declaring victory early, running out of context mid-feature (the next session had to guess the state), and marking features done without end-to-end testing.

### Inferences
- Escalate at a natural boundary: after a test run fails, or at a compaction point. Start the new session with a short failure brief rather than switching the model or top-level effort mid-conversation. The brief should cover:
  - the failing test names and output
  - the hypotheses tried
  - the files touched
  - the diff or commit SHA
- A model switch always loses the prior cache, because caches are model-specific. This is my inference and is not stated on the pages fetched.
- Speculation: handing over the full failed trace may import the weaker model's mistaken framing. Both RTV and CodeRescue pass less than the full trace, but neither ablates this directly for repository tasks.

### Gaps
- I found no measurement of the re-read cost of a fresh session on a large repository against continuing in place.
- I found no direct ablation of "full trace vs summary vs error-only" handoff on SWE-bench-style tasks.

## 5. Loop and stuck detection heuristics in real coding agents

### Takeaway
The production heuristics are simple repetition counters. OpenHands has the best-documented detector. Gemini CLI has a loop-detection service. I found no official documentation of loop detectors in Claude Code, Codex or Cursor. These signals are natural escalation or abort triggers alongside test failure.

### Cited Findings
- The OpenHands SDK stuck detector is on by default (`stuck_detection=True`) and looks at events after the last user message — [OpenHands docs](https://docs.openhands.dev/sdk/guides/agent-stuck-detector)

  | Pattern | Threshold |
  |---|---|
  | Same action producing the same observation | 4 or more |
  | Same action producing errors | 3 or more |
  | Agent monologue (messages with no progress) | 3 or more |
  | Alternating ping-pong between two action-observation pairs | 6 or more cycles |
  | Repeated context-window errors | not given |

  - It can halt execution, and `conversation.stuck_detector.is_stuck()` exposes the status.
- The OpenHands thresholds were hardcoded. Issue #762 requests configurable `stuck_detection_thresholds`, for example to allow legitimate polling — [GitHub issue #762](https://github.com/OpenHands/software-agent-sdk/issues/762). Whether this shipped was not verified.
- Gemini CLI has a LoopDetectionService that stops repeated tool calls (same name and arguments). Version 0.6.0 added a prompt to disable it per session.
  - Users report false positives on long-running shell commands.
  - Details come from secondary sources — [lilting.ch article](https://lilting.ch/en/articles/gemini-self-loathing-loop-bug); [gemini-cli issue #19519](https://github.com/google-gemini/gemini-cli/issues/19519)
  - Gemini CLI personal tiers were reportedly discontinued June 18, 2026 in favor of Antigravity CLI [SECONDARY, same lilting.ch source].
- OpenRouter's agent SDK documents "doom loop detection" — [OpenRouter docs](https://openrouter.ai/docs/agent-sdk/call-model/doom-loop-detection). Not fetched.
- Claude Code: a community feature request proposes halting after about 5 identical tool calls with the same arguments, modeled on Gemini CLI — [claudeissues.com #4317](https://claudeissues.com/issue/4317-feature-request-implement-agentic-loop-detection-service-to-prevent-repetitive-a). This is a request, not a shipped feature.
- Cost-side symptoms seen in the token study:
  - High-cost runs re-view and re-edit the same files.
  - Some models keep spending heavily on unsolvable tasks.
  - [SECONDARY, arXiv 2604.22750](https://tokenade.net/en/case-studies/swe-bench-agent-token-study)
- The overthinking patterns Analysis Paralysis and Premature Disengagement are another class of "stuck," driven by reasoning rather than repeated actions — [arXiv 2502.08235](https://arxiv.org/abs/2502.08235)

### Inferences
- The typical thresholds are 3 identical errors, 4 identical action-observation pairs, 3 monologue turns and 6 ping-pong cycles. These are reasonable defaults for a cheap trigger to escalate or stop.
- Additional cost-based triggers suggested by the token study (speculation):
  - repeated edits to the same file without the test outcome changing
  - token spend above a multiple of the task's median
- Polling and long-running commands cause false positives. Detectors need allowlists or configurable thresholds.

### Gaps
- I found no official documentation of loop or stuck detection in Claude Code, OpenAI Codex CLI or Cursor. One third-party claim says Claude Code and Codex have none; it is unverified.
- I did not check SWE-agent's mechanisms, such as per-instance cost limits, `max_requeries` on format errors, and its RetryAgent and reviewer loop. These need a direct look at the SWE-agent docs.
- I found no measured cost savings attributable to stuck detection itself.
