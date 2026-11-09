# Decisions

Decisions only. One line each, newest first, dated. No analysis, no options considered, no open items (those are in `open.md`). When an open item is decided, add it here with its ID and remove it from `open.md`.

Format: `- YYYY-MM-DD (was Oxx) — the decision, stated so it can be checked against the code.`

These are the design records for the kit itself. Each cites its evidence where one exists.

## Engineering

- 2026-11-09 — Maintainer tools are pinned, never fetched at whatever version is current: bats, bats-support, bats-assert and markdownlint-cli2 through `package-lock.json` (exact versions); shellcheck, shfmt, gitleaks, lychee and actionlint through `scripts/tools.sh`, each download checked against a sha256 written in the script before it is unpacked. One gitleaks version everywhere, enforced by `tests/consistency.bats`. Evidence: supply-chain practice of pinning by digest (as GitHub recommends for actions by full commit SHA).
- 2026-11-09 — The installable payload lives under `template/`; `scripts/install.sh` copies `template/` as is, and the repo root is an ordinary install of it (`scripts/install.sh .`), tailored to the kit. The kit runs its own workflow and checks; `tests/consistency.bats` fails when the root copies drift from `template/` in an unexpected way.
- 2026-11-09 — Scripts that run in target repos need python3 3.8 or later with the standard library only; no pip packages. Every target already has python3 on macOS and Linux; a package install would be a new step that fails silently.
- 2026-11-09 — Shell scripts target bash 3.2 with BSD and GNU userland: no `mapfile`, `declare -A`, `local -n`, `${x,,}`, `[[ -v`, `|&` or `coproc`. macOS ships `/bin/bash` 3.2, and hooks run with whatever `bash` is on PATH. CI runs the tests under macOS `/bin/bash` 3.2. Evidence: the 1.4 review cycle replaced a `mapfile` call in `scripts/check.sh` `lint --changed`, which bash 3.2 does not have.
- 2026-11-09 — The writer escalates to a fresh writer one rung up instead of retrying in the same context, and the ladder ends after three rungs. Evidence: `docs/research/coding-agent-model-effort-combos.md` ("A medium-to-high ladder beats fixed high on price and pass rate": escalating only failures was cheaper and solved more; a failed context carries the framing that failed).
- 2026-11-09 — Cross-model review (Codex) is off by default and never blocks. It sends diffs to a second vendor, and no study measures the extra true defects it finds; its value is in disagreement. Evidence: `docs/research/coding-agent-model-effort-combos.md` ("Codex earns a seat as a dissenting opinion, not a gate").
- 2026-11-09 — Model profile for this repo: standard (`scripts/set-models.sh standard`). Cross-model review: off.
- 2026-10-25 — An unconfigured check fails (exit 2, `NOT CONFIGURED`) instead of passing or skipping, so no report can say "lint passed" for a check that never ran. A check that does not apply is replaced by an explicit `skip "<reason>"`. Practice: agents claiming verification that did not happen (README, Why this exists: Claimed verification).
- 2026-10-25 — The reviewer reads the diff before the plan, in a separate read-only context. Reading the plan first anchors the reviewer on what was meant instead of what was written, and a model favours its own output when it grades it. Evidence: `docs/research/coding-agent-model-effort-combos.md` ("Review quality collapses below medium": self-preference of 50–75% on code tasks).

## Retired

(none)
