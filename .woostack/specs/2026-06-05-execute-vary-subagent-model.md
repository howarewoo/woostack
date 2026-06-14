---
name: execute-vary-subagent-model
type: spec
status: planning
date: 2026-06-05
branch: feature/execute-vary-subagent-model
links:
  - "[[2026-06-04-execute-dual-mode-execution]]"
  - "[[2026-06-04-woostack-execute]]"
---

# woostack-execute: vary subagent model per task (quality / speed / cost) — Design Spec

> **Plan:** [[plans/2026-06-05-execute-vary-subagent-model]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

The dual-mode execution work ([[2026-06-04-execute-dual-mode-execution]]) gave subagent mode a
`fast | standard | deep` tier vocabulary: each prompt template declares a `tier:` in frontmatter,
"resolved through the shared Model Tiers table in `../woostack-review/prompts/_header.md`." That
wiring is only half-built, so in practice subagents **do not vary the model at all**:

- **Descriptive, not operational.** `references/subagent-driver.md`'s "Model tiers" section names
  the tiers and says where to resolve them, but the per-task dispatch steps (implementer step 1,
  spec-reviewer step 3, quality-reviewer step 4) **never instruct the controller to read the tier
  and pass a concrete `model:` on the Agent/Task call.** Every subagent therefore runs at the
  host's session model; the tiers are documentation, not behavior.
- **Static per role.** Tier is fixed per prompt (`implementer=standard`, `spec-reviewer=standard`,
  `quality-reviewer=deep`). There is no per-task adaptation, so a trivial one-file rename would
  pay the same model as a security-critical migration, and vice versa — the opposite of
  optimizing quality/speed/cost. Two scattered notes gesture at adaptation ("`fast` — mechanical
  1–2-file tasks … an implementer downgrade"; BLOCKED → "re-dispatch at a higher tier") but they
  are not a coherent selection rule with one home.
- **Mapping lives in a review internal — and is already duplicated.** The concrete tier→model
  table sits inside `woostack-review/prompts/_header.md` (a review-prompt header), is **re-embedded**
  as an Anthropic-only copy in `prompts/anthropic.md`, is **referenced by name** ("the table in
  `_header.md`") from `prompts/opencode.md`, and is mirrored as executable logic in
  `scripts/load-prompt.sh` (`default_model_for()`). Two skills now need the table, but its only
  documented home is review-specific, so execute depends on a review internal — and the table
  exists in four places that can drift.

Net: the infrastructure names tiers but never routes them, and the assignment is static. "Vary
the model to optimize quality, speed, and cost" is unimplemented.

## 2. Goal

Make **subagent-mode** `woostack-execute` actively vary the per-task model to trade quality,
speed, and cost — operationally, adaptively, on one shared mapping:

- **Wire (operationalize).** Each per-task dispatch resolves the effective tier → maps it to a
  concrete model via a shared doc → **passes that model as the dispatch `model:` arg.** Best
  effort: a host that cannot route the model per call falls back to the session model and **says
  so** (degraded, not equivalent).
- **Adapt.** A signal→tier **heuristic in the subagent driver** picks the tier per task from
  complexity and risk, around the role defaults — so cheap work gets a cheap model and risky/hard
  work gets a capable one.
- **Promote.** Move the canonical tier→model table out of the review prompt into a **neutral
  shared reference** both `woostack-review` and `woostack-execute` point at, and **repoint review**
  so its CI prompt stays self-contained.

Inline mode is untouched: it *is* the session model and cannot vary.

## 3. Non-goals

- **No inline-mode variation.** Inline runs in this session's model by definition; only the
  subagent driver varies models.
- **No model-version changes.** The tier→model table is **moved verbatim**. Stale slugs (e.g.
  `claude-opus-4-7` vs a newer Opus) are a separate concern, explicitly out of scope here — this
  change must not silently bump any model id.
- **No plan-format change.** Tiers are chosen by the driver at execute time, **not** annotated per
  task in the plan (the "plan-annotated tiers" alternative was weighed and rejected in ideation).
- **No new per-repo config surface for execute.** `woostack-execute` does **not** start reading
  `.woostack/config.json` model overrides; those `models.<tier>` / `models.<provider>.<tier>` keys
  remain **review-only** behavior. The shared doc *documents* them as review behavior, but wiring
  execute to honor them is out of scope (the "reuse + honor config override" option was not the
  chosen path).
- **No parallel dispatch.** "One increment per cycle," tasks sequential over the shared working
  tree — unchanged.
- **No change to gates, the never-merge rule, or the `spec : plan : PRs = 1 : 1 : N` invariant.**
- **No change to review's output/contract.** The repoint must be output-neutral: the composed
  review prompt still contains the same table text, and the review event/STATUS_LINE behavior is
  unchanged.

## 4. Approach

### 4.1 Promote the tier prose to a shared doc (deep dedup)

New canonical file **`skills/using-woostack/references/model-tiers.md`** (a new `references/` dir
under the collection hub) becomes the **single source** for tier knowledge across the collection.
It holds:

- the host-agnostic `fast | standard | deep` → multi-provider (Anthropic / OpenAI / Google /
  OpenRouter) model **table** (same slugs as today — content unchanged, see non-goals);
- the **tier semantics** (what each tier is for) and the **provider notes**;
- the **routing rules** (per-call vs single-model-per-session) and the **override-precedence
  logic**, written **generically** — "a host MAY override the table via per-repo config; precedence
  is forced-tier > explicit-model > per-provider key > flat-tier key > table default."

Today this knowledge is **duplicated**: the multi-provider table in
`woostack-review/prompts/_header.md`, an embedded Anthropic-only copy in
`prompts/anthropic.md`, and references in `prompts/opencode.md`. Deep dedup collapses them onto the
shared doc.

**Generic logic vs runtime binding.** Only the tier *table and precedence logic* are
single-sourced. Each review prompt keeps its **concrete runtime bindings** — the env/paths/inputs
that actually execute the routing (`FORCE_TIER`, `run_model`, `/tmp/pr-review/config.json`,
`inputs.model`, the `jq` override reads) — as thin pointers that say "resolve per the shared doc's
precedence." Executable surface stays where it runs; no duplicated table or precedence prose.

`using-woostack` is the neutral hub both skills can justify pointing at, and the **whole `skills/`
tree ships in the review action bundle** (`action.yml` resolves paths under
`${{ github.action_path }}/skills/…`, i.e. the repo root), so the file is reachable from CI as
well as from interactive hosts and from a consumer repo's installed collection (cross-skill
relative links already work — execute already links `../woostack-review/prompts/_header.md`).

### 4.2 Repoint woostack-review (keep the CI prompt self-contained, output-neutral)

`load-prompt.sh` concatenates `_header.md` (+ provider body) into **one self-contained prompt blob**
shipped to external runners that follow **no** markdown links — so the table *content* must still
land in the composed prompt. Therefore:

- **`prompts/_header.md`:** remove the raw inline Model Tiers table + provider notes + the
  routing/override prose; replace with a short "Model Tiers" section that links the shared doc and
  carries the inline anchor the loader fills. The review-pipeline **"Per-repo Config" key table**
  (which key is consumed at which stage) **stays** — it is review plumbing, not tier vocab. Keep
  the in-prompt references ("the table below", "the `deep` row") resolving against the inlined
  content.
- **`prompts/anthropic.md`:** delete the embedded Anthropic-only tier table; repoint its
  "Model Routing" steps to the shared doc's table + precedence. **Keep** its concrete `model:`
  dispatch example and the per-repo override `jq` (the Anthropic runtime binding).
- **`prompts/opencode.md`:** repoint its "table in `_header.md`" reference and override precedence
  to the shared doc. **Keep** the OpenRouter `reasoning_effort` binding specifics.
- **`load-prompt.sh`:** gains a step that **inlines the shared doc's tier→model table into the
  composed prompt** (alongside `_header.md` + body) so the CI blob remains byte-complete — **no
  change to review output.** The precise splice mechanism (a comment-marker replacement vs an
  added concatenation) is a plan/harden detail; the **invariant** is that the composed prompt
  contains the same table text it does today, and the inline step **fails loud** (non-zero) rather
  than ever shipping a table-less prompt.
- **`default_model_for()` in `load-prompt.sh`** stays the authoritative **executable** resolver for
  single-session CI hosts (bash cannot read a markdown table). It gains a
  `# canonical source: skills/using-woostack/references/model-tiers.md — keep in sync` comment,
  declaring it a mirror of the shared doc.

No other review prompt is affected: the validator and angle prompts declare only a `tier:`
frontmatter (no table reference), so they resolve against the inlined table unchanged.

### 4.3 Repoint woostack-execute

`references/subagent-driver.md`'s "Model tiers" cross-link changes from
`../../woostack-review/prompts/_header.md` to `../../using-woostack/references/model-tiers.md`.
The three `prompts/*.md` `tier:` frontmatter values are unchanged (verify they remain the
role-default source).

### 4.4 Wire the dispatch (operationalize)

Add a one-paragraph **"Dispatch model"** contract to the driver's Model-tiers section and have the
three dispatch steps reference it:

> Before each subagent dispatch, resolve the task's **effective tier** (role default, adjusted per
> §4.5), map it to the host's model via [model-tiers.md] (use the column for the host's provider —
> usually the session's), and **pass that model on the dispatch** (the `model:` arg of the
> Agent/Task call). Pass whatever value the host's subagent API accepts — a concrete slug where it
> takes slugs, or the tier's model **family** (e.g. `haiku`/`sonnet`/`opus`) where it takes
> families. **When the host supports per-call routing, every dispatch MUST pass the resolved
> model** — omitting it makes the subagent inherit the parent session's model (typically Opus),
> silently defeating tier routing and burning multiples of the tokens on cheap work (the same
> rationale `woostack-review`'s `prompts/anthropic.md` already states for its angle spawns). **When
> the host cannot route per call**, run at the session model and **say so** (degraded, not
> equivalent) — never pretend a tier ran.

Implementer (step 1), spec-reviewer (step 3), and quality-reviewer (step 4) each cite this
contract so the tier each prompt declares (or the heuristic overrides) actually reaches the call.
This mirrors the proven discipline already shipping in the review action — execute is the half
that was left descriptive.

### 4.5 Adapt — the signal→tier heuristic (single home)

New **"Tier selection"** subsection in `subagent-driver.md`, holding the role defaults plus the
adjustment rules, and absorbing the previously scattered notes:

- **Role defaults** (unchanged from today's frontmatter): implementer `standard`, spec-reviewer
  `standard`, quality-reviewer `deep`.
- **Bump UP → `deep`** when the task touches **security / auth / crypto**, **data migrations**,
  **concurrency / locking**, **money / billing**, or is **cross-cutting / architectural**; when the
  task spec is **highly ambiguous**; or when the task previously returned **BLOCKED** for
  "needs more reasoning."
- **Bump DOWN → `fast`** when the task is **mechanical, fully specified, single-file, and
  low-risk** (rename, copy/string change, mechanical refactor, config tweak, docstring/comment).
- **Reviewers:** spec-reviewer → `fast` on a trivial diff; quality-reviewer → `standard` on a
  trivial diff (otherwise stays `deep`).
- **Default-safe:** when signals are ambiguous, **keep the role default** — never downgrade risky
  work on uncertainty.

This subsection becomes the **single source** for tier choice: the old "`fast` = an implementer
downgrade" line and the BLOCKED "re-dispatch at a higher tier" path both point here instead of
restating rules.

### 4.6 SKILL prose

`woostack-execute/SKILL.md` and its `description:` gain a clause that subagent mode **routes each
subagent to a tier-appropriate model** (today they describe the per-task spec+quality loops but
not model variation). `woostack-build` stays mode-agnostic; its step-8/9 prose is touched only if a
one-line mention reads cleanly, otherwise left as-is. The `using-woostack` routing row is
unchanged.

## 5. Components & data flow

| Component | Role | Change |
| --- | --- | --- |
| `skills/using-woostack/references/model-tiers.md` | Canonical shared tier→model table + semantics + provider notes + generic routing/precedence logic | **New** |
| `skills/woostack-review/prompts/_header.md` | Remove table + provider notes + routing/override prose → link + inline anchor; keep review-pipeline Per-repo Config key table; in-prompt references preserved | Edited |
| `skills/woostack-review/prompts/anthropic.md` | Delete embedded Anthropic tier table; repoint Model Routing to shared doc; keep concrete `model:` example + override `jq` binding | Edited |
| `skills/woostack-review/prompts/opencode.md` | Repoint "table in `_header.md`" + precedence to shared doc; keep OpenRouter `reasoning_effort` binding | Edited |
| `skills/woostack-review/scripts/load-prompt.sh` | Inline the shared table into the composed prompt (fail-loud); sync comment on `default_model_for()` | Edited |
| `skills/woostack-execute/references/subagent-driver.md` | Repoint cross-link; add "Dispatch model" contract (wire); add "Tier selection" heuristic (adapt); fold scattered notes | Edited |
| `skills/woostack-execute/SKILL.md` (+ `description:`) | Note per-task model variation in subagent mode | Edited |
| `skills/woostack-execute/prompts/{implementer,spec-reviewer,quality-reviewer}.md` | `tier:` frontmatter unchanged — role-default source | Unchanged (verify) |

**Control flow (per task, subagent mode):**

```
controller picks task
  └─ effective tier = role default ± heuristic (§4.5)
  └─ map tier → concrete model via model-tiers.md
       (host can't route per call → session model, said aloud, degraded)
  └─ dispatch implementer       (model:)  → 4-status handling
  └─ dispatch spec-reviewer     (model:)  → loop until ✅
  └─ dispatch quality-reviewer  (model:)  → loop until ✅
  └─ tick checkboxes
  → next task
```

**Review side (output-neutral):**

```
load-prompt.sh:  CONTEXT_HEAD + [shared model-tiers table inlined] + _header.md + body
                 → composed prompt blob (still contains today's table text)
single-session CI host: model pinned by default_model_for() + --model (mirror of the table)
```

## 6. Error handling

- **Host cannot route per call** → run the session model, say "degraded," never claim a tier ran.
- **Shared doc unreachable / table missing from the composed review prompt** → the `load-prompt.sh`
  inline step **fails loud** (non-zero) rather than shipping a table-less prompt; the CI prompt is
  never silently degraded.
- **BLOCKED "needs more reasoning"** → bump up one tier per §4.5 and re-dispatch; **never**
  silent-retry the same model (existing rule, now anchored to the table).
- **Ambiguous tier signals** → keep the role default; never downgrade risky work on uncertainty.
- **Executable-mirror drift** → `default_model_for()` and the shared table could diverge; mitigated
  by the sync comment plus a test asserting the Anthropic rows agree (§7).
- **Plan steps untrusted / protected branch** → unchanged invariants from `woostack-execute`.

## 7. Testing

Skill-collection (Markdown / shell) change — checks are structural and behavioral; no app test
runner exists in this repo.

**Automated / mechanical:**

- `model-tiers.md` exists and contains the `fast | standard | deep` rows for each provider column.
- **No duplicated table:** grep the review prompts — `_header.md`, `anthropic.md`, `opencode.md`
  no longer embed a tier→model table and instead **link** the shared doc; none still claims the
  table "in `_header.md`". `subagent-driver.md` links the shared doc, **not** `_header.md`. No
  dangling relative paths in either direction.
- **`load-prompt.sh` composed-prompt check:** drive `load-prompt.sh` with stub env and assert the
  emitted `prompt` still contains the tier→model table text (no CI regression), and that a missing
  shared doc makes the step exit non-zero (fail-loud).
- **Mirror sync:** `default_model_for()`'s Anthropic `fast/standard/deep` slugs equal the shared
  doc's Anthropic column.
- The twelve `SKILL.md` files are neither moved nor renamed; relative links resolve.

**Manual / behavioral (dry-run walkthroughs):**

- A trivial single-file task → heuristic resolves `fast` → implementer dispatched at the fast
  model.
- A security/migration task → heuristic resolves `deep` → implementer at the deep model.
- Quality reviewer stays `deep` on a non-trivial diff, downgrades to `standard` on a trivial one.
- A host without per-call routing → the driver runs the session model and reports it as degraded.
- A `woostack-review` run (or composed-prompt inspection) still shows the full Model Tiers table
  and the unchanged output contract.

## 8. Open questions

Resolved in ideation:

1. **Core intent** → **wire + adapt** (operationalize dispatch AND adapt the tier per task), not
   wire-only and not a role-tier rethink.
2. **Adapt mechanism** → **heuristic in the driver** (signal→tier table), not plan-annotated tiers
   and not freeform controller judgment.
3. **Mapping source** → **promote to a neutral shared doc** and repoint review (not "reuse the
   review table" and not "reuse + honor config override").
4. **Doc home** → **`using-woostack/references/model-tiers.md`** (neutral hub) over keeping it under
   `woostack-review`.
5. **Review repoint** → **proceed**: `load-prompt.sh` inlines the shared table, `_header.md` links
   it, `default_model_for()` keeps a sync comment. Output-neutral.

Resolved during spec hardening:

6. **Repoint depth** → **deep dedup**: collapse all four copies (the `_header.md` table, the
   `anthropic.md` embedded table, the `opencode.md` reference, plus the routing/override prose)
   onto the shared doc — not a minimal neutral-table-only move. The blast radius (PR 1 edits
   `_header.md` + `anthropic.md` + `opencode.md` + `load-prompt.sh`) is accepted; the
   output-neutral invariant + the composed-prompt test guard it.
7. **Generic logic vs runtime binding** → the shared doc holds the table + semantics + provider
   notes + **generic** precedence logic; each review prompt keeps its **concrete runtime bindings**
   (`FORCE_TIER`, `run_model`, `/tmp/pr-review/config.json`, `inputs.model`, the override `jq`) as
   thin pointers to the shared precedence. Executable surface stays where it runs; no duplicated
   table or precedence prose. `default_model_for()` stays as the bash executable mirror with a
   sync comment.
8. **Dispatch granularity** → the driver passes whatever the host's subagent API accepts (concrete
   slug or tier model-family), resolved from the host's provider column; MUST pass when the host
   can route per call, else session model + said-aloud degrade.

For harden / plan (implementation detail, not design forks):

- Exact splice mechanism in `load-prompt.sh` (comment-marker replacement vs appended `cat`) —
  invariant: the composed prompt contains today's table text and fails loud if it cannot.
- Exact PR-1 increment split if the review repoint exceeds the soft ≤500-LOC target (e.g.
  CI-critical inline + `_header` first, cosmetic prompt dedup second) — settled in plan harden.
- Whether `woostack-build` SKILL prose needs a touch or stays fully mode-agnostic.
- Exact wording of the "Tier selection" table and the "Dispatch model" contract.
