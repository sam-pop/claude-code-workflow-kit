# Review log

Every reviewer, security-auditor, codex-reviewer and stuck-writer report lands here automatically (`scripts/capture-review.sh`, on the SubagentStop and SubagentHandback hooks; it saves any final message starting `## Review:`, `## Security audit:`, `## Codex review:`, `## Codex plan review:` or `## STUCK:`), named `<date>-<time>-<sha>-<review|security|codex|codex-plan|stuck>.md`. This folder is the raw material for the improvement loop; nothing here is edited by agents.

Kinds:

- `review`, `security`: the Claude reviewer and auditor. The reviewer's `### Run` line (tier, writer rung and trigger, requested model/effort) is the per-task ladder log, filled in when the profiles extra is on; on audits, fill in the `served:` model from `/tasks`.
- `codex`: the Codex second opinion (codex extra); a plan review is saved as `*-codex-plan.md`. Mark its findings the same way as any other.
- `stuck`: a writer that hit a stop rule. These are escalation records, not findings to tick off.

With the metrics extra on, `check.sh doctor` counts each kind (`codex (30d)`, `escalations (30d)`).

## Verification

Only with the verify-review extra on (`scripts/extras.sh on verify-review`). When a review or codex report is saved, the hook runs `scripts/verify-review.sh` on it and appends a `### Verification` block:

```text
### Verification
checked: 2026-11-09 14:02 · base: main@1a2b3c4 · scripts/verify-review.sh
status: complete
quotes: 4 verified, 1 unverified, 0 unquoted
- unverified [92] src/export.ts:41 — quote not found within ±3 lines
coverage: 6 changed files, 1 not in ### Coverage: src/routes.ts
```

- `status` is `incomplete` when a required section is missing (Summary, Run, Checks, Standards, Spec, Considered below threshold, Not reviewed, Coverage; codex reports need no Run).
- A quote is `verified` when the text after the `>` marker under a finding appears within 3 lines of the cited lines, or on a line the diff removed. `unverified` means the reviewer may be describing code that is not there: check that finding first. `unquoted` findings have no quote line.
- `coverage` lists changed files the reviewer did not name under `### Coverage`.

When anything is off, the hook also shows a one-line summary in the session. With the metrics extra on, `check.sh doctor` counts incomplete reports and unverified quotes in its review stats.

## What you do with a finding

Edit the saved report, not the chat:

- Fixed → `- [x] [95] …` (tick the box).
- Not a real issue → `- [x] [95] … — dismissed: <short reason>`. Use the **same wording** for the same reason each time; `check.sh doctor` counts recurring reasons and suggests them for the reviewer's false-positives list.
- Real but deferred → leave unticked and add the O-id you created for it in `docs/open.md`.

## Monthly pass (ten minutes)

1. `scripts/check.sh doctor` — with the metrics extra on, read the review stats and the recurring-dismissal lines.
2. A finding category that recurs 3+ times across reports → write the lint or semgrep rule, add it to `check.sh lint`, and mark the conventions row **mechanical**.
3. A dismissal reason that recurs 2+ times → add a line to the reviewer's "False positives".
4. Reports older than 90 days: delete, or keep only the ones tied to an accepted risk.

Pre-committed thresholds (3 and 2) are deliberate: change them in `docs/decisions.md`, not ad hoc.

## Privacy

Reports quote code. On a Shared repo, that is fine inside the repo; never paste one into a chat, ticket or email outside it without reading it first. A quote never carries a secret value: the reviewer replaces it with `…`, and the elided quote still verifies.
