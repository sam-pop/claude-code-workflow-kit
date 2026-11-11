# Security

## What the kit guards

Claude Kit guards against **agent accidents**: a command that should not have run, a check reported as passed that never ran, a secret sent where it should not go. It does not guard against a hostile committer or a malicious dependency. Be clear about what this does and does not protect against.

- **Deny rules prevent accidents, not attacks.** They match command prefixes; a reworded command such as `git -C . push` can slip past them. They are not a sandbox.
- **Hooks execute repository code.** Anything in `.claude/settings.json` or `scripts/` runs on your machine. The lint hook runs your linters after every edit, so a linter config that is code runs too. Only install the kit in repos whose committers you trust, use the Review-only tier otherwise, and review changes to those paths, and to every file your hooks, linters, formatters, tests or build execute (for example `eslint.config.js`, `.markdownlint-cli2.cjs`, `conftest.py`, `package.json` scripts, a `Makefile`), before opening Claude Code on a branch.
- **The security auditor is a first pass, not a pen test.** It makes routine review cheap and consistent; client-facing systems still need human security review. Opus 5.5 reroutes most security work to Opus 4.8, so the audit report records the served model (from `/tasks`) instead of assuming it.
- **Fable bills credits.** On Pro and standard Team plans from the first request; `claude -p` does so without asking. Set a cap in `/usage-credits`.
- **Codex egress.** With the codex extra on, the diff leaves for OpenAI. On client work, get the client's consent. The extra is not available on Review-only.
- **Confidence scores are the model's own estimate.** The "below threshold" list and the escaped-defect metric exist so you can tune them from evidence.
- **Not yet battle-tested across many stacks.** Expect your first tailoring to find something to fix, and please send it back.

## The Codex extra, in short

`scripts/codex-review.sh` sends Codex one prompt and nothing else: the plan text, or the diff with 20 lines of context plus the reviewer checklist and `docs/conventions.md` from the base branch. Codex starts in an empty directory. gitleaks is required and scans the prompt once, with inline `gitleaks:allow` markers ignored and the base branch's `.gitleaks.toml`; a finding, or a gitleaks that cannot run, refuses the run. A changed, deleted or untracked secrets-file name refuses it too. The scan is a best-effort guard against accidents, not a security boundary: its blind spots (unprefixed secrets, UTF-16, encoded or compressed text, file-name-scoped rules, a permissive base config) are listed with the eight guarantees and their tests in [`template/docs/rollout.md`](template/docs/rollout.md#codex).

## Scanner findings

A finding whose only effect is a secret passing the gitleaks pre-scan gets a line in the blind-spot list in `template/docs/rollout.md`, not new code. Code changes only when a documented guarantee is false, and narrowing the claim is the first option. There is one security audit and one re-check of its fixes per release; a further round needs a failure seen in use. The record is in `docs/decisions.md`.

## Reporting a vulnerability

Use GitHub private vulnerability reporting: open the repository's **Security** tab and choose **Report a vulnerability**, or go to <https://github.com/sam-pop/claude-code-workflow-kit/security/advisories/new>. Please do not open a public issue for a vulnerability, and do not include real secrets in a report. Say which file or script is affected, how to reproduce it, and what an attacker gains.

This is an early-status project maintained by one person, so there is no response-time guarantee. A report that shows a documented guarantee to be false is fixed first.
