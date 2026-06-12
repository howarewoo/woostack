# Output Discipline (internal comms)

Canonical rules for **internal** woostack communication — subagent→parent handbacks, swarm/worker reports, and memory/log writes. Cross-linked from the channels that emit them; never restated. Sibling of [model-tiers.md](model-tiers.md).

**Governing principle: strip the envelope, never the reasoning.** Terseness applies to the *wrapper prose* — preamble, narration, pleasantries, hedging. It never applies to structured/contract fields or to risk-bearing reasoning.

## Scope

Applies to internal comms only:

- subagent→parent handbacks (implementer, spec/quality reviewers, debug),
- swarm/worker reports,
- memory note bodies and log/report writes.

Does **NOT** apply to:

- user-facing replies — including a controller's own inline-mode narration in `woostack-execute --inline`;
- the review JSON-artifact contract — that is governed by the "Output Discipline (READ FIRST)" section of [woostack-review `_header.md`](../../woostack-review/prompts/_header.md), a different channel.

## Default terse rules

- Drop preamble, narration ("I have completed…", "I went ahead and…"), pleasantries ("sure", "happy to"), and hedging.
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

## Memory-note bodies

A distilled memory note body is one terse reusable rule: **one line, `<pattern>: <reason>`, ideally ≤100 chars, no preamble or narration.** State the rule and stop — no instance line numbers, no restating the finding. This is the single canonical definition of the rule; the memory contract and the review / address-comments record steps link here instead of restating it.
