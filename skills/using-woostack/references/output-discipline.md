# Output Discipline

Canonical rules for woostack communication — user-facing replies, subagent→parent handbacks,
swarm/worker reports, and log/report writes. Cross-linked from the channels that emit them; never
restated. Sibling of [model-tiers.md](model-tiers.md).

**Governing principle: strip the envelope, never the reasoning.** Terseness applies to the
*wrapper prose* — preamble, narration, pleasantries, hedging, and repetition. It never applies to
structured/contract fields or to risk-bearing reasoning.

## Scope

Applies to:

- user-facing replies from controllers and inline workflows,
- subagent→parent handbacks (implementer, spec/quality reviewers, debug),
- swarm/worker reports,
- log/report writes.

Does **NOT** apply to authored source, documentation, commit messages, or PR descriptions. The
review JSON-artifact and inline-comment contract is governed separately by
[woostack-review `_worker-header.md`](../../woostack-review/prompts/_worker-header.md).

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
- At a final reply, apply [woostack-reflect](../../woostack-reflect/SKILL.md)'s canonical candidate
  gate before loading or invoking it: the session already contains a concrete observed preventable
  instruction gap that could yield a durable instruction finding. If no candidate is admitted, emit
  no reflection headings. An explicit `/woostack-reflect` invocation always runs exactly once. Keep
  both suggestion headings when a pass is admitted and emit `No durable improvement identified.` when
  no finding survives.

## Internal terse rules

- Drop preamble, narration ("I have completed…", "I went ahead and…"), pleasantries ("sure",
  "happy to"), and hedging.
- Use structured, named fields; fragments are fine.
- Keep code symbols, file paths, line numbers, and error strings **verbatim**.
- No invented abbreviations — a reader must be able to decode every term.

## Contract fields are verbatim

**Never compress a structured field the parent parses.** The controller's `subagent-driver.md` branches on exact tokens — compressing or renaming them breaks that branching:

- `STATUS:` codes — `DONE` / `DONE_WITH_CONCERNS` / `NEEDS_CONTEXT` / `BLOCKED`
- `VERDICT:` tokens — `PASS` / `FAIL` / `APPROVED` / `CHANGES_REQUESTED`
- the named field labels themselves (`CHANGED FILES`, `MISSING`, `EXTRA`, `ISSUES`, …)

Keep these labels and tokens exactly. Terseness applies to the prose *around* the contract, never the contract itself.

## Auto-clarity carve-out

Keep full, clear English for the **content** of:

- security findings,
- destructive-operation confirmations,
- root-cause and architecture reasoning,
- **any reviewer or implementer finding or concern** — the text under `CONCERNS`, `MISSING`, `EXTRA`, `ISSUES`, and the like — because each is reasoning a downstream decision depends on,
- anything that word order or omission would make ambiguous.

The envelope around these still goes terse (drop the preamble, keep the field label); the reasoning itself never does. *Strip the envelope, never the reasoning.*
