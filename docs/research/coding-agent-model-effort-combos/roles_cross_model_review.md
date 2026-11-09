# Per-role model allocation and cross-model (different vendor) code review

Research date: 2026-11-09. Source labels: [Primary research] = paper or first-party engineering post with data; [Vendor docs] = product documentation; [Vendor marketing] = a vendor benchmarking itself or its rivals; [Practitioner] = blog, forum or skill page, anecdotal.

## Q1. Planner/executor splits: does a strong planner plus a cheaper executor work?

### Takeaway
The best quantitative evidence (Aider 2024, Anthropic 2025) shows that splitting a strong reasoner from an executor matches or beats the strong model working alone, at lower cost. The gain comes from the split itself as much as from the model choice: pairing a model with itself also helped. Anthropic's current Claude Code tooling builds this in (`opusplan`, per-subagent `model` and `effort`), but its guidance is general ("larger models for complex or ambiguous tasks") and does not assign models to roles.

### Cited Findings
- **Aider architect/editor (Sep 26, 2024, older evidence):** o1-preview as architect with o1-mini or DeepSeek as editor scored 85.0% on Aider's code-editing benchmark, the top score at the time. o1-preview alone scored 79.7%. — [Aider blog](https://aider.chat/2024/09/26/architect.html) [Primary research, vendor's own benchmark]
- In the same benchmark, pairing a model with itself also beat that model solo: Claude 3.5 Sonnet/Sonnet 80.5% vs 77.4% solo; GPT-4o/GPT-4o 75.2% vs 71.4%; GPT-4o-mini/GPT-4o-mini 60.2% vs 55.6%. The largest gain was o1-mini as architect with DeepSeek as editor: 71.4% vs 61.1% solo. — [Aider blog](https://aider.chat/2024/09/26/architect.html)
- The strong reasoning model was most useful as architect, and the editor's job was mainly to apply edits reliably. For example, o1-preview with a Sonnet editor in diff format scored 82.7%. — [Aider blog](https://aider.chat/2024/09/26/architect.html)
- **Anthropic multi-agent research system (Jun 13, 2025):** an Opus 4 lead with Sonnet 4 subagents beat single-agent Opus 4 by 90.2% on Anthropic's internal research eval. — [Anthropic Engineering](https://www.anthropic.com/engineering/multi-agent-research-system) [Primary research, internal eval]
- On BrowseComp, three factors explained 95% of the performance variance. Token usage alone explained 80%; the others were number of tool calls and model choice. Upgrading from Sonnet 3.7 to Sonnet 4 gained more than doubling Sonnet 3.7's token budget. — [Anthropic Engineering](https://www.anthropic.com/engineering/multi-agent-research-system)
- Agents use about 4x the tokens of chat, and multi-agent systems about 15x. — [Anthropic Engineering](https://www.anthropic.com/engineering/multi-agent-research-system)
- The lead agent uses extended thinking and the subagents use interleaved thinking. The post gives no further per-role model guidance. — [Anthropic Engineering](https://www.anthropic.com/engineering/multi-agent-research-system)
- **Claude Code `opusplan`:** "uses `opus` during plan mode, then switches to `sonnet` for execution." The docs also point to an "advisor tool" that consults a second model mid-task instead of switching at the plan boundary. — [Claude Code model config docs](https://code.claude.com/docs/en/model-config) [Vendor docs]
- **Claude Code subagents:** subagents inherit the main conversation's model unless their definition sets `model`. A subagent without its own `effort` runs at the session's effort level. The docs say: "To keep a custom subagent on a smaller model, set `model` in its definition." `CLAUDE_CODE_SUBAGENT_MODEL` and the Agent tool's `model` parameter are other override points. — [Claude Code model config docs](https://code.claude.com/docs/en/model-config) [Vendor docs]
- **Claude Code effort guidance:**
  - `medium` "fits day-to-day engineering work with a clear scope, such as implementing a new feature."
  - `high` is for "work where verification matters or edge cases are likely, such as fixing a bug in an existing codebase."
  - `max` is for "hard problems you want Claude to work through without you, such as finding security vulnerabilities," but "may show diminishing returns and is prone to overthinking, so test before adopting it broadly."
  - Defaults: `medium` on Opus/Sonnet/Haiku 5.5, `high` on most other models.

  — [Claude Code model config docs](https://code.claude.com/docs/en/model-config) [Vendor docs]
- The docs suggest Fable for "root-cause investigations, outage debugging, and architecture decisions." — [Claude Code model config docs](https://code.claude.com/docs/en/model-config) [Vendor docs]
- **Anthropic blog (Lydia Hallie, Jul 7, 2026):**
  - "Choose smaller models for more routine tasks and larger models for more complex or ambiguous tasks."
  - "for most tasks you should use the model's default effort level."
  - Smaller models do better with directive prompts: "specific instructions directing execution are a better recipe for success on the smaller models."
  - Higher effort makes Claude "more predisposed to double-checking additional hypotheses or verifying correctness."
  - On harder multi-step work, a larger model can cost less per task overall, and "the larger model can accomplish tasks the smaller one cannot even at the highest effort settings."

  — [Claude blog](https://claude.com/blog/claude-model-and-effort-level-in-claude-code) [Vendor docs/blog]

### Inferences
- The evidence supports putting the strongest model, or the highest effort, on the planner/architect role. A detailed blueprint then lets a cheaper or lower-effort writer succeed, consistent with Anthropic's point that smaller models do best with directive instructions. This matches the kit's planner -> writer -> reviewer flow.
- Anthropic's own effort examples map directly onto roles:
  - writer on a clear-scope feature: `medium`
  - bug fix or verification-heavy work, i.e. reviewer: `high`
  - security-vulnerability hunting, i.e. security-auditor: `max`, tested before broad use
- That `max` is reserved for security is Anthropic's own example; applying it to the kit's auditor is an inference.
- "Token usage explains 80% of variance" suggests extra effort on a role is roughly a direct performance lever, but that finding is for research/browsing tasks, not code.

### Gaps
- I found no 2025–2026 controlled benchmark of planner/executor splits on coding with current models (Opus/Sonnet 4.x–5.x, GPT-5.x). The Aider data is from 2024. I did not check Aider's leaderboard for newer architect-mode entries.
- I found no published evidence comparing writer quality at `medium` vs `high` effort when the writer is given a detailed plan.
- The Anthropic research-system result is on research tasks. I did not find whether Anthropic's coding-specific multi-agent results follow the same pattern.

## Q2. LLM code review quality: precision, recall, false positives, and the effect of reasoning effort

### Takeaway
On public benchmarks the best AI reviewers catch roughly 40–70% of known bugs, with precision from about 45% to over 90% depending on tool and tuning. Recall and precision trade off, and every vendor-run benchmark puts its own tool first. OpenAI's Dec 2025 study is the strongest primary evidence on effort. Even a small review budget recovers a large share of known high-severity issues; extra budget mostly improves calibration and cuts false alarms. Repository access and code execution help.

### Cited Findings
- **OpenAI "scaling code verification" (Dec 1, 2025)** — [OpenAI Alignment Blog](https://alignment.openai.com/scaling-code-verification/) [Primary research, but OpenAI evaluating its own product]
  - OpenAI chose precision first, accepting "modestly reduced recall in exchange for high signal quality and developer trust." Recall and precision sit on a Pareto frontier that custom instructions or AGENTS.md can shift.
  - Even at a small fraction of the generator's token spend, the verifier catches a large share of previously identified high-severity issues. Extra budget "mostly improves calibration and reduces false alarms."
  - Performance falls faster with less thinking budget on model-generated code than on human-written code, and recall is consistently higher on human-written code. OpenAI reads this as a distribution shift: model-written code is harder to verify.
  - GPT-5 with repository access and code execution was a stronger reviewer, catching more critical issues with fewer false alarms. Dedicated review training improved it further. GPT-5.1-Codex improved both recall and precision.
  - Codex review comments on 36% of Codex-cloud-generated PRs, and 46% of those comments lead to a code change. The comparable figure on human PRs is 53%; across all comments it is 52.7%. Over 80% of reactions are positive.
  - Every internal OpenAI PR is reviewed automatically, and the system handled over 100k external PRs per day as of Oct 2025.
- **Greptile benchmark (Jul 2025):** Greptile reports catching 82% of 50 real bugs, vs Cursor Bugbot 58%, Copilot 54% and CodeRabbit 44%. No false-positive data. — [Greptile](https://www.greptile.com/ai-code-review-evaluation) [Vendor marketing]
- **Martian Code Review Bench (2026):** an open benchmark from a research lab, not a review vendor. The offline set is 50 PRs from 5 open-source projects whose bugs were later found and fixed. It reports precision, recall and F1; its dashboard defaults to F2, which weights recall double. — [Unblocked summary](https://getunblocked.com/benchmarks/code-review/); [Kilo blog](https://blog.kilo.ai/p/martians-independent-benchmark-tested)
  - Vendor-reported snapshots disagree because dates and leaderboards differ:
    - Greptile: 60.8% F1 (76.2% precision, 50.6% recall), Jul 30, 2026. — [Greptile](https://www.greptile.com/content-library/greptile-martian-code-review-benchmark) [Vendor marketing]
    - CodeRabbit: top F1 at 51.2%. — [CodeRabbit](https://www.coderabbit.ai/blog/coderabbit-tops-martian-code-review-benchmark) [Vendor marketing]
    - Unblocked: 68.4% recall, 58.7% precision. — [Unblocked](https://getunblocked.com/benchmarks/code-review/) [Vendor marketing]
    - GitLab Duo: 48.3% F1, Jun 3, 2026. — [GitLab Duo bench](https://duo-review-bench-6f7260.gitlab.io/benchmark/) [Vendor]
  - These vendor claims conflict with one another (each claims a lead). Check the live leaderboard (codereview.withmartian.com) before quoting a ranking.
- **Augment benchmark:** 7 tools on open-source PRs. Augment reports the top F-score at 59%; Cursor Bugbot 49% (60% precision, 41% recall); Greptile 45%; CodeRabbit 39%. — [Augment](https://www.augmentcode.com/blog/we-benchmarked-7-ai-code-review-tools-on-real-world-prs-here-are-the-results) [Vendor marketing]
- **Signal65 (Mar 2026):** Cursor Bugbot had the highest precision (95.95%) and fewest false positives (3); CodeRabbit found the most high-severity bugs. — [Signal65 PDF](https://signal65.com/wp-content/uploads/2026/03/Signal65-Insights_Evaluating-AI-Code-Review-Tools.pdf) [Analyst report; sponsorship not verified]
- **CodeRabbit on GPT-5-Codex vs GPT-5:** GPT-5-Codex made about 32% fewer comments with about 35% higher per-comment precision (46.3% vs 34.2%). — [CodeRabbit](https://coderabbit.ai/blog/gpt-5-codex-how-it-solves-for-gpt-5s-drawbacks) [Vendor, third-party to OpenAI]

### Inferences
- In a single-owner kit, false positives are the main cost: each one is a finding the owner has to triage. OpenAI's precision-first choice and its finding that extra budget mostly reduces false alarms suggest running the reviewer at `high` effort rather than `low`. Effort buys calibration more than raw recall.
- A reviewer that can run tests and read the repository is meaningfully better than one that only sees the diff, so the kit's reviewer should have read and test-execution tools.
- OpenAI finds model-written code harder to verify than human code. That argues for a stronger review setting in a fully agent-written workflow, not a weaker one.
- Best-tool recall of about 50–70% means a single AI review pass misses a third to a half of real bugs. Tests and CI remain the main safety net.

### Gaps
- None of the benchmarks I found isolates reasoning-effort levels (e.g., Claude `medium` vs `high` vs `max`) for review. OpenAI's thinking-budget curve is the only primary data, and only for its own models.
- I did not fetch Martian's leaderboard directly; the figures above come from vendor reposts with differing snapshots.

## Q3. Self-preference bias, correlated errors, and cross-family review

### Takeaway
Peer-reviewed evidence shows that LLM judges favor their own outputs, including when those outputs are wrong on verifiable code tasks. It also shows that errors are more correlated between models from the same provider or architecture. Both findings support using a different model family as the reviewer. But the same work finds that strong models from different providers also make highly correlated errors, and long chain-of-thought substantially reduces harmful self-preference. I found no controlled study measuring how many extra bugs a cross-vendor code reviewer (e.g., Codex reviewing Claude) catches; current evidence for that is anecdotal.

### Cited Findings
- **Correlated Errors in LLMs (Kim, Garg, Peng, Garg; ICML 2025, arXiv 2506.07962):** across 350+ LLMs, models that share a provider, base architecture or size have more correlated errors. On one leaderboard dataset, models agree 60% of the time when both are wrong. Larger, more accurate models have highly correlated errors "even with distinct architectures and providers." In LLM-as-judge setups, judges favor models from their own provider or architecture. — [arXiv 2506.07962](https://arxiv.org/html/2506.07962v1); [PMLR](https://proceedings.mlr.press/v267/kim25e.html) [Primary research]
- **LLM Evaluators Recognize and Favor Their Own Generations (Panickssery et al., 2024, older):** links self-recognition ability to self-preference. — [arXiv 2404.13076](https://arxiv.org/abs/2404.13076v1) [Primary research]
- **Self-Preference Bias in LLM-as-a-Judge (Wataoka et al., 2024, older):** judges give significantly higher scores to lower-perplexity (more familiar) text than human raters do, whether or not they wrote it. — [arXiv 2410.21819](https://arxiv.org/html/2410.21819v1) [Primary research]
- **Do LLM Evaluators Prefer Themselves... (arXiv 2504.03846, v3 Dec 2025)** — [arXiv 2504.03846](https://arxiv.org/html/2504.03846v3) [Primary research; open models only, no Claude or GPT-5 as judges]
  - Much self-preference is legitimate, because stronger models' outputs really are better.
  - Harmful self-preference, defined as favoring one's own objectively wrong answer, is large:
    - Qwen2.5-72B: 86% on MATH500 and 73% on MMLU.
    - Code (MBPP+): large models show harmful self-preference of roughly 50–75%, though overall self-preference stays below 40%.
  - Long chain-of-thought gives the lowest harmful self-preference for every model tested, with the biggest reduction on math and code.
- **Measurement caveat (arXiv 2601.22548, 2026):** argues that evaluator uncertainty accounts for an average of 89.6% of measured self-preference, so earlier figures may overstate the bias. — [arXiv 2601.22548](https://arxiv.org/pdf/2601.22548) [Primary research; from search summary, not fully read]
- **Rubric-based evaluation (Pombal et al., arXiv 2604.06996, 2026):** self-preference persists even with fully objective, programmatically verifiable rubrics. — [alphaXiv 2604.06996](https://www.alphaxiv.org/abs/2604.06996) [Primary research; from search summary]
- **OpenAI's own setup:** reviewer and generator are "the same model," trained differently for the two skills. OpenAI does not compare against a cross-vendor reviewer. — [OpenAI Alignment Blog](https://alignment.openai.com/scaling-code-verification/)
- **Practitioner reports on cross-vendor review:**
  - One developer runs Codex on every Claude-written diff: "Where Codex and Claude agree, that's signal. Where they diverge, that's the line I read myself." — [Zack Proser](https://zackproser.com/blog/codex-reviews-claudes-diffs) [Practitioner]
  - A Reddit user said cross-model review (GPT-5.4 reviewing Claude) "catches things self-review never does." A commenter said it is strongest on architecture decisions and weaker on line-level bugs, "where all models share similar blind spots." — [Reddit snapshot](https://reddit.sentinel-team.org/posts/1sflw5k/snapshots/2026-04-09T16%3A41%3A00.47446Z) [Practitioner, anecdotal]
  - OpenAI released an official Codex plugin for Claude Code (reported March 2026) with a `/codex:review` command for uncommitted changes. — [Reddit snapshot](https://reddit.sentinel-team.org/posts/1sflw5k/snapshots/2026-04-09T16%3A41%3A00.47446Z); [aiproductivity.ai](https://aiproductivity.ai/news/codex-review-claude-code-cross-model-validation/) [Secondary; not verified against an OpenAI primary page]
  - A cross-model review skill guide puts a 5–15% false-positive rate as normal and advises "triage findings, don't blindly fix everything." — [Daniel Vaughan](https://codex.danielvaughan.com/2026/03/28/cross-model-adversarial-review/); [MindStudio](https://www.mindstudio.ai/blog/cross-vendor-ai-agent-review-claude-codex/) [Practitioner/vendor-adjacent]

### Inferences
- The mechanism behind cross-family review is supported: same-provider errors correlate more, and self-preference exists. The size of the benefit for code review is unmeasured. Kim et al. suggest it shrinks as models get stronger, because strong models' errors converge.
- Two cheaper mitigations have evidence behind them and can stack with cross-family review:
  - Run the same-family reviewer with high reasoning effort, since long CoT cuts harmful self-preference.
  - Give it fresh context with no memory of writing the code. This one is speculative; I found no direct study of fresh-context reviewers.
- Speculative: cross-family review is most valuable where the reviewer can check against a spec or blueprint and where the two models' training differs most, such as design and architecture issues. Shared blind spots (common API misuse, common insecure patterns) are less likely to be caught by a second frontier model.
- Treating agreement between two vendors' reviewers as high-confidence and disagreement as "human reads this" is a practitioner heuristic, not a validated method.

### Gaps
- I found no controlled study of the form "Claude-written PRs reviewed by Claude vs by GPT/Codex, counting unique true defects found." This is the key missing evidence.
- I found no data on ensembles of review models (e.g., union or intersection of Claude + Codex findings) and their precision/recall.
- The self-preference studies mostly use open models (Qwen, Llama, Gemma). I found no results for Claude 4.x/5.x or GPT-5.x judging their own code.

## Q4. Security auditing and vulnerability detection: do stronger models or more reasoning help, and at what false-positive cost?

### Takeaway
Frontier models with agentic scaffolding and validation now find real, previously unknown vulnerabilities at scale (Anthropic: 500+ validated zero-days with Opus 4.6). Anthropic's own docs reserve `max` effort for vulnerability hunting. Academic benchmarks still report high false-positive and false-discovery rates for LLM detectors, especially on patched code and cross-procedure flows. Raw model output therefore needs a validation step before anyone acts on it.

### Cited Findings
- **Anthropic Frontier Red Team (Feb 5, 2026):** Claude Opus 4.6 found more than 500 zero-days in open-source code, mostly memory corruption. Each was validated before reporting, by Anthropic staff or outside researchers. — [red.anthropic.com zero-days](https://red.anthropic.com/2026/zero-days/); [Axios](https://axios.com/2026/02/05/anthropic-claude-opus-46-software-hunting) [Primary, but vendor reporting its own model]
- **Anthropic + Mozilla (Mar 6, 2026):** Opus 4.6 found 22 Firefox vulnerabilities in February 2026, "more than were reported in any single month in 2025." — [Anthropic/Mozilla](https://www.anthropic.com/research/mozilla-firefox-security); [red.anthropic.com Firefox](https://red.anthropic.com/2026/firefox/) [Primary, vendor]
- Anthropic then launched Claude Code Security as a limited research preview. — [Fortune](https://fortune.com/2026/02/06/anthropic-claude-ai-model-cybersecurity-security-vulnerabilities-risks/) [Press; launch timing from search summary]
- **Claude Code docs:** `max` effort is recommended for "hard problems you want Claude to work through without you, such as finding security vulnerabilities," with a caveat about diminishing returns and overthinking. — [Claude Code model config docs](https://code.claude.com/docs/en/model-config) [Vendor docs]
- **Project-scale study (arXiv 2601.19239, 2026):** five public LLM-based detectors and traditional tools all show high false-discovery rates. Root causes include shallow interprocedural reasoning and misidentified source/sink pairs. — [arXiv 2601.19239](https://arxiv.org/pdf/2601.19239) [Primary research; from search summary]
- **Patched-code study (arXiv 2601.22655, 2026):** fine-tuned models have large false-positive rates on patched code, suggesting surface pattern matching inflates scores. — [alphaXiv 2601.22655](https://www.alphaxiv.org/abs/2601.22655.md) [Primary research; from search summary]
- **VulnLLM-R (arXiv 2512.07533, Dec 2025):** a specialized reasoning model with an agent scaffold, compared against o3, DeepSeek-R1, QwQ-32B and Claude 3.7 Sonnet on F1, FPR and FNR. It notes PrimeVul mislabels some benign code as vulnerable, distorting benchmark scores. — [arXiv 2512.07533](https://arxiv.org/pdf/2512.07533) [Primary research; specific numbers not retrieved]
- **SecureMind (ISMM '25):** evaluates 10 LLMs, 7 of them reasoning models, on 16K samples across 8 CWEs, and notes excessive false positives as an adoption barrier. — [Glasgow PDF](https://www.dcs.gla.ac.uk/~jsinger/pdfs/ismm25.pdf) [Primary research; numbers not retrieved]
- **Older baseline (arXiv 2312.12575, 2023, older):** all eight LLMs tested had high false-positive rates and often flagged patched code as still vulnerable. — [arXiv 2312.12575](https://arxiv.org/html/2312.12575v3) [Primary research, predates reasoning models]
- **OpenAI (Dec 2025):** more review budget "mostly improves calibration and reduces false alarms" (general code review, not security-specific). — [OpenAI Alignment Blog](https://alignment.openai.com/scaling-code-verification/)

### Inferences
- The security-auditor role has the best case for the strongest model and highest effort: Anthropic's own role example for `max`, plus evidence that agentic, validated hunting with frontier models finds real bugs.
- The academic false-positive evidence means auditor output should require a reproduction or proof (a failing test, a trace or a PoC) before being rated Critical/High. Anthropic's 500 zero-days were all human-validated.
- The gap between "frontier model plus agentic scaffold plus validation finds real zero-days" and "LLM detectors have high false-discovery rates" is likely explained by scaffolding and validation, not the model alone. This is inference; I found no paper that directly attributes it.

### Gaps
- I found no published ablation of Claude effort levels (`high` vs `xhigh` vs `max`) on vulnerability detection precision or recall.
- I did not retrieve per-model false-positive figures from SecureMind or VulnLLM-R.
- I found no study of cross-vendor review specifically for security findings.

## Q5. When should a second reviewer run: every diff, high-risk changes, or pre-release?

### Takeaway
The industry leader on automated review (OpenAI) reviews every PR internally with one model family. Practitioners who add a second-vendor reviewer report either every diff or high-risk diffs, but I found no study comparing cadences. The evidence supports one strong automated reviewer on every change. A cross-family second opinion is a reasonable, unproven add-on for high-risk or large changes and before releases.

### Cited Findings
- OpenAI automatically reviews every internal PR and handled over 100k external PRs per day (Oct 2025). — [OpenAI Alignment Blog](https://alignment.openai.com/scaling-code-verification/) [Primary, vendor]
- Codex review is selective about commenting: it comments on only 36% of Codex-generated PRs, and roughly half of its comments lead to changes. Reviewing everything is cheap in noise if the reviewer is tuned for precision. — [OpenAI Alignment Blog](https://alignment.openai.com/scaling-code-verification/)
- A practitioner runs Codex on every Claude-written diff and reads only the lines where the two disagree. — [Zack Proser](https://zackproser.com/blog/codex-reviews-claudes-diffs) [Practitioner]
- Cross-model review costs two model calls instead of one per reviewed change, a practical cost of running it on every diff. — [MindStudio](https://www.mindstudio.ai/blog/cross-vendor-ai-agent-review-claude-codex/) [Vendor-adjacent blog]
- Anthropic's effort guidance ties higher effort to "work where verification matters or edge cases are likely," which supports scaling review effort with risk rather than using a flat setting. — [Claude Code model config docs](https://code.claude.com/docs/en/model-config) [Vendor docs]

### Inferences
- A defensible kit policy, labeled inference, not evidence:
  1. Same-family reviewer at `high` effort on every change; this is the kit's current workflow.
  2. A cross-family reviewer (e.g., `/codex:review`), optional or flagged, for larger changes (3+ files or migrations), security-sensitive paths, and before release.
  3. Security auditor at maximum effort before releases and quarterly, with findings validated before they block.
- Running two reviewers on every small fix probably costs more in owner triage time than it saves, given 5–15% false-positive rates per reviewer and a single-owner context. This is speculative.

### Gaps
- I found no empirical study comparing review cadences (every diff vs risk-gated vs pre-release) for AI reviewers.
- I did not fetch Anthropic's own published guidance on Claude Code's managed code-review product, or its recommended triggers, in this pass.
