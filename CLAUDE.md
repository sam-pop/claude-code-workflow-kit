# Claude Kit

The kit itself: templates, agents, hooks and scripts installed into other repositories (`template/`), maintained here with its own workflow (the root is an install of `template/`).

The main session reads `docs/open.md` first. Items in `docs/open.md` are the owner's to decide: design around them and flag them. When one is decided, record it in `docs/decisions.md` and remove it from `docs/open.md`.

## Stack

- Shell: bash 3.2 or later, BSD and GNU userland (macOS and Linux); inline Python: python3 3.8 or later, standard library only.
- Git and GitHub; CI in `.github/workflows/check.yml`.
- Maintainer tools: node 22 (`.nvmrc`) with `npm ci` for bats and markdownlint-cli2; `scripts/tools.sh install` for shellcheck, shfmt, gitleaks, lychee and actionlint (pinned, checksum-verified, into `.tools/bin`).

## Commands

Verify through `scripts/check.sh`, so every agent, hook and CI run checks the same thing.

```bash
scripts/check.sh lint      # shellcheck, shfmt, markdownlint-cli2, lychee (offline), actionlint
scripts/check.sh test      # bats tests/
scripts/check.sh build     # skipped: the kit ships source
scripts/check.sh security  # gitleaks, tracked sensitive files
scripts/check.sh doctor    # kit hygiene
scripts/check.sh all       # everything
```

Setup once: `npm ci && scripts/tools.sh install`. One test file: `npx bats tests/install.bats`. After editing anything under `template/`: `scripts/install.sh --upgrade .`, merge any `.kit` files, delete `.claude/kit-upgrade.md`.

## Layout

| Path | Contents |
|---|---|
| `template/` | The product: exactly what `scripts/install.sh` installs. Edit here. |
| root `CLAUDE.md`, `.claude/`, `docs/`, `scripts/`, `.github/` | Dogfood copies of `template/`, tailored to this repo; synced with `scripts/install.sh --upgrade .` |
| `scripts/install.sh`, `scripts/kit-upgrade-prompt.md`, `scripts/tools.sh` | The installer, the merge-session prompt it embeds, and the pinned maintainer tools; never installed |
| `tests/` | bats tests, `helpers.bash`, `stubs/`, `fixtures/` |
| `docs/research/` | Evidence behind the model and effort defaults |
| `README.md`, `CHANGELOG.md` | Public docs; the installer reads the version from `CHANGELOG.md` |

## Rules

Full rules: `docs/conventions.md`. The short version:

- Edit `template/` first, then sync the root with `scripts/install.sh --upgrade .`.
- Write shell for bash 3.2 and BSD userland; python3 inline code uses the standard library only.
- Add no runtime dependency to `template/`: targets need only bash, git and python3.
- Never overwrite a file a target tailored: the installer writes a `.kit` sibling instead.
- Every bug fix ships with a bats test that fails without the fix.
- Keep `template/CLAUDE.md` at 150 lines or fewer.
- A behaviour change updates README, `template/HOW-TO-USE.md` and the CHANGELOG Upgrade notes.

## Workflow

Run agents in the foreground, one at a time, and wait for each report before starting the next.

1. **Small fix** (1–2 files, obvious, reversible): make the change in the main session, run `scripts/check.sh all`, then the **reviewer** agent.
2. **Larger change** (3+ files, a migration, or the owner asks): the **planner** agent; it states the risk tier (`template/docs/rollout.md`, Risk tiers), and you confirm the tier with the owner. Put its Questions to the owner in one round, each with its recommended answer, and wait. Then the **writer** agent with the confirmed blueprint, then the **reviewer** agent.
3. **Before a release**, and quarterly: the **security-auditor** agent. Critical and High findings block the release only when they carry a reproduction; note the served model (from `/tasks`) on the saved report.
4. Report the reviewer's findings and what was done with each before committing. Pushing and merging are the owner's.

Agents brief each other through the delegation prompt: name the change, the files, the blueprint if any and the base branch.

Extras that are on (`scripts/extras.sh status`) add rules: follow each one's section in `template/docs/rollout.md`, Extras. With **profiles** on, its risk tiers and writer ladder authorise passing the Agent tool's `effort` parameter, never `model`, and the rung and risk tier go in each writer and reviewer prompt. With **codex** on, its plan review runs on the planner's blueprint before the owner's question round. This repo has profiles, stop-warning, verify-review and metrics on and codex off.

## Recording

- Decisions → `docs/decisions.md`, dated.
- Open items → `docs/open.md`, with an ID (`Oxx`), an opened date, a decide-by date and an owner.
- `template/` holds nothing about this repo or its maintainer: no names, emails, pre-release plans or root-only paths (`tests/consistency.bats`).

## Environment

No secrets and no services. Without `npm ci` and `scripts/tools.sh install`, `scripts/check.sh` fails and names the missing tool. Tests need no network; they use stubs in `tests/stubs/` for codex, gitleaks, timeout and claude unless `KIT_REQUIRE_REAL_TOOLS=1`.
