# Glossary

The project's shared language. One term per line, the meaning in one sentence, and where it lives in code. The planner reads it before naming anything new.

Why it matters: a term defined once replaces a sentence everywhere it appears, in code, docs, prompts and reviews. "The materialization cascade" is one token for the agent; "when a lesson is given a spot in the file system and its parents update" is thirty.

Rules:

- A term is added when it has been explained twice in conversation or appears in two files.
- One meaning per term. A second meaning gets a second term.
- Code uses the term verbatim (`Tenant`, not `Org` in one place and `Customer` in another).
- Retire a term by striking it and naming its replacement; do not delete the line.

| Term | Meaning | In code |
|---|---|---|
| Risk tier | Low, Medium or High: how much a change can hurt, which sets the reviewer's effort. | `CLAUDE.md` Workflow, Risk tiers |
| Rung | One step of the writer ladder: a fresh writer at a higher effort or model after the previous one failed. | `CLAUDE.md` Workflow, Writer ladder |
| `.kit` sibling | The kit's copy of a file, saved beside a tailored file during install or upgrade, for a merge by hand. | `scripts/install.sh` (`tailored`) |
| Upgrade class | How `install.sh --upgrade` sorts each kit file: replaced, current, tailored, tailored (kit unchanged), new, skipped, never re-added, retired. | `scripts/install.sh` (`classify`, `ORDER`) |
| Dogfood copy | A root file that is the kit's own install of the same path under `template/`, possibly tailored to the kit. | repo root vs `template/` |
| Check stamp | The record of the working tree on which `scripts/check.sh all` last passed. | `scripts/check-stamp.sh`; stored in `$(git rev-parse --git-path kit/check-passed.json)` |
