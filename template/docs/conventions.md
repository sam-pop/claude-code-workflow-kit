# Conventions

Status: {{DRAFT | ADOPTED}}. This is the one file the planner, writer and reviewer cite. Every rule here is either **mechanical** (checked by `scripts/check.sh lint`, named in the Enforcement column) or **judgment** (checked by the reviewer). A rule with neither is a wish, not a convention; remove it or give it an enforcer.

## Architecture

{{Describe the layers and the one allowed direction of dependencies. Example:}}

- `{{ui/}}` → `{{domain/}}` ← `{{data/}}`. `{{domain/}}` imports nothing from the other two.
- {{External services (database, auth, payments, email) are reached only through `{{data/}}` behind an interface the domain defines.}}
- {{Entry points (routes, handlers, jobs, CLI) hold no business logic; they validate input, call the domain, shape the response.}}

## Dependency injection and configuration

- {{How dependencies are provided: constructor, context, module-level factory. One pattern.}}
- Config and secrets are read in one place ({{file}}) and passed down. No `process.env` / `os.environ` / equivalent outside it.

## Errors

- {{One error type or shape crosses layer boundaries (`AppError`, `Result`, exceptions mapped at the edge). Name it.}}
- Errors from vendors and the platform are mapped at the boundary where they occur.
- No silently swallowed errors on a user-triggered path.

## Data

- {{Schema source of truth and how migrations are made and applied.}}
- {{Reads vs writes: caching, local-first, transactions, whatever applies.}}
- {{Multi-tenancy or row-level rules, if any.}}

## Concurrency and async

- {{The one async model used. What is banned.}}

## Naming and files

| Thing | Pattern | Example |
|---|---|---|
| {{Files}} | {{kebab-case / PascalCase}} | {{example}} |
| {{Tests}} | {{mirror source path, `.test` suffix}} | {{example}} |
| {{Booleans}} | {{is/has/can prefix}} | {{example}} |

## Testing

Write a test where it catches a real bug: a mapper, a rule with branches, a write path, a failure the user would see. Skip tests that restate the implementation, check defaults, or exercise fakes. Tests use fakes injected through the normal DI path; no shared mutable state, no real network, no real clock.

Test runner: {{name}}. Pattern: {{arrange / act / assert, or the project's own}}.

## Logging and privacy

- Use the injected logger; no bare `print` / `console.log` in production code.
- Never log {{personal data: names, emails, tokens, addresses, document contents}}.
- Secrets never in source, tracked config or logs.

## Anti-patterns

Each row is a hard rule. **Mechanical** rows name the check in `scripts/check.sh lint`; **judgment** rows are the reviewer's.

| Anti-pattern | Enforcement |
|---|---|
| {{Vendor SDK imported outside `data/`}} | mechanical: {{lint rule name}} |
| {{Business logic in a route handler}} | judgment |
| {{`console.log` / `print` in production code}} | mechanical: {{lint rule}} |
| {{Hard-coded config or secret}} | mechanical: {{secret scan}} |
| {{Unhandled promise / swallowed error}} | mechanical: {{lint rule}} |
| {{Inline styles / magic numbers in UI}} | judgment |
| {{Test that asserts nothing or only initial state}} | judgment |
| Resolving an item in `docs/open.md` without the owner | judgment |
| Unrelated refactors mixed into a change | judgment |

## Definition of done

- `scripts/check.sh all` passes, or the report says exactly which part could not run.
- New behavior with branches or failure paths has a test that would catch its bug.
- No row of the Anti-patterns table is violated.
- Any new third-party dependency was called out for approval before being added.
- Any open item touched is still open, or the owner closed it and `docs/decisions.md` records it.
- `handoff.md` is rewritten if the session is ending.
