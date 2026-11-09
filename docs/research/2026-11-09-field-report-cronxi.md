# Field report: Cronxi upgrade to kit 1.5 — proposed kit changes

- **Date:** 2026-11-09
- **Source:** Cronxi (production SaaS, Shared tier), upgraded from pre-1.4 (kit `c5ac6c4`) to 1.5 (`0709d16`) in Cronxi PR #586.
- **Method:**
  1. An Opus agent (high effort) compared the owner's own workflow with `template/`: the global `CLAUDE.md`, a per-project lessons file, and Cronxi's workflow and deploy docs.
  2. A fresh Fable agent re-derived every finding from the files and labelled each one CONFIRMED, PARTLY or WRONG.
  3. Only confirmed findings that apply to any repo appear here. Cronxi-only ones stay in Cronxi.
- **Line numbers** refer to `template/` at `0709d16`. Each finding also quotes the line, so it survives drift.

Each item gives the problem, the evidence, the change, and a CHANGELOG/Upgrade line. Items are ordered by impact: correctness and security first, then upgrade path, cost, ergonomics.

---

## 0. SECURITY BUG: `verify-review.sh` reads outside the repository (found by Codex on Cronxi #586; fixed there)

**Problem.** `resolve()` checks that the *cited* path stays inside the repository. When that path is not a file, it falls back to a suffix match against the changed files, and returns that candidate unchecked. Repro:
1. A changed file `src/escape` is a symlink to a file outside the repo.
2. A review cites `escape:1` and quotes a line of the outside file.
3. The script opens the target and reports `quotes: 1 verified`.

This also runs automatically through `capture-review.sh`, the SubagentStop hook.

**Second bug in the same script.** `for ref in (base, "origin/" + base)` prefers a stale local `<base>` over `origin/<base>`, unlike `check.sh`. In Cronxi, local `main` gave 181 changed files where `origin/main` gave 18, so coverage flagged unrelated upstream files as unread.

**Fix (as applied in Cronxi):**
```diff
-for ref in (base, "origin/" + base):
+for ref in ("origin/" + base, base):
...
-    return cands[0] if len(cands) == 1 else None
+    return cands[0] if len(cands) == 1 and inside(cands[0]) else None
```
Cronxi's regression tests (`scripts/__tests__/verifyReview.test.mjs`) reproduce both bugs in a scratch git repo, with a symlinked changed file and a clone whose local `main` is behind. Each test fails when its fix is reverted. Port both to the kit's bats suite.

**Porting trap (it bit Cronxi).** Tests that run git in a scratch directory must drop every inherited `GIT_*` variable. Under a git hook, `GIT_DIR` points at the real repository. Cronxi's first version of these tests passed when run directly, but under its pre-push hook (which runs the suite) it:
- committed into the real branch;
- set `core.bare=true` in the shared `.git/config`.

Prove isolation with a decoy: run with `GIT_DIR=<tmp>/decoy.git` and check that no repository appears there. Audit the kit's bats suite and `install.sh` tests for the same exposure.

**CHANGELOG (Fixed):** "`verify-review.sh` no longer follows a shortened citation to a changed symlink outside the repository, and diffs against `origin/<base>` first."
**Upgrade note:** none. The file is kit-owned, so an untailored copy is replaced in place.

## 1. Security auditor: fail closed on an unreproduced Critical/High

**Problem.** An unreproduced Critical or High finding does not block a release; it goes to the owner as a decision. The safe default is the reverse: block until someone rules on it.

**Evidence.**
- `CLAUDE.md:48`: "Critical and High findings block the release only when they carry a reproduction".
- `.claude/agents/security-auditor.md:53`: "Without one, mark the finding `unreproduced`; the owner decides."
- Cronxi changed this back when it tailored the kit, and keeps it after the upgrade: "an unreproduced one still blocks until the lead rules on it".

**Change.**
- `security-auditor.md:53`: "Without one, mark it `unreproduced`. It still blocks until the owner rules on it, recorded on the saved report (fix, park with an ID, or accept with a stated ceiling)."
- `CLAUDE.md:48`: make the matching edit.
- Keep the reproduction requirement for *severity*: an unreproduced finding can be downgraded, but only on the record.

**CHANGELOG (Changed):** "An unreproduced Critical/High blocks the release until the owner rules on it (it used to pass to the owner silently)."
**Upgrade note:** "A tailored `security-auditor.md`: merge the new sentence at line 53."

## 2. High risk raises the writer's starting point, not only the reviewer's effort

**Problem.** The risk tier changes only the reviewer's effort. A High change (auth, money, timers, migrations) starts on the same rung-1 writer as a typo fix, and moves up only after something fails mechanically. Field lesson: a fixer patched 2 of 3 identical bug sites "to keep the diff minimal". No escalation trigger fired, because every check passed.

**Evidence.**
- `CLAUDE.md:55`: "The tier sets the reviewer's effort."
- The ladder triggers at `CLAUDE.md:71` are all mechanical.

**Change.** In `CLAUDE.md` Workflow:
- **Risk tiers:** "On High the writer starts at rung 2 (Agent `effort: high`) under a change contract: the invariants it must not touch, named in the brief. It also produces a list of every block it moves or copies, which the reviewer checks."
- **Writer ladder:** add the trigger "a fix that reaches some sites of the bug class the reviewer named but not all".
- **`reviewer.md` Checklist:** "For each fix, find the other sites of the same bug class (grep the pattern) and confirm each one is fixed or explicitly out of scope."

**CHANGELOG (Changed):** "High-risk changes start the writer at rung 2 with a change contract and a moved-block list; a partial bug-class fix escalates."

## 3. Reviewer: break each fix (mutation check) and name concrete risks

**Problem.** Neither `reviewer.md` nor the writer's brief asks anyone to confirm that a test actually pins each fix. Field evidence from Cronxi:
- Reviewers told to mutate each fix killed 16 of 19 mutations. That exposed 3 paths no test pinned, behind a green suite of about 13k tests.
- A brief naming 3–5 concrete risks found more than "check everything".

**Evidence.** No mention of mutation, breaking a fix, or named risks in `template/.claude/agents/reviewer.md`.

**Change.**
- `reviewer.md` Checklist:
  - "For each behavioural fix, revert or mutate it locally and confirm at least one test fails; restore it, and confirm the tree matches the reviewed commit. Report the mutations as `killed n/m`."
  - "The brief names 3–5 concrete risks; address each by name before general review."
- `planner.md` Output: "Risks to probe (3–5, concrete)."

**CHANGELOG (Added):** "Reviewer mutation check (`killed n/m`) and named risks in the plan."
**Caveat:** a mutation pass needs a scratch copy so the review tree stays clean. Say so in the agent text.

## 4. A lessons file that every brief inlines

**Problem.** Agents repeat their failure modes, for example:
- reporting tests that never ran;
- `check; echo` masking a failing exit code;
- losing work when a worktree is auto-removed.

The owner's fix is a per-project lessons list, with the relevant items pasted into every brief. The kit has no such mechanism. Cronxi's own list lives in machine-local memory, so a cross-model reviewer or a fresh machine never sees it.

**Change.**
- New tracked file `docs/lessons.md`: one line per observed agent failure mode, dated, each with the rule that prevents it.
- `CLAUDE.md` Workflow: "Inline the relevant `docs/lessons.md` entries into every writer and reviewer brief. Add an entry when an agent fails in a new way."
- `doctor.sh`: warn when `docs/lessons.md` is missing or unchanged for 90 days on an active repo (optional).

**CHANGELOG (Added):** "`docs/lessons.md`, inlined into briefs."

## 5. Writer rules: fail-first test, `Not verified:`, no attribution

**Problem and evidence.** `template/.claude/agents/writer.md` already requires pasted output (line 71: "the exit code and the last 3 lines of its output, pasted, not summarised"). It does not require:
- (a) a failing test before the fix;
- (b) a final `Not verified:` line listing what was not exercised;
- (c) commits and PR text free of tool attribution, which many owners require.

Field lesson: a writer reported "100 passed" for a file that never ran. A `Not verified:` line makes gaps explicit.

**Change.** `writer.md` Rules:
- "Write the test first and show it failing (exit code and tail) before the fix."
- "End the report with `Not verified:` (or `Not verified: nothing — all changed paths exercised`)."
- Attribution: "Follow the repo's attribution rule in `docs/conventions.md`." Ship the template line `Commits and PRs carry no tool attribution` as a default the owner can delete.

**CHANGELOG (Changed):** "Writer: fail-first tests, a `Not verified:` line, the attribution rule from conventions."

## 6. Git hygiene for parallel agents

**Problem.** The kit's deny list blocks destructive git, but the failures seen in the field came from ordinary commands in shared or auto-removed trees:
- `git add -A` swept up another agent's files.
- A resumed agent lost a round of work when its worktree vanished.
- A stale local `main` nearly reverted 4 deploys.
- A broad `pkill` killed another session's dev server.
- A report written inside an auto-removed worktree was lost.

**Change.** `docs/conventions.md` → "Git and processes", and the writer's Rules:
- "Stage by explicit path; never `git add -A` / `.`."
- "Commit after every green step."
- "Before committing, check the branch and `git rev-list --left-right --count origin/<base>...HEAD`."
- "Kill only processes you started (by PID); never a pattern `pkill`."
- "Write reports and scratch output outside any worktree the harness may remove."

**CHANGELOG (Added):** "Git and process hygiene rules for parallel agents."

## 7. "Done" for a deploy means verified in production

**Problem.** The template has no deploy guidance beyond the planner's "Undo" step (`planner.md:34`, `:53`). Field incidents:
- A deploy that skipped the CDN purge never reached users, three releases in a row.
- Deploying from a stale branch nearly reverted live work.

**Change.**
- `CLAUDE.md` gets a short Deployment section: "A deploy is done when a post-deploy check against production passes, not when the deploy command exits. Deploy from a branch whose base is the current `origin/<base>`, and prove `<base>` contains what production runs before deploying."
- Plus an optional `docs/DEPLOY.md` stub with Before / Deploy / Verify / Rollback headings.

**CHANGELOG (Added):** "Deployment section and `docs/DEPLOY.md` stub."

## 8. Tier efforts are not profile-aware (Fable)

**Problem.** The High row sends the reviewer to `xhigh`. On a profile whose reviewer is Fable, the kit's own header says that buys little. Cronxi's reviewer is Fable, so it tailored High back to `high`.

**Evidence.**
- `scripts/set-models.sh:14`: "Fable barely gains from effort."
- The High row in the tier table (`CLAUDE.md`) says `xhigh`.

**Change.** Tier table High cell: "`xhigh` (`high` when the reviewer runs on Fable)". Have `set-models.sh` write a one-line note in `docs/decisions.md` when it sets a Fable reviewer.

**CHANGELOG (Changed):** "High-tier reviewer effort is `high` on a Fable reviewer."

## 9. Upgrades from a repo with no manifest: do a real three-way merge

**Problem.** A repo installed before 1.4 has no `.claude/kit-manifest`. Every tailored file then arrives as a `.kit` sibling, and the merge prompt asks the session to "merge it into its original". That is a two-way diff, so all of the owner's tailoring shows up as differences. In Cronxi: 18 files, nearly all conflicts. What worked was `git merge-file` per file:
- base = the kit commit the repo was tailored from (found by the smallest diff against candidate commits);
- ours = the repo's file;
- theirs = the 1.5 `template/` copy.

That left 5 clean files and 34 conflict hunks that genuinely needed a decision.

**Pitfall seen in the field.** Since 1.5 the kit repo also has its own root copies of these files, carrying kit-only rules (bats, bash 3.2 self-checks, `template/` paths). A merge that takes "theirs" from the root instead of `template/` drags those in. In this upgrade, the files that merged cleanly were byte-identical between root and `template/`, but several conflicted files were not.

**Change.**
- `scripts/kit-upgrade-prompt.md`, step 2:
  - "When `.claude/kit-version` records a base commit, run `git merge-file` per file with base = that commit's `template/` (or root, before 1.5) copy, ours = the repo file, theirs = the `.kit` file. Resolve only the conflict hunks."
  - "Never take kit text from the kit repo's root copies; only `template/` is installable."
- `install.sh --upgrade`:
  - also write `<file>.kit-base` when the base is known;
  - for a repo with no manifest, offer `--base <kit-commit>`, and print the candidate commit whose files are closest to the repo's.
- `.claude/kit-version`: record `base=<commit>` at install time from 1.5 on. It already records `commit=`; use it as the base on the next upgrade.

**CHANGELOG (Changed):** "Upgrades do a three-way merge (`.kit-base`); `--base` for repos without a manifest."

## 10. `set-models.sh` and `doctor` can silently undo a tailored seat choice

**Problem.**
- `doctor.sh:96` tells the user to run `scripts/set-models.sh <profile>` whenever an agent has no `effort:` line.
- `docs/rollout.md:30` says "switch any time".
- On a repo that tailored its seats (Cronxi keeps a Fable reviewer, while 1.5's `max` makes it Opus), following either one rewrites `model:` lines the owner chose.

**Change.**
- `doctor.sh:96`: "add an `effort:` line (or run `set-models.sh` if the seats are untailored)".
- `set-models.sh`: refuse, without `--force`, to change a `model:` line that differs from every profile's value for that role. Print the role and both values.
- `rollout.md:30`: "…switch with `set-models.sh` unless `docs/decisions.md` records tailored seats".

**CHANGELOG (Changed):** "`set-models.sh` keeps tailored seats unless `--force`."

## 11. Smaller items

- **Codex reports from other transports.** `verify-review.sh` and the doctor's Codex stats only see reports saved under `docs/reviews/` by `capture-review.sh`. Owners who run Codex another way (a peer terminal, `codex exec`) skip quote verification. Add `scripts/capture-review.sh import <file> codex` to file an external report, which runs `verify-review.sh` on it.
- **Optional plan review and blocking mode for `--cross`.** `CLAUDE.md:67` says Codex "never blocks" and sees only High diffs and releases. For owners with Codex quota, offer `--cross=plan,block`:
  - Codex reviews the planner's blueprint in a fresh session;
  - its whole-branch verdict gates merge.

  Field evidence: a fresh cross-model adversary found 4 plan defects the lead had missed, including 3 critical advisories in a second lockfile. Keep the default off.
- **The Stop hook only sees the lead's tree.**
  - `check-stamp.sh` fingerprints `CLAUDE_PROJECT_DIR` (line 95), so writer worktrees are invisible to it.
  - After a commit it goes silent (lines 16–17).
  - Document in `rollout.md` that it is a nudge, not a gate.
- **`settings.json` names `codex-reviewer` in the SubagentStop matcher** (line 55) even when `--cross` is off. It's harmless. Have `set-models.sh --cross` add it instead.
- **The doctor's open-item scan no longer reads code** (1.5). An `Oxx` cited only in a code comment can now dangle. Consider `DOCTOR_SCAN_CODE=1` to restore the old `git grep` over tracked files.

---

## Not proposed (Cronxi-only)

The following stay in Cronxi:
- the Codex-via-Orca transport;
- Fable/Codex seat assignments;
- Firebase emulator secret isolation (`demo-` project id plus placeholder secrets);
- `verify:deployed` and CDN purge details;
- the self-hosted CI runner.

Not verified: none of these changes was implemented or run against the kit's own test suite; line numbers are as of `0709d16`.
