# Review log

Every reviewer and security-auditor report lands here automatically (`scripts/capture-review.sh`, on the SubagentStop hook), named `<date>-<sha>-<review|security>.md`. This folder is the raw material for the improvement loop; nothing here is edited by agents.

## What you do with a finding

Edit the saved report, not the chat:

- Fixed → `- [x] [95] …` (tick the box).
- Not a real issue → `- [x] [95] … — dismissed: <short reason>`. Use the **same wording** for the same reason each time; `check.sh doctor` counts recurring reasons and suggests them for the reviewer's false-positives list.
- Real but deferred → leave unticked and add the O-id you created for it in `docs/open.md`.

## Monthly pass (ten minutes)

1. `scripts/check.sh doctor` — read the review stats and the recurring-dismissal lines.
2. A finding category that recurs 3+ times across reports → write the lint or semgrep rule, add it to `check.sh lint`, and mark the conventions row **mechanical**.
3. A dismissal reason that recurs 2+ times → add a line to the reviewer's "False positives".
4. Reports older than 90 days: delete, or keep only the ones tied to an accepted risk.

Pre-committed thresholds (3 and 2) are deliberate: change them in `docs/decisions.md`, not ad hoc.

## Privacy

Reports quote code. On a Shared repo, that is fine inside the repo; never paste one into a chat, ticket or email outside it without reading it first.
