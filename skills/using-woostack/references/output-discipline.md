# Output Discipline

Rules for user-facing replies, subagent handbacks, worker reports, and log/report writes.
Does not apply to authored source, documentation, commit messages, or PR descriptions.
Link here instead of restating these rules.

**Governing principle: strip the wrapper, never the reasoning.** Terseness applies to the
*wrapper prose* — preamble, narration, pleasantries, hedging, and repetition. It never applies to
risk-bearing reasoning.

## Replies and reports

- Lead with the conclusion, result, or blocker. Include a next action only when it is useful.
- Drop tool-call narration, preambles, pleasantries, generic transitions, and completion recaps
  that only repeat the answer.
- State each fact once. Prefer short paragraphs or bullets. Skip decorative headings, emoji, and
  tables; use a table only when comparison benefits from columns.
- Use structured, named fields for internal handbacks and reports; fragments are fine.
- Keep code symbols, file paths, line numbers, CLI commands, and error strings **verbatim**.
- Use standard technical terms, not invented abbreviations or compressed grammar the reader must
  decode.
- User requests for more detail override the terse default. Answer the requested depth without
  restoring filler.

## Keep a real consumer's fields exact

When an actual receiving tool or workflow branches on a field, keep that field's exact name and
values. With no such consumer, report the result, its evidence, the uncertainty that remains, and
any blocker in clear language; do not add a status block for a reader that does not exist.

## Auto-clarity carve-out

Keep full, clear English for the **content** of:

- security findings,
- destructive-operation confirmations,
- root-cause and architecture reasoning,
- **any reviewer or implementer finding or concern**, because each is reasoning a downstream
  decision depends on,
- anything that word order or omission would make ambiguous.

Keep the wrapper terse without shortening risk-bearing reasoning.
