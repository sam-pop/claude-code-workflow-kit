# Open items

The single list of things not yet decided. Every item has an ID; other documents and code comments refer to the ID, never restate the question. **Agents do not pick a value for an item here.** They design against the boundary, code around it, and flag the dependency in their report.

When an item is decided: record it in `decisions.md` with "(was Oxx)" and delete it here. When a new question comes up: add it here, not inline in another doc.

Format: `- **Oxx** — the question, what it blocks, who decides.`

## Engineering

- **O1** — {{question}}. Blocks: {{what}}. Decides: {{owner / engineer}}.

## Product

- **O2** — {{question}}. Blocks: {{what}}. Decides: {{product owner}}.

## Research needed

<!-- kit: items that need information, not a decision. The answer goes in a note under docs/research/ and the item moves to Engineering or Product. -->

- **O3** — {{what we need to find out}}.
