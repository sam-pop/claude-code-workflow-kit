# Decisions

Decisions only. One line each, newest first, dated. No analysis, no options considered, no open items (those are in `open.md`). When an open item is decided, add it here with its ID and remove it from `open.md`.

Format: `- YYYY-MM-DD (was Oxx) — the decision, stated so it can be checked against the code.`

## Engineering

- {{YYYY-MM-DD}} — Stack: {{language/framework/runtime}}. Hosting: {{where}}. Database: {{which}}.
- {{YYYY-MM-DD}} — {{e.g. "All verification goes through `scripts/check.sh`; agents never run raw tool commands."}}
- {{YYYY-MM-DD}} — Model profile: {{lite | standard | max}} (scripts/set-models.sh). Cross-model review: {{off | on: Codex sees High-risk diffs and each release range, which leave for OpenAI; not available on Review-only}}.

## Product

<!-- kit: only if a product owner's decisions are recorded separately from engineering. Delete the section otherwise. -->

- {{YYYY-MM-DD}} — {{decision}}

## Retired

<!-- kit: decisions that were reversed. Keep the original line and add "(reversed YYYY-MM-DD, see …)". History is useful; deletion is not. -->
