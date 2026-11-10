# Contributing

Thanks for helping. This file is for changes to the kit itself; using the kit is in `README.md` and `template/HOW-TO-USE.md`.

## Set up

You need bash, git, python3 3.8 or later and node 22 (`.nvmrc`).

```bash
npm ci                     # bats, bats-support, bats-assert, markdownlint-cli2 (exact versions)
scripts/tools.sh install   # shellcheck, shfmt, gitleaks, lychee, actionlint into .tools/bin, checksum-verified
```

`scripts/tools.sh` supports linux-x64 and darwin-arm64. Elsewhere, install the versions `scripts/tools.sh versions` prints and put them on PATH.

## Check

```bash
scripts/check.sh all          # what CI runs on Linux
npx bats tests/install.bats   # one test file
```

A missing tool is a FAIL that names the command to install it, never a skipped check. CI also runs the tests under macOS `/bin/bash` 3.2.

## Make a change

1. Edit under `template/`: that is what gets installed. The root copies are this repo's own install.
2. Sync the root: `scripts/install.sh --upgrade .`, merge any `.kit` file into the root copy, then delete the `.kit` files and `.claude/kit-upgrade.md`. `tests/consistency.bats` fails if the root drifts.
3. Run `scripts/check.sh all`.

## Rules

- Shell runs on bash 3.2 with BSD and GNU userland: no `mapfile`, `declare -A`, `local -n`, `${x,,}`, `[[ -v`, `|&` or `coproc`; under `set -u` expand arrays as `${a[@]+"${a[@]}"}`.
- Inline Python uses the standard library only and runs as `python3 -I`. Nothing in `template/` may need anything beyond bash, git and python3.
- Every bug fix comes with a bats test that fails without it, named after the bug.
- Tests use the helpers in `tests/helpers.bash` and the stubs in `tests/stubs/`; they need no network, and fake secrets are generated at runtime (`fake_token`), never committed.
- A behaviour change updates `README.md`, `template/HOW-TO-USE.md` and the Upgrade notes in `CHANGELOG.md`.
- Keep `template/CLAUDE.md` at 150 lines or fewer, and keep changes small: explain the failure a change prevents.
