---
name: output-discipline
type: spec
status: approved
date: 2026-06-12
branch: feature/output-discipline
links:
---

# Native Output Discipline for Internal Comms — Design Spec

> **Plan:** [[plans/2026-06-12-output-discipline]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

Internal communication inside the woostack collection — subagent→parent handbacks, swarm/review workers, and memory/log writes — is reinjected into the controller's context on every subsequent turn. Verbose, preamble-laden output bloats context fast and shortens session lifespan. Today there is **no shared discipline** governing the prose length or fluff of these channels:

- The only named "Output Discipline" section (`woostack-review/prompts/_header.md`) governs **review JSON artifacts only** — it does not reach prose handbacks or memory bodies.
- The only explicit terseness budget anywhere — the `<pattern>: <reason>`, ≤100-char memory rule — is **copy-pasted in two places** (`woostack-review` Stage 6, `woostack-address-comments` Phase 3 ACCEPT), drifting independently.
- Several high-frequency channels carry no length/fluff rule at all: `woostack-execute` implementer + spec/quality reviewer handbacks, `woostack-debug` Phase 4 handback, `woostack-init` memory note bodies, `woostack-commit` drafting subagent, `woostack-address-comments` worker `reasoning`/`reply`, `woostack-execute-overnight` decision-log rationale.

There is no single shared reference a skill can cross-link for internal-comm output conventions, so the rules are absent, inconsistent, or duplicated.

## 2. Goal

Add one canonical, cross-skill **Output Discipline** reference that defines a *tiered* terse style for internal comms — default no-fluff, with an explicit auto-clarity carve-out for content that must stay fully clear — and wire the **high-frequency, context-resident channels** to it with a thin one-line cross-link (no restating). Dedup the existing ≤100-char memory rule into the canonical home. Leave user-facing replies and the review JSON-artifact contract untouched.

Scope is deliberately the **risk-adjusted core** (descoped 2026-06-12): the two justifiable wins are (a) killing the live 2-copy drift of the ≤100-char rule, and (b) trimming the channels that actually accumulate in long unattended / subagent-mode runs (implementer handbacks, spec/quality verdicts, memory bodies). Tail channels are deferred (§3) — they can adopt the doc later by cross-link.

The win: lower context bloat on the channels that dominate long runs, one source of truth instead of drift-prone copies, and no loss of clarity where it matters (security, destructive ops, root-cause/architecture reasoning, and any reviewer/implementer finding).

## 3. Non-goals

- **User-facing replies.** The terse discipline governs *internal* comms only. Skills' final replies to the user stay natural and well-structured. **Out of scope entirely** — distinct from the auto-clarity carve-out (§4.3), which is internal content that *is* in scope but exempted from terseness. The controller's own **inline-mode narration** in `woostack-execute --inline` (reviews it performs directly, surfaced to the user) is user-facing and likewise out of scope; the discipline targets cross-agent handbacks and persisted writes (memory/logs/reports), not the controller talking to its user.
- **The review JSON-artifact contract.** `_header.md`'s existing "Output Discipline" (JSON array shape, crash-guard, escape rules for angle workers) is a different channel and is **not** rewritten — it only gains a one-line pointer to the new doc for prose handbacks.
- **Full lithic/article-dropping "caveman" style.** Rejected during ideate: the default is structured no-fluff (no preamble/narration/pleasantries, fragments OK, structured fields, length caps), not article-stripping, because parent agents must parse correctness/security content unambiguously.
- **New tooling / lint enforcement.** No script enforces the discipline; it is prompt-level guidance. (A future lint pass is out of scope here.)
- **The `status:`/board conventions, model-tiers, memory schema fields.** Unchanged except for the memory *body* discipline pointer.
- **Tail channels — deferred (descoped 2026-06-12).** The low-frequency / low-payoff channels are **out of scope** for this feature: `woostack-debug` Phase 4 handback, `woostack-commit` drafting subagent, `woostack-address-comments` worker `reasoning`/`reply`, and `woostack-execute-overnight` decision-log rationale. They carry little context-resident weight and add risk surface for marginal savings; the canonical doc exists for them to adopt later by cross-link, but this feature does not wire them. (Note: `woostack-address-comments` is still touched for the ≤100-char **dedup** at Phase 3 ACCEPT — that is part of the dedup win, not tail-channel wiring.)

## 4. Approach

**One canonical shared reference + thin cross-links** (chosen over inlining a block per prompt, which would duplicate rules across ~8 files and drift). Mirrors the repo rule "cross-link, do not duplicate" and the proven `using-woostack/references/model-tiers.md` pattern (one reference, multiple skill consumers).

Create `skills/using-woostack/references/output-discipline.md` — **a single file** with a stable `## Auto-clarity carve-out` heading consumers can deep-link (`output-discipline.md#auto-clarity-carve-out`). Its governing principle, stated up front: **strip the envelope, never the reasoning** — terseness applies to the *wrapper prose* (preamble, narration, pleasantries, hedging), and **never** to structured/contract fields or to risk-bearing reasoning. Contents:

1. **Scope statement** — applies to internal comms (subagent handbacks, swarm/worker reports, memory/log writes); explicitly NOT user-facing replies (incl. inline-mode controller narration), NOT the review JSON-artifact contract.
2. **Default terse rules** — drop preamble, narration ("I have completed…"), pleasantries, hedging; use structured named fields; fragments OK; keep code symbols, file paths, line numbers, and error strings **verbatim**; no invented abbreviations.
3. **Contract-field rule (verbatim)** *(mitigation, 2026-06-12)* — **never compress structured/contract fields the parent parses** — `STATUS` codes (`DONE` / `BLOCKED` / `NEEDS_CONTEXT` / `DONE_WITH_CONCERNS`), `VERDICT` tokens (`PASS` / `FAIL` / `APPROVED` / `CHANGES_REQUESTED`), and named field labels the driver branches on — keep them **verbatim**. Terseness applies to the prose *around* the contract, never the contract itself. This protects `subagent-driver.md`'s status-code branching.
4. **Auto-clarity carve-out** (`#auto-clarity-carve-out`) — keep full, clear English for the *content* of: security findings, destructive-operation confirmations, root-cause + architecture reasoning, and — *generalized (mitigation, 2026-06-12)* — **any reviewer or implementer finding/concern** (`CONCERNS`, `MISSING`, `EXTRA`, `ISSUES`, and the like), since each is reasoning a downstream decision depends on. The envelope around them still goes terse; the finding text itself never does. Also covers anything that word order/omission could make ambiguous.
5. **Memory-body rule (canonical home)** — the one-line `<pattern>: <reason>`, ≤100 chars, no narration rule, defined **once** here.

Then wire the **core, high-frequency channels** with a single cross-link line each (channel-scoped, no restating the ruleset):

- `woostack-execute/prompts/implementer.md` (Report-back block — envelope terse; `STATUS` verbatim per §4.3; `CONCERNS` content rides the carve-out)
- `woostack-execute/prompts/spec-reviewer.md`, `quality-reviewer.md` (verdict blocks — `VERDICT` verbatim; `MISSING`/`EXTRA`/`ISSUES` content rides the carve-out)
- `woostack-execute/SKILL.md` distill step (note body)
- `woostack-init/references/memory.md` §3 note body

Tail channels (debug Phase 4, commit subagent, address-comments worker fields, overnight decision log) are **deferred** — see §3.

Dedup: `woostack-review/SKILL.md` Stage 6 and `woostack-address-comments` Phase 3 ACCEPT replace their spelled-out ≤100-char rule with a cross-link to the canonical definition. (This is the dedup win — `woostack-address-comments` is touched here only for that, not for tail-channel wiring.) `_header.md`'s existing "Output Discipline" gains one line noting prose-handback discipline lives in the new doc (resolves the name collision; the JSON contract itself is unchanged).

Discovery: follows the `model-tiers.md` precedent — that shared reference lives in `using-woostack/references/` and is **not** indexed in `using-woostack/SKILL.md`; consumers reach it purely by relative-path cross-link. So `output-discipline.md` is "discoverable" by being cross-linked from ≥1 consumer; no new SKILL-index or quick-map entry is required (an optional `using-woostack` mention is fine but not in scope).

## 5. Components & data flow

- **Canonical reference** — `skills/using-woostack/references/output-discipline.md`. New file, single source of truth. Read by consumers via relative path (same mechanism as `model-tiers.md`).
- **Cross-link sites (core)** — each core consumer adds a pointer at the exact channel where output is specified: implementer Report-back block, spec/quality reviewer verdict blocks, execute distill step, `memory.md` §3 note body. The pointer names the canonical file and the carve-out, and does not restate the rules.
- **Dedup sites** — the two ≤100-char memory rule copies collapse to cross-links; the canonical definition is the only spelled-out copy.
- **Collision resolver** — `_header.md` one-line pointer disambiguates "review JSON Output Discipline" vs "prose internal-comm Output Discipline."

Data flow: a subagent/worker reads its prompt → the prompt's cross-link routes it to the canonical rules → it emits terse, structured, carve-out-aware output → the parent reinjects a smaller payload → context lasts longer. No runtime/code path; this is prompt-authoring data flow.

## 6. Error handling

- **Broken cross-link** (target path doesn't resolve) → a consumer cannot find the rules. Mitigation: every cross-link uses a correct relative path verified against the worktree; AC checks all targets resolve.
- **Residual duplication** (a site restates the ruleset instead of linking, or the ≤100-char rule survives in >1 place) → drift returns. Mitigation: AC asserts the rule is spelled out exactly once and no consumer restates the full ruleset.
- **Over-compression** (security/root-cause/destructive content gets terse-stripped and becomes ambiguous) → real risk. Mitigation: the auto-clarity carve-out is mandatory and called out at each relevant channel (security findings, debug root-cause, destructive confirmations).
- **Scope leak** (terse rules bleed into user-facing replies or the review JSON contract) → degrades UX / breaks parsers. Mitigation: explicit non-goals + scope statement; review JSON contract untouched.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. No code runtime here, so "testable" = a verifiable assertion about the authored files.

- **AC1 — Canonical reference exists and is complete**
  - happy: `skills/using-woostack/references/output-discipline.md` exists and contains all five sections (scope statement, default terse rules, **contract-field verbatim rule**, auto-clarity carve-out, canonical memory-body rule) plus the "strip the envelope, never the reasoning" principle line.
  - error: a missing section → AC fails; reviewer flags the absent heading.
  - edge: the carve-out enumerates security findings, destructive confirmations, root-cause/architecture reasoning, **and any reviewer/implementer finding/concern (`CONCERNS`/`MISSING`/`EXTRA`/`ISSUES`)** explicitly (not a vague "be clear when needed"); the contract-field rule names `STATUS`/`VERDICT` tokens as verbatim.

- **AC2 — ≤100-char memory rule defined exactly once**
  - happy: the `<pattern>: <reason>`, ≤100-char rule is spelled out only in `output-discipline.md`; `woostack-review/SKILL.md` Stage 6 and `woostack-address-comments` Phase 3 ACCEPT cross-link it.
  - error: the rule still spelled out in a second file → AC fails.
  - edge: the cross-links preserve the existing behavior (one-line accept-record write) — no semantic change to what gets recorded.

- **AC3 — Every core channel cross-links the canonical doc, none restates it**
  - happy: each of the four core consumer sites (implementer Report-back, spec-reviewer + quality-reviewer verdict blocks, execute distill, `memory.md` §3) carries a one-line pointer to `output-discipline.md`.
  - error: a core channel has no pointer, or a channel restates the full ruleset inline → AC fails. A **deferred tail channel** (debug, commit, address-comments worker, overnight log) being wired is scope creep → also fails.
  - edge: each pointer is channel-scoped and notes the contract-field/carve-out split where it applies (e.g. reviewer verdicts → `VERDICT` verbatim, `ISSUES`/`MISSING`/`EXTRA` content rides the carve-out in full English).

- **AC4 — Scope boundary preserved**
  - happy: no user-facing reply guidance is made terse; `_header.md`'s JSON-artifact contract is unchanged except for a one-line pointer; the review angle/validator JSON schema is untouched.
  - error: a user-facing section or the JSON schema is rewritten terse → AC fails.
  - edge: the `_header.md` pointer disambiguates the two "Output Discipline" usages without altering the JSON rules.

- **AC5 — Not orphaned (cross-linked, per model-tiers precedent)**
  - happy: `output-discipline.md` is cross-linked from ≥1 consumer (the wiring of AC3), exactly as `model-tiers.md` is reached — no `using-woostack/SKILL.md` index entry is required.
  - error: the file exists but no skill references it (true orphan) → AC fails.
  - edge: a `using-woostack` quick-map/index mention is optional, not required for this AC to pass.

- **AC6 — All cross-link targets resolve**
  - happy: every relative path added (consumer→canonical, canonical→conventions/carve-out anchors) points to a real file.
  - error: a dangling relative path → AC fails.
  - edge: paths are correct from each file's own directory depth (prompts/ vs references/ vs SKILL root differ).

- **AC7 — Contract fields stay parseable (mitigation)**
  - happy: after wiring, `implementer.md` still emits a verbatim `STATUS:` line and `spec-reviewer.md`/`quality-reviewer.md` still emit verbatim `VERDICT:` lines — the `subagent-driver.md` branching tokens are intact; the canonical doc's contract-field rule names them.
  - error: a wired prompt's cross-link or terse rewording drops/renames a `STATUS`/`VERDICT` token, or removes a label the driver parses → AC fails.
  - edge: `CONCERNS`/`ISSUES`/`MISSING`/`EXTRA` content is preserved in full English (carve-out), not compressed away — the field stays, only its preamble goes.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

No application runtime, package scripts, or CI exist for this repo (it is a skill collection). Verification is **doc-consistency review**, performed by the executing agent and the per-increment quality/spec reviewers:

- **Link resolution** — for every cross-link added, confirm the relative target exists from that file's directory (grep/`ls` the resolved path).
- **Single-definition check** — grep the collection for the ≤100-char rule wording; assert it is spelled out only in `output-discipline.md`.
- **No-restatement check** — confirm each consumer site links rather than copies the ruleset.
- **Scope check** — diff-review that no user-facing section and no review JSON schema lines were made terse.
- **Carve-out presence** — confirm security/destructive/root-cause + finding/concern exemptions appear in the canonical doc and are referenced where those channels live.
- **Contract-field check (AC7)** — grep the wired prompts; confirm `STATUS:`/`VERDICT:` contract tokens survive verbatim post-wiring and the canonical doc states the verbatim rule.

Fixtures/CI: none. The "harness" is grep + the reviewer reading the diff. Each increment is independently shippable and reviewable as a docs PR.

## 9. Open questions

All resolved in harden + scope review (2026-06-12):

- **Filename/anchor** → RESOLVED: a single file `using-woostack/references/output-discipline.md` with a stable `## Auto-clarity carve-out` heading consumers deep-link via `#auto-clarity-carve-out`. (§4)
- **using-woostack index entry** → RESOLVED: not needed. Follows the `model-tiers.md` precedent — shared references in `using-woostack/references/` are reached by consumer cross-links, not SKILL-indexed. Discoverability = ≥1 consumer cross-link (AC5). (§4 Discovery)
- **Scope (risk/ROI review)** → RESOLVED: descoped to the **core** — token savings alone don't clear the bar, so wire only the dedup win + the high-frequency context-resident channels (implementer, spec/quality reviewers, distill, memory body). Tail channels deferred (§3). (Option A.)
- **Mitigation — contract-field integrity** → RESOLVED: added the verbatim contract-field rule (§4.3) + AC7, so terse rewording can't break `subagent-driver.md` status/verdict branching.
- **Mitigation — carve-out generalization** → RESOLVED: the carve-out now covers all reviewer/implementer findings/concerns, not just debug (§4.4).
- **Name collision** → RESOLVED (kept): canonical doc keeps the name `output-discipline.md`; `_header.md` gains a one-line pointer to disambiguate. (Rename to `handback-discipline.md` considered and declined — keep the source report's "Output Discipline" term.)
- **woostack-debug Phase 4** → DEFERRED (resolution stands for later adoption): structure terse, reasoning full — strip the envelope, keep root-cause/fix/evidence in full clear English under the carve-out. Seeds the governing principle but is **not wired** by this feature (§3).
- **Overnight decision-log budget** → DEFERRED (resolution stands for later adoption): no extra per-entry budget; rationale inherits the default terse rule, event-code vocabulary unchanged. **Not wired** by this feature (§3).
