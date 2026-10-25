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
| {{Term}} | {{One sentence. What it is, not how it is implemented.}} | {{type, table or module}} |
