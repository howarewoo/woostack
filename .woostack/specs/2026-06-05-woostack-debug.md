---
name: woostack-debug
type: spec
status: approved
date: 2026-06-05
branch: feature/woostack-debug
links:
---

# woostack-debug: a woostack-native systematic-debugging skill — Design Spec

> **Plan:** [[plans/2026-06-05-woostack-debug]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

woostack has no first-class debugging discipline. When a verification fails during
`woostack-execute`, or a `woostack-review` finding turns out to be a real bug, the agent is
left to its default behavior: guess a fix, try it, guess again. That is exactly the
guess-and-check thrashing that wastes time and introduces new bugs — the failure mode the
superpowers `systematic-debugging` skill exists to prevent (its "Iron Law": no fix without
root-cause investigation first).

The superpowers skill is proven but lives outside woostack and does not speak woostack's
conventions. Specifically it has no notion of the `.woostack/memory/` store, so a root cause
found today is re-discovered from scratch next month; it references
`superpowers:test-driven-development` and `superpowers:verification-before-completion` for its
test/verify steps rather than woostack's own TDD discipline (embodied inline in
`woostack-execute`); and it has no handback contract with the build loop's execute phase.

We want to own the debugging behavior so it (a) enforces root-cause-before-fix everywhere a
bug surfaces, (b) feeds and reads the woostack memory store so root causes become durable
`gotcha` knowledge, and (c) plugs into `woostack-execute` and `woostack-review` as the place
those skills route a stuck verification or a confirmed bug — while carrying no external
dependency.

## 2. Goal

Ship `skills/woostack-debug/SKILL.md`: a woostack-native systematic-debugging skill, exposed
**both** as the 12th public command `/woostack-debug [target]` **and** as an internal hook the
build-loop skills invoke. It retells superpowers' four-phase method (root-cause investigation →
pattern analysis → hypothesis/test → implementation with a failing test first) and its
load-bearing safeguards (the Iron Law; the "3 fixes failed → question architecture"
escalation), and wires them to woostack systems:

- **Memory recall** at the start (surface known `[[gotchas]]`/hotspots for the target files
  before investigating).
- **Memory distillation** at the end (write one `gotcha` note through the reject-by-default
  gate when a confirmed root cause is fixed).
- **Mode-dependent stop model**: autonomous when invoked internally; a look-before-fix
  root-cause gate when run standalone.

Rewire `woostack-execute` (route a repeatedly-failing verification to `woostack-debug` before
escalating) and `woostack-review` (offer `woostack-debug` to investigate a confirmed bug), and
register the new command across the adoption/enumeration surface.

## 3. Non-goals

- **No spec/plan/status authoring.** `woostack-debug` is a sub-routine, not a build-loop
  phase. It writes no `.woostack/specs/` or `.woostack/plans/` file and never touches a spec's
  `status:`/`branch:` frontmatter. The `spec : plan : PRs = 1 : 1 : N` invariant is untouched.
- **No commit, no merge.** It hands the fix back. Standalone → it names `woostack-commit` as
  the next step; invoked by `woostack-execute` → execute commits the fix in its existing
  per-increment cadence. It never opens, updates, or merges a PR.
- **No reference files.** The four phases and supporting techniques (root-cause tracing,
  defense-in-depth, condition-based waiting) live inline in `SKILL.md` as brief mentions. We do
  **not** port superpowers' `root-cause-tracing.md`, `defense-in-depth.md`,
  `condition-based-waiting.md`, the TS example, or `find-polluter.sh`. Keep the skill lean.
- **No new CI.** No changes to [`action.yml`](../../action.yml) or the reusable review
  workflow; debugging is not a review angle and ships no consumer CI surface.
- **No standalone TDD/verification skill.** Phase 4's "failing test first" reuses the TDD
  discipline already embodied in `woostack-execute`, referenced inline — we do not create or
  depend on a separate skill for it.
- **No behavior change to the other skills** beyond the call-site edits and enumeration
  updates listed in §5. `woostack-build` is unchanged (it reaches debug transitively through
  `woostack-execute`).

## 4. Approach

Author one self-contained `SKILL.md` modeled on the proven superpowers structure, retold in
woostack vocabulary and wired to woostack systems.

### 4.1 The debug loop (four phases, Iron Law preserved)

- **Iron Law, stated up top:** `NO FIX WITHOUT ROOT CAUSE FIRST`. A symptom fix is a failure.
  Carried as a prominent block so it survives summarization (same treatment as the ideate
  HARD GATE).
- **Phase 1 — Root cause investigation:** read errors/stack traces completely; reproduce
  consistently; check recent changes (`git diff`, recent commits); in multi-component systems
  add boundary instrumentation to localize *which* layer fails before touching it; trace the
  bad value backward to its source (root-cause-tracing technique, inline).
- **Phase 2 — Pattern analysis:** find working examples in the same repo; compare working vs.
  broken; list every difference ("that can't matter" is banned); map dependencies/config/env.
- **Phase 3 — Hypothesis & test:** one hypothesis at a time ("X is the cause because Y");
  test with the smallest possible change, one variable at a time; confirm or form a new
  hypothesis; say "I don't understand X" rather than fake understanding.
- **Phase 4 — Implementation:** write a **failing test that reproduces the bug first** (reusing
  woostack-execute's TDD discipline); apply **one** minimal fix at the root cause (no "while
  I'm here" extras); verify the test passes and nothing else broke; consider defense-in-depth
  validation at layer boundaries (inline mention). Fix didn't work and <3 attempts → back to
  Phase 1 with the new evidence; **≥3 attempts → STOP and question the architecture** (this is
  not a failed hypothesis, it's a wrong-architecture signal).

Carry a condensed Red Flags / Rationalizations list (from superpowers) so the agent
self-catches "quick fix for now", "just try changing X", "one more fix attempt", etc.

### 4.2 Mode-dependent stop model (the hybrid)

The skill behaves differently depending on whether it was invoked internally or run as a
command — mirroring how `woostack-execute` has an inline vs. subagent mode:

- **Autonomous mode** (`/woostack-debug <target> --auto`): run all four phases autonomously.
  No per-fix approval gate (consistent with `woostack-execute` / `woostack-harden` owning no
  gate). The Iron Law still forces the root cause to be **narrated** before any fix, so the
  "why" is visible inline. The single hard stop is the **3-fixes architectural escalation**,
  which doubles as the handback signal to the caller.
- **Standalone mode** (`/woostack-debug <target>`, no `--auto`): after Phases 1–3 (root cause
  found, hypothesis confirmed), **stop and present the root cause + the proposed minimal fix,
  and wait for an explicit go-ahead** before applying it (Phase 4). The 3-fixes escalation
  still applies.

**Mode is selected by an explicit `--auto` flag**, mirroring `woostack-execute`'s explicit
`--inline/--subagent` precedent rather than context-sniffing. `--auto` ⇒ autonomous; its
absence ⇒ the standalone look-before-fix gate. There is no inference: when `--auto` is not
present the gate always applies, so an unrequested fix is never silently applied.

### 4.3 Memory integration

- **Recall (start).** Compute the working set (the target's files: the failing test file and
  the code under suspicion) and run the recall procedure — `recall.sh` when the
  `woostack-init` scripts are present, the manual §6 procedure otherwise — to surface matching
  `gotcha`/`hotspot`/`pattern` notes before investigating. State whether recall was
  script-assisted or manual (degradation contract). A matching note may already name the root
  cause; honor it.
- **Distill (end, on a confirmed fix).** Write **one** `gotcha` note through the
  reject-by-default gate: narrow glob `scope:` covering the touched files (single-literal-path
  scope is rejected as trivia), `source:` = the spec/plan that owns the work or `pr-N`, terse
  body with `[[wikilinks]]` to related notes, `updated:` stamped today. Dedupe against
  `MEMORY.md` first (update an existing note rather than add a near-duplicate). Then run
  `build-index.sh` + `doctor.sh`. The note records the *root cause and its fix*, not the
  symptom. All of this reuses the machinery and gate documented in
  [memory.md](../../skills/woostack-init/references/memory.md) — link it, do not restate it.

### 4.4 Wiring the existing skills

- **`woostack-execute` (active dispatch, `--auto`).** Its "When to stop and ask → a
  verification fails repeatedly" path currently stops and asks the user. Insert
  `woostack-debug <target> --auto` as the step *before* escalating: a repeatedly-failing
  verification routes to debug, which finds the root cause and fixes it, or hits the 3-fixes
  escalation and *then* surfaces to the user. execute is already an autonomous loop, so the
  autonomous dispatch fits. Applies to both inline and subagent drivers. Debug returns the fix
  into execute's working tree; execute commits it in its normal per-increment cadence (debug
  does not commit).
- **`woostack-review` (suggest, gated — never `--auto`).** When a review confirms a real bug
  (not a style nit), **suggest** `/woostack-debug <target>` to the user as the systematic way
  to investigate it. review never `--auto`-dispatches debug: review owns no fix behavior and
  "never auto-addresses findings", so it must not trigger an autonomous fix — it points the
  user at the gated command. Light prose pointer; no change to review's verdict/threading
  behavior.
- **`woostack-build`.** No change — it reaches debug transitively through `woostack-execute`.

## 5. Components & data flow

Edit set. This is a single feature; the increment decomposition is `woostack-plan`'s job, but
the natural split is **(A) the new skill + memory/loop**, then **(B) the call-site wiring +
enumeration**, so A is independently shippable and reviewable before B references it.

| File | Change |
|---|---|
| `skills/woostack-debug/SKILL.md` | **NEW** — the skill: frontmatter (`name`, scoped `description`), Iron Law block, the four phases, the mode-dependent stop model, the Red Flags/Rationalizations digest, memory recall + distill (link `memory.md`), and the out-of-scope/handback contract. Lean, no `references/`. |
| `skills/woostack-execute/SKILL.md` | "When to stop and ask" (line ~137, `A verification fails repeatedly.`): route a repeatedly-failing verification to `woostack-debug <target> --auto` **before** escalating to the user — escalate only if debug hits its 3-fixes architectural stop. This block is shared by both drivers, so one edit covers inline + subagent. Note debug does not commit; execute commits the returned fix in its existing per-increment cadence. |
| `skills/woostack-review/SKILL.md` | Prose pointer: **suggest** the gated `/woostack-debug <target>` to the user to investigate a confirmed bug finding — never `--auto` (review never auto-addresses findings). No verdict/threading change. |
| `skills/using-woostack/SKILL.md` | Add a Command Routing row for `/woostack-debug <target> [--auto]`. |
| `AGENTS.md` (`.claude/CLAUDE.md` symlink) | Public surface `eleven → twelve` and add `woostack-debug` to the list (line ~16); update the "eleven-skill command surface" phrasing (line ~34); `thirteen → fourteen` SKILL.md files and `eleven → twelve` public in the rename-protection constraint (line ~79); add a Quick file map entry; add `/woostack-debug` to the Mode B command list. |
| `README.md` | Public-surface count `eleven → twelve` and add `woostack-debug` to the command list (line ~29); add a `### /woostack-debug [target]` entry in the command-catalog section (the per-command blurb block, lines ~50–90). The build-loop prose (line ~62) names build *phases* only (ideate/harden/plan/execute); debug is a sub-routine, not a phase, so it is **not** added there. |
| `CONTRIBUTING.md` | Add `woostack-debug` to the command-surface list (line ~3); add a "where to edit the debugging behavior" row if the edit-map table lists per-skill entries. |

Runtime data flow:

```
/woostack-debug <target>        woostack-execute (stuck verification)     woostack-review (confirmed bug)
        │                                  │                                        │
        ▼                                  ▼                                        ▼
   standalone mode ─────────────►  woostack-debug  ◄──────────────────────  internal hook mode
        │  (look-before-fix gate)        │  (autonomous; 3-fixes escalation)
        │                                │
   recall.sh (start) ◄────────── working set = target files
        │
   Phase 1→2→3→4  (Iron Law: root cause before fix; failing test first; minimal fix; verify)
        │
   fix handed back ──► standalone: name woostack-commit │ internal: execute commits in its cadence
        │
   distill 1 gotcha note ──► reject-by-default gate ──► build-index.sh + doctor.sh
```

## 6. Error handling

- **Scripts absent (individual install).** Memory recall/distill degrade to the manual
  procedure per the `memory.md` §10 degradation contract; the skill states which path it took
  and never fails silently.
- **No root cause found.** Honor superpowers' "When process reveals no root cause": after a
  genuine investigation, document what was checked and implement appropriate handling
  (retry/timeout/clear error + logging) rather than a blind fix — but treat this as the rare
  case (most "no root cause" is incomplete investigation).
- **Mode ambiguity.** Mode is an explicit `--auto` flag, so there is no inference to get
  wrong: any invocation without `--auto` takes the **standalone look-before-fix gate**. A
  malformed or unrecognized flag is treated as absent (gated), never as autonomous — an
  unrequested fix is never applied.
- **Description over-trigger.** Risk: a debugging `description` broad enough to hijack every
  error mention. Mitigation: scope the `description` to "use as woostack's systematic-debugging
  phase / `/woostack-debug`", recognizable to execute/review and as a command, without
  shadowing routine error handling.
- **3-fixes escalation as a real stop.** The "≥3 fixes failed → question architecture" stop is
  load-bearing; state it as an explicit block so it survives summarization, like the Iron Law.

## 7. Testing

No app/test harness in this repo (it is a skills collection). Verification is by inspection:

- New `skills/woostack-debug/SKILL.md` has valid frontmatter (`name`, `description`), the Iron
  Law block, all four phases, the mode-dependent stop model, and the memory recall/distill
  contract linking `memory.md` (not restating it).
- `woostack-execute` routes a repeatedly-failing verification to `woostack-debug` before user
  escalation; `woostack-review` offers it for a confirmed bug.
- `using-woostack` has a `/woostack-debug` routing row.
- Enumeration is consistent repo-wide: grep for `eleven`/`twelve`/`thirteen`/`fourteen` and the
  command lists in `AGENTS.md`, `README.md`, `CONTRIBUTING.md` — counts and lists all include
  `woostack-debug` and agree with each other.
- Cross-links resolve (`woostack-debug` ↔ `woostack-execute`/`woostack-review`/`memory.md`/
  `conventions.md`); no dangling links.
- `woostack-debug` writes no spec/plan/status and contains no commit/merge action (grep the
  skill for those to confirm the out-of-scope contract holds).

## 8. Open questions

Resolved during the spec harden pass (step 3):

- **Naming** → `woostack-debug` (verb-family, matches build/commit/review/execute/plan).
- **`target` argument shape** → free-form (failing test path, error text, PR#, or symptom);
  no-arg standalone → ask what's broken (mirror `woostack-execute`'s no-arg behavior).
- **Mode detection mechanism** → explicit `--auto` flag (mirrors `woostack-execute`'s
  `--inline/--subagent`). `--auto` ⇒ autonomous (no gate); absent/unrecognized ⇒ standalone
  look-before-fix gate. No context-sniffing; fail-safe to gated (§4.2, §6).
- **execute vs. review dispatch** → `woostack-execute` actively dispatches `--auto` (it is
  already an autonomous loop); `woostack-review` only **suggests** the gated `/woostack-debug`
  and never `--auto`-dispatches, because review owns no fix behavior and never auto-addresses
  findings (§4.4).
- **Exact execute insertion point** → the shared "When to stop and ask → a verification fails
  repeatedly" block (execute SKILL.md line ~137); one edit covers both inline and subagent
  drivers, routing to debug before user escalation (§5).
- **README touch points** → the public-surface count + list (line ~29) and a new
  `### /woostack-debug <target>` command-catalog entry; build-loop prose (line ~62) is left
  untouched because debug is a sub-routine, not a build phase (§5).
