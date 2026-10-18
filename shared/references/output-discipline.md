# Output Discipline

Canonical rules for woostack communication — user-facing replies, subagent→parent handbacks,
swarm/worker reports, and log/report writes. Cross-link from a channel that emits them instead of
restating them.

**Governing principle: strip the wrapper, never the reasoning.** Terseness applies to the
*wrapper prose* — preamble, narration, pleasantries, hedging, and repetition. It never applies to
risk-bearing reasoning.

## Scope

Applies to:

- user-facing replies from coordinating skills and inline workflows,
- subagent→parent handbacks (implementer, spec/quality reviewers, debug),
- swarm/worker reports,
- log/report writes.

Does **NOT** apply to authored source, documentation, commit messages, or PR descriptions.

## User-facing replies

- Lead with the conclusion, result, or blocker. Include a next action only when it is useful.
- Drop tool-call narration, preambles, pleasantries, generic transitions, and completion recaps
  that only repeat the answer.
- State each fact once. Prefer short paragraphs or bullets. Skip decorative headings, emoji, and
  tables; use a table only when comparison benefits from columns.
- Keep code symbols, file paths, line numbers, CLI commands, and error strings **verbatim**.
- Use standard technical terms, not invented abbreviations or compressed grammar the reader must
  decode.
- User requests for more detail override the terse default. Answer the requested depth without
  restoring filler.

## Internal terse rules

- Drop preamble, narration ("I have completed…", "I went ahead and…"), pleasantries ("sure",
  "happy to"), and hedging.
- Use structured, named fields; fragments are fine.
- Keep code symbols, file paths, line numbers, and error strings **verbatim**.
- No invented abbreviations — a reader must be able to decode every term.

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

The wrapper around these still goes terse; the reasoning itself never does. *Strip the wrapper,
never the reasoning.*
