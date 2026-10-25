# Open items

The single list of things not yet decided. Every item has an ID; other documents and code comments refer to the ID instead of restating the question. Agents design around these items and flag them; the named owner decides.

When an item is decided, record it in `decisions.md` with "(was Oxx)" and delete it here. When a new question comes up, add it here rather than inline in another doc. `scripts/check.sh doctor` warns when an item is past its decide-by date and fails above 15 items, so the list stays short enough to act on.

Format: `- **Oxx** (opened YYYY-MM-DD, decide by YYYY-MM-DD, owner) — the question. Blocks: what.`

## Engineering

- **O1** (opened {{YYYY-MM-DD}}, decide by {{YYYY-MM-DD}}, {{owner}}) — {{question}}. Blocks: {{what}}.

## Product

- **O2** (opened {{YYYY-MM-DD}}, decide by {{YYYY-MM-DD}}, {{product owner}}) — {{question}}. Blocks: {{what}}.
