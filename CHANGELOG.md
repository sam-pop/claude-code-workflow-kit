# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). `scripts/install.sh` reads the version from the first `## [x.y]` heading below.

## [1.7] — unreleased

### Fixed

- `scripts/extras.sh` owns a hook only when its command is exactly the one the kit writes (`"${CLAUDE_PROJECT_DIR}/scripts/check-stamp.sh" hook`), under the event the kit writes it to. Before, any hook whose command merely mentioned `scripts/check-stamp.sh` counted as the kit's: `off stop-warning` deleted it, and `on stop-warning` skipped adding the kit's own.
- `scripts/extras.sh on` and `off` check that the file being moved, not only its destination, resolves inside the repo, and `sync` checks both ends of each move; a symlinked `.claude/optional/` or `scripts/` leading outside the repo is refused and names the path.
- `scripts/codex-review.sh` runs gitleaks from inside each scanned directory, on `.`, so the paths it matches are relative. A `.gitleaksignore` fingerprint (`src/a.txt:github-pat:1`) and a `^`-anchored path allowlist in the base's config now match a file the change leaves alone; before, gitleaks saw absolute paths under the temporary directory, so they never matched and the run was refused. The change under review still gets no exemption. The same relative paths end the blind spot for a `TMPDIR` under a default-allowlisted directory such as `node_modules/`.
- `scripts/codex-review.sh` scans a canary first: a token generated at run time, in a scratch directory, with the same flags and the base's config. If the scan does not report exactly that token, the run is refused (exit 5, "the secret scan is not working here"), for example when the base's config cannot be loaded or exempts it. A base config with a relative `[extend] path` is still refused, now by this check.
- `scripts/codex-review.sh` starts Codex with `safe.bareRepository=explicit` (appended to any `GIT_CONFIG_COUNT` entries in the environment), so Codex's own git does not discover a tracked `config`, `HEAD`, `objects/` and `refs/` as a bare repository. Not verified with the real Codex CLI.
- The 1.5 note overstated the lint hook: it passes the last 40 lines of lint output (printable ASCII, 300 characters a line) so Claude can fix what lint found; the Stop warning and the review-saved message carry counts and at most three names.
- `verify-review.sh` stopped with a Python traceback and no `### Verification` block when a finding cited a path containing a NUL byte. Such a citation is now `unverified — path outside the repository`, and control characters in a cited path print as `?`.

### Upgrade notes

- Codex review: the secret scan now proves it works by finding a canary GitHub token first, so a base `.gitleaks.toml` with only custom rules (no `useDefault`, no GitHub-token rule) refuses every run (exit 5); add `[extend] useDefault = true` or a GitHub-token rule.
- A Stop hook whose command you edited by hand is no longer treated as the kit's: `extras.sh status` warns and `on stop-warning` adds the kit's own.
- A `.gitleaksignore` or `^`-anchored allowlist in the base branch's gitleaks config now applies to the Codex review; a fingerprint written for an absolute path under the temporary directory no longer matches. Fingerprints are `path:rule:line` with `path` relative to the repo root.

## [1.6] — 2026-11-10

### Added

- Core and extras. A fresh install is the core process; five opt-in extras are off until you switch them on with `scripts/extras.sh on <name>`: `profiles`, `codex`, `stop-warning`, `verify-review`, `metrics`. An extra is its files: dormant in `.claude/optional/`, active at `.claude/agents/<file>.md` or `scripts/<file>.sh`. `scripts/extras.sh status|on|off|sync` moves the files and adds or removes only the kit's own hook entry in `.claude/settings.json`; `status` warns about a half-enabled extra, a hook left behind, Codex without its CLI and `CODEX_API_KEY` in a workflow. Core scripts call an extra's script only when it is active.
- `scripts/review-stats.sh` (metrics extra): the review-log counts that `check.sh doctor` used to print always.
- `scripts/stuck-detect.sh` (profiles extra): `scripts/check.sh` prints `same failure N times: <args>` after three identical failures (durations, times and addresses ignored), the writer's first stop rule. State is kept as hashes only; with the extra off `check.sh` keeps no state.
- `scripts/codex-review.sh plan <file>` (codex extra): Codex reviews the planner's blueprint, sending only the plan text under the same gitleaks scan and tooling checks, before your question round. Saved as `*-codex-plan.md`; the codex-reviewer's Bash guard allows `plan <file>` for a relative `*.md` path inside the repo; the script refuses git-ignored paths and secrets-file names.
- `check.sh doctor` warns when `reviewer.md` and `writer.md` use the same `model:`.
- `scripts/set-models.sh` refuses to overwrite a seat that is none of the profiles' values for its role; `--force` overrides.
- The writer writes each test first and shows it failing, and ends its report with `Not verified:`; the reviewer reads that line.
- `docs/rollout.md` has a core Risk tiers section and one Extras section per extra.
- `HOW-TO-USE.md`: an Extras table, and a paragraph on handing work to another agent or person.
- README: "What makes it different" and "Core and extras".

### Changed

- Profiles now keep the model that wrote the code from reviewing it. lite: sonnet/high planner and writer, opus/medium reviewer, opus/high auditor. standard: opus/high planner, sonnet/high writer, opus/high reviewer, opus/xhigh auditor (the writer was opus/medium). max: opus/high planner, opus/medium writer, fable/high reviewer and auditor (Fable was the planner).
- The writer ladder raises effort only and never passes Agent `model`: lite and standard go sonnet/high, sonnet/xhigh, stop; max goes opus/medium, opus/high, opus/xhigh, stop. The High risk tier changes only the reviewer's effort. The `CLAUDE.md` Workflow is about ten lines; tiers, ladder and per-extra rules moved to `docs/rollout.md`.
- `scripts/check-stamp.sh` (stop-warning extra) fingerprints the working tree from `git ls-files -s` and `git status` and hashes changed files itself: nothing is written to `.git/objects` or the index, `docs/reviews/` and untracked files over 1 MiB are left out, and a commit of unchecked changes still warns. The stamp is `kit/check-passed.json` (the 1.5 `kit/check-passed` is ignored and deleted by the next record); the command line is unchanged.
- `scripts/check-stamp.sh`, `scripts/verify-review.sh` and `scripts/set-models.sh` live in `.claude/optional/` until their extra is on. `scripts/set-models.sh` also warns about Claude Code older than 2.1.292, `effortLevel` in `~/.claude/settings.json` and Fable billing (moved from `doctor`); `--cross` is gone.
- `check.sh doctor` is shorter: review stats need the metrics extra, and the checks for the stop-warning stamp lines, Codex and `CODEX_API_KEY` are part of `extras.sh status`, which `doctor` shows.
- `scripts/install.sh` finds an extra's active files through `active_path` (this replaces the codex-reviewer alias), updates them in place, never re-adds one you deleted, and finishes with the kit's `extras.sh sync`.
- Review reports from the Codex plan review and `*-codex-plan.md` are counted with Codex reports.
- `codex-review.sh plan <file>` takes only a `*.md` file that is not git-ignored and not a secrets file (`.env`, `*.pem`, `*.p12`, SSH keys); the guard checks the same name rules.
- `verify-review.sh` prefers `origin/<base>` over a local base branch and never resolves a short citation to a changed symlink that leaves the repo.
- `scripts/extras.sh` acts on the repo it sits in (`KIT_EXTRAS_REPO` selects another); `CLAUDE_PROJECT_DIR`, which belongs to hooks, is ignored.
- The security auditor fails closed: an unreproduced Critical or High finding still blocks the release until the owner rules on it on the saved report (fix, park with an open-item ID, or accept with a stated limit).
- The High risk tier sets reviewer effort to `xhigh`, or `high` when the reviewer runs on Fable (max): Fable lost about 1.8 points of bug-finding from `high` to `low`.

### Removed

- `handoff.md` and `docs/glossary.md` are no longer installed. The session-start and session-end ritual, the handoff freshness warning in `doctor` and the glossary pointers are gone.
- `scripts/set-models.sh --cross`; use `scripts/extras.sh on codex`.

### Fixed

- Every inline Python the kit runs (hooks, the installer, `extras.sh`, `set-models.sh`, the Codex guard) now runs as `python3 -I`, so a `json.py` or `re.py` in the working directory is no longer imported. Before, a repo holding such a file could run code from the Stop and SubagentStop hooks and the installer, and could switch off the codex-reviewer's Bash guard. `tests/consistency.bats` fails on a `python3` or `python3.N` call that lacks `-I`, takes its script from a redirect or heredoc without `-`, or puts its options on a continuation line.
- `codex-review.sh` exports the review tree with every configured filter driver's smudge off (git-crypt, transcrypt, LFS), so Codex gets files as stored in git instead of decrypted content; an untracked file behind a filter driver is named in the report and not sent.
- `codex-review.sh` gives the change under review no exemption from the secret scan: the prompt and every changed or untracked file (not only untracked ones) are scanned with gitleaks' own `--ignore-gitleaks-allow`, at their own path and as a copy under a bare number that no path allowlist matches. A `-diff` or `binary` attribute, a nested `gitleaks:gitleaks:allowallow` marker (which survived the earlier marker-stripped copy) and a path that `.gitleaks.toml` or gitleaks' defaults allowlist (`package-lock.json`, `*.svg`, `go.sum`, `node_modules/`) can no longer hide a credential in the change. A refusal names the file behind each numbered scan copy.
- `codex-review.sh plan <file>` refuses a path through a symlinked directory and a path when `git check-ignore` gives no clear answer, so a git-ignored file cannot be reached through a link.
- `codex-review.sh`'s secret scan copies are written after a newline, because gitleaks skips content whose first bytes look like a known binary format (`%PDF`, `MZ`, SQLite, gzip): before, a prefixed credential in a changed or untracked file led by such bytes was sent. Each changed or untracked file is now also scanned as `scan/named/<n>/<file name>`, so a path-scoped rule (`nuget.config`, `.npmrc`) still fires for a file under an allowlisted directory such as `node_modules/`. The working-tree patch is applied with `apply.whitespace=nowarn`, so a user's `apply.whitespace=fix` no longer alters the review copy.
- `codex-review.sh` applies the working-tree patch from outside the review tree (`git apply --directory`), so a tracked `config`, `HEAD`, `objects/` and `refs/` can no longer make the tree a bare repository whose filter drivers run during the apply; an inherited `GIT_DIR` is cleared for it, and if git can still find any repository from the temp directory the run refuses (exit 1) instead of dropping the working-tree edits.
- The review boundary now covers files that linters, formatters, tests and build execute, not only `.claude/` and `scripts/`: the lint hook runs your linters after every edit, and a linter config that is code runs on your machine. The README, `HOW-TO-USE.md`, `docs/rollout.md` and `TAILOR.md` say so.
- `codex-review.sh` trusts only commits on the base branch: `high <ref>`, `release <ref>` and the plan's merge-base must be ancestors of `origin/<base>`, or of the local base when there is no remote-tracking copy, else exit 2; a tag or branch literally named `origin/<base>` is refused as ambiguous. `release` with no ref starts from the newest tag on the base branch, and plan mode refuses a local base at HEAD as high mode does.

### Upgrade notes

- Nothing is lost: an upgrade keeps each extra as the repo had it. From 1.5, `stop-warning`, `verify-review`, `profiles` (with `stuck-detect.sh`) and `metrics` stay on and `codex` stays as it was. From 1.4, `profiles` and `metrics` come on and `stop-warning` and `verify-review` arrive off; switch them on with `scripts/extras.sh on <name>`. Run `scripts/extras.sh status` afterwards and record the result in `docs/decisions.md`.
- Switching an extra rewrites `.claude/settings.json` with 2-space indentation. An untailored copy comes back byte-identical after `on` then `off`. While a hook-bearing extra (`stop-warning`) is on, `.claude/settings.json` differs from the kit's copy, so later upgrades list it as tailored even if you never edited it, and later kit changes to it arrive as `.kit` merges. A tailored copy keeps its other entries.
- `--cross` moved: `scripts/set-models.sh <profile> --cross` is now `scripts/extras.sh on codex`.
- `handoff.md` and `docs/glossary.md` show as retired; they are not deleted and are now your own files. Delete them or keep them. Remove their lines from your `CLAUDE.md` and the glossary pointer from `.claude/agents/planner.md`.
- A tailored `scripts/check.sh`: add the line that hands the run to the stuck detector, right after the `cd`, and keep the stamp lines from 1.5. Both do nothing until their extra is on, and `extras.sh status` warns when an extra that is on lacks its line:

  ```bash
  [[ -z "${KIT_STUCK_INNER:-}" && -f scripts/stuck-detect.sh ]] && exec bash scripts/stuck-detect.sh "$@"
  ```

- A tailored `.claude/settings.json`: the `Stop` hook belongs to the stop-warning extra. If you merge by hand, keep the entry when the extra is on, then run `scripts/extras.sh sync`.
- The profile values changed (see Changed). With profiles on and untailored seats, re-apply with `scripts/set-models.sh <lite|standard|max>`: the standard writer moves to Sonnet/high only then. `set-models.sh` refuses (exit 1, nothing changed) a seat whose model/effort is none of the profiles' values for its role, so a tailored agent file stays as you set it; `--force` overrides. The reviewer and the writer now differ in every profile, and `doctor` warns when they match.
- The stop-warning stamp has a new format: expect one warning until the next `scripts/check.sh all` passes.
- A tailored `CLAUDE.md`: the Workflow section is shorter. Move your risk-tier and ladder text to `docs/rollout.md` or take the kit's version.
- Re-running an older kit's `--upgrade` over a 1.6 repo is not clean, but destroys nothing: active extra files show as tailored `.kit` files, dormant ones as retired, and 1.5's installer re-installs the dormant extras at their active paths as `new` (the extras then run, so run `scripts/extras.sh status` and switch off what you did not want).
- `codex-review.sh` (codex extra): `high <ref>`, `release <ref>` and `plan` now refuse (exit 2) a trusted ref that is not on `origin/<base>`; when your base is not the default branch, set `BASE_BRANCH` in the session environment (the guard allows no `VAR=…` prefix on the command; use the `env` block of `.claude/settings.json`). Without `origin/<base>` the local base is trusted, so anything committed on it counts.
- A changed file that holds an older `gitleaks:allow` line now refuses the run (exit 5); remove the marker or rotate the secret.
- The Codex secret scan is a best-effort guard against accidents, not a security boundary. Read the blind-spot list in `docs/rollout.md` (codex, Egress): unprefixed secrets, UTF-16 and re-encoded text, compressed or encrypted content, untouched files under gitleaks' default path exemptions, and a `TMPDIR` under a `node_modules/` or `vendor/` path (which switches the scan off). Anything Codex may not see stays out of the repo, or leave the codex extra off.
- Codex sees LFS pointers and encrypted blobs, not checked-out content; an untracked file behind a filter driver (a new LFS asset or git-crypt file) is named in the report as filtered and not sent.
- Plan paths through a symlinked directory are refused (exit 2).
- A changed or untracked file at a path that `.gitleaks.toml` or gitleaks' defaults allowlist is now scanned: a fake secret in a changed fixture or lockfile refuses the run (exit 5). Allowlist by value (`regexes`, `stopwords`), not by path. Files the change leaves alone keep the path allowlists, so a credential already committed in a lockfile or SVG is still sent.
- A tailored `scripts/check.sh`: prefer linter invocations that load no code from the tree (for markdownlint-cli2, the API options `noImport`, `noGlobs` and `optionsOverride: {fix: false}`; for lychee, `--config /dev/null`) and hand each linter its files as `./path` so a tracked file named like an option is a file name; otherwise treat those config files as part of what to review on an outside branch.
- Re-read the widened review boundary in `docs/rollout.md` (Review-only) before opening Claude Code on a branch from someone you don't fully trust.
- With the codex extra on, the first `high` run after upgrading refuses (exit 5) until the upgraded `codex-review.sh` is on the base branch, because the script differs from the base's copy.

## [1.5] — 2026-11-09

### Added

- `scripts/check-stamp.sh` and a `Stop` hook: `scripts/check.sh all` records the working tree it passed on (in `.git/kit/check-passed`, never committed), and when Claude finishes a turn after files changed since, the session shows which files. Silent when nothing changed and until `check.sh` is configured.
- `scripts/verify-review.sh`: each saved review and Codex report gets a `### Verification` block. Every Standards and Spec finding now quotes the line it cites; the script checks the quote against the file (within 3 lines, or a removed line in the diff), checks that `### Coverage` names every changed file, and lists missing sections. Issues also show as a one-line message when the report is saved.
- `.github/dependabot.yml` for the SHA-pinned actions.
- `check.sh doctor` review stats count incomplete reports and unverified quotes, and warn when `scripts/check.sh` does not run `scripts/check-stamp.sh record`.
- `DOCTOR_SKIP_PATHS` (space-separated) leaves paths out of the doctor's open-item scan, for a vendored copy of something that uses its own IDs.
- `check.sh doctor` warns when a tailored repo (no `TAILOR.md`) still has the `hashFiles('TAILOR.md')` CI gate, or when `CLAUDE_CODE_USE_BEDROCK`, `_VERTEX` or `_FOUNDRY` is set (aliases differ by provider).
- More `permissions.deny` rules: `git branch -f`, `git update-ref`, `git stash clear`, `gh pr create`, `gh pr merge`, `gh repo delete`, `gh repo edit`, `gh repo archive`, `gh repo create`, `gh repo sync`.

### Changed

- The installable files live under `template/` in the kit repository; `scripts/install.sh` copies `template/` as is and never writes into the kit, so it works from a read-only copy or one without `.git`. Installed paths are unchanged: a repo installed from 1.4 upgrades with nothing retired.
- The merge-session prompt moved to `scripts/kit-upgrade-prompt.md` in the kit (it was never installed).
- The reviewer's Output: findings name the full `path:line` with the source line quoted under it, and a new `### Coverage` section lists every changed file read (or why not).
- `check.yml`: top-level `permissions: contents: read`, concurrency with cancel-in-progress, a 20-minute timeout, actions pinned to a commit SHA with `persist-credentials: false`, gitleaks 8.30.1 downloaded and checked against its sha256 before unpacking, semgrep pinned.
- gitleaks 8.30.1 everywhere (was 8.21.2).
- `scripts/codex-review.sh` hardening: gitleaks is required (exit 3 without it; before, the scan was skipped with a warning and the diff was sent); the reviewer checklist sent to Codex comes from the base, not the change; the run refuses (exit 5) when the change edits `scripts/codex-review.sh` or `codex-reviewer.md`, or when a tracked `.env`, `*.pem`, `*.p12` or SSH key would be sent; the trusted base is `origin/<base>` when `<base>` is a branch with a remote-tracking copy (any other ref is used as given), and a local base at or ahead of HEAD is refused (exit 2); tracked and untracked symlinks and `.codex/` are removed from the review tree and listed, with names made printable; an `AGENTS.md` is named in the report header. Limitation, documented: a base `.gitleaks.toml` with a relative `[extend] path` cannot be resolved, so the run refuses as if secrets were found.
- `max` and the Astra release model are labelled experimental; `pin()` is gone from `codex-review.sh` (it only guarded constants).
- Hook messages carry counts and at most three quoted, printable-ASCII names (40 characters), never raw file names or tool output: the Stop warning, the review-saved message and the lint hook's output.
- `scripts/verify-review.sh`: coverage counts only exact paths on the `read:` line; a finding with no parsable path counts as `unparsed` (an issue); a bold label before the path is accepted; quotes under 12 non-space characters and 2 words are `quote too short`; the removed-line fallback needs the `(removed)` prefix; paths outside the repository are never opened.
- The doctor's open-item scan reads only kit-owned files (`CLAUDE.md`, `handoff.md`, `docs/*.md`, `.claude/agents/`, `.claude/optional/`), and an ID must stand alone, so `-O2` and IDs in code no longer count.
- Agents described as "Read-only" are now described as having no edit tools, with Bash limited by instruction; reviewer quotes replace secret values with `…`.
- Shell scripts formatted with shfmt and clean under shellcheck; behaviour unchanged except where Fixed says so.
- The kit repository installs itself at its root and runs its own checks (shellcheck, shfmt, markdownlint, lychee, actionlint, a bats suite, gitleaks) in CI on Linux and macOS `/bin/bash` 3.2.

### Fixed

- `scripts/codex-review.sh` stops with `codex-review: git diff failed` (exit 1) when building the diff fails, for example on a required clean filter that errors; before, it reviewed a partial diff.
- `CLAUDE.md` wrote the example open-item ID as `O1`, so `check.sh doctor` failed on any tailored repo whose `docs/open.md` had no O1. It now reads `Oxx`.
- `check.sh doctor` read codex report names with spaces as several files.
- `scripts/install.sh` made every `scripts/*.sh` in the target executable, including the target's own scripts; it now sets the mode only on files it writes (executable when the kit's copy is, and every `.sh`, so a kit copy that lost its modes still installs runnable scripts), and refuses (exit 1, before writing anything) when a destination, its `.kit` sibling or a state file resolves outside the target through a symlink, dangling or not. A second positional argument is a usage error (exit 2) instead of silently winning.
- `scripts/capture-review.sh`: two reports in the same second overwrote each other; a counter is added and no file is overwritten. When `verify-review.sh` times out or fails, the report gets `not run (timeout|error)` and the session is told.
- `check.sh lint --changed` fell back to nothing when the base branch exists only as `origin/<base>`.
- `check.sh doctor` read CRLF frontmatter only with GNU sed.

### Upgrade notes

- A tailored `scripts/check.sh`: add the two stamp lines to `run_all`, the first before `lint`, the second after `doctor`:

  ```bash
  local rc=0 t
  t=$(bash scripts/check-stamp.sh tree 2>/dev/null)
  ...
  [[ $rc -eq 0 && -n "$t" ]] && bash scripts/check-stamp.sh record "$t"
  ```

  Without them the Stop hook stays silent and `check.sh doctor` warns.
- A tailored `.claude/settings.json`: add the `Stop` hook entry (`"${CLAUDE_PROJECT_DIR}/scripts/check-stamp.sh" hook`, timeout 30).
- A tailored `.claude/agents/reviewer.md`: merge the new Output format (the quote line under each finding, `### Coverage`, the paragraph about verification). Keep the five sections `codex-review.sh` reads (from the base's copy, so an edit takes effect once it is on the base): Confidence, Checklist, Subtle violations, False positives, Output.
- A tailored `.github/workflows/check.yml`: adopt `permissions`, `concurrency`, `timeout-minutes`, the SHA-pinned checkout with `persist-credentials: false` and the gitleaks checksum step.
- `.github/dependabot.yml` arrives as new (or as `.kit` if you have one); delete it if you use another updater.
- Deleting `scripts/check-stamp.sh` but keeping the `Stop` entry in `settings.json` makes every turn end with a (non-blocking) hook error; remove both or neither.
- A tailored `.github/workflows/check.yml`: delete the "Kit not tailored yet" step and every `if: hashFiles('TAILOR.md')` line once `TAILOR.md` is gone; `doctor` warns while they remain.
- Cross-model review now needs gitleaks on the machine that runs it, and in high mode a base that is not HEAD: work on a branch, or keep `origin/<base>` fetched.
- An open-item ID used only in code comments is no longer checked by `doctor`; keep IDs in `docs/` or `CLAUDE.md`.
- A tailored `.claude/settings.json`: merge the new deny rules.
- Re-running `install.sh --upgrade` from a 1.4 kit after upgrading to 1.5 lists `scripts/check-stamp.sh`, `scripts/verify-review.sh` and `.github/dependabot.yml` as retired; they are not deleted.

## [1.4] — 2026-11-09

### Added

- Effort per role: `scripts/set-models.sh` writes `effort:` beside `model:`.
- Profile `lite` (Sonnet/high planner, writer and reviewer; Opus/high auditor) for Pro ($20) plans.
- Risk tiers (Low, Medium, High) that set the reviewer's effort, and a writer escalation ladder, both in the `CLAUDE.md` Workflow section.
- The writer's `## STUCK:` report and stop rules; `scripts/capture-review.sh` saves it as `*-stuck.md`.
- Optional cross-model review: `--cross` enables `codex-reviewer`, which relays `scripts/codex-review.sh` (Codex in a fresh copy of HEAD with no `.git`, gitleaks pre-scan of that copy and of the prompt, read-only sandbox, `timeout`). Reports are saved as `*-codex.md`.
- `scripts/install.sh --upgrade` (with `--force` for an unfinished merge) and `--dry-run`, `.claude/kit-version`, `.claude/kit-manifest`, and `.claude/kit-upgrade.md` (the merge prompt plus the classification; say "Read .claude/kit-upgrade.md").
- Doctor checks for settings that undo the effort setup (`CLAUDE_CODE_EFFORT_LEVEL`, `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, old Claude Code, `effortLevel`, `maxEffortLevel`), for Sonnet below `high`, for a missing `effort:`, for Fable billing, and for an unfinished upgrade merge. Review stats now count Codex reports and escalations separately.
- Research report and notes under `docs/research/`; README sections on cost, cross-model review, troubleshooting and upgrading.

### Changed

- Standard profile: planner opus/high, writer opus/medium (was Sonnet), reviewer opus/high, auditor opus/xhigh. The `max` profile: Fable planner and auditor, Opus writer and reviewer.
- The security auditor's Critical and High findings block a release only with a reproduction; its report records the served model.
- The reviewer's report gains a `### Run` line (tier, writer rung, requested model and effort).
- Claude Code v2.1.292 or later is required (the Agent tool's per-call `effort`).
- The installer copies only files tracked in the kit checkout (`git ls-files`), and no longer copies `README.md`, `CHANGELOG.md`, `docs/research/`, `docs/assets/` or the kit's own review log.

### Fixed

- `scripts/doctor.sh` no longer fails on binary files or on research and release documents when it looks for undeclared open-item IDs.

### Upgrade notes

- The writer is now opus/medium: re-run `scripts/set-models.sh <profile> [--cross]` after merging.
- If `.claude/settings.json` is tailored, add `codex-reviewer|writer` to the `SubagentStop` matcher (`reviewer|security-auditor|codex-reviewer|writer`).
- Merge the `CLAUDE.md` `## Workflow` text: risk tiers, cross-model review and the writer ladder.
- The reviewer's output gains a `### Run` line, and the auditor's a `Run:` line.
- A repo from before 1.4 has no manifest, so every existing kit file that differs from 1.4 arrives as `.kit` once. Then open Claude Code and say: Read .claude/kit-upgrade.md

## [1.3]

- Fixes from an adversarial audit of the kit (commit d5fe8e1, "v1.3: fixes from adversarial audit").

## [1.2]

- Claude Kit v1.2 (commit 8b33a24).
