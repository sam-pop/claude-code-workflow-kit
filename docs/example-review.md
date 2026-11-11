# Example reviewer report

An illustration of the format, not a real review. The change is made up: a CSV export added to a multi-tenant app. The `### Verification` block appears only with the verify-review extra. Back to the [README](../README.md#daily-use).

```markdown
## Review: Add invoice CSV export

### Summary
Adds a per-tenant CSV export of invoices. Not merge-ready: one data-isolation
issue and one test that cannot fail.

### Run
tier: High · writer rung: 1 (trigger: none) · requested: opus/xhigh

### Checks
lint: 0 (writer said 0) · test: 142 passed / 0 skipped vs base 138 / 0 · build: 0

### Standards
- [ ] [92] `src/app/api/invoices/export/route.ts:18` — tenant ID is read from the
      query string → take it from the session; as written, any signed-in user
      can export another tenant's invoices.
  > const tenantId = req.nextUrl.searchParams.get("tenant");
- [ ] [88] `src/lib/invoices/export.test.ts:41` — expected CSV is built with the
      same toCsvRow() the code uses (tautological) → assert against a literal
      fixture.
  > const expected = rows.map(toCsvRow).join("\n");

### Spec
- [ ] [86] `src/app/api/invoices/export/route.ts:30` — "Exports are limited to the
      selected date range" → the range is parsed but never applied.
  > const { from, to } = parseRange(req); … db.invoice.findMany({ where: { tenantId } })

### Risks probed
- A tenant's export includes another tenant's invoices — read the query and the
  test fixtures → held
- An empty date range returns every invoice — traced parseRange → finding [86] above

### Considered, below threshold
- [70] src/lib/invoices/export.ts:12 — loads all rows into memory; fine at
      current volume, worth streaming above ~50k invoices.

### Not reviewed
Column order and headers against what finance expects.

### Coverage
read: src/app/api/invoices/export/route.ts, src/lib/invoices/export.ts, src/lib/invoices/export.test.ts
not read (reason): none

### Verification
checked: 2026-11-09 14:02 · base: main@1a2b3c4 · scripts/verify-review.sh
status: complete
quotes: 3 verified, 0 unverified, 0 unquoted
coverage: 3 changed files, 0 not in ### Coverage
```

The checks line is the point: the reviewer re-ran the checks and compared them with the writer's claim. A mismatch there is a blocking finding in itself. The `### Verification` block (verify-review extra) is not written by the reviewer: when the report is saved, `scripts/verify-review.sh` looks up each quoted line in the file it cites and checks that every changed file is named on the `read:` line of `### Coverage`. It checks form, not judgment: a quote that exists, a path that was listed. A quote it cannot find means the finding may describe code that is not there, so you read that one first.
