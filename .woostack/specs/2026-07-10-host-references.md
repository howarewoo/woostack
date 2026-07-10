---
name: host-references
type: spec
status: approved
date: 2026-07-10
branch: feature/host-references
links:
  - "[[2026-07-09-omp-model-tiers]]"
---

# Centralized host references — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-10-host-references]]

## 1. Problem

Host-specific instructions (how to dispatch subagents, route tiers, scaffold, and degrade on
Claude Code / Codex / Antigravity / opencode / omp) are scattered across at least seven sites
in six skills:

- `skills/using-woostack/references/model-tiers.md:27-39` — the three "Routing by host
  capability" buckets + the omp host-level fallback note
- `skills/woostack-execute/references/subagent-driver.md:56-58,137-140` — per-host capability
  cases (cwd, spawn), the omp agent-by-tier paragraph, the host-fallback clause
- `skills/woostack-review/SKILL.md:334-338,409-413` — per-host local dispatch rows + host
  routing buckets
- `skills/woostack-commit/SKILL.md:54-58` — omp fast-draft dispatch
- `skills/woostack-init/SKILL.md:61-63` — omp generator scaffold step
- `skills/woostack-execute-overnight/SKILL.md:72-75` — omp usage-exhaustion advisory (PR #475)

Consequences, all observed in this repo's history:

- **Fan-out on every new host.** Adding omp touched every one of these sites
  ([[2026-07-09-omp-model-tiers]] enumerated an 11-file lockstep list); wisdom
  `lockstep-edit-sites` records this class of drift as woostack's most common defect source.
- **Context waste.** Every session loads every host's instructions — a Claude Code session
  carries omp agent-by-tier mechanics, generator paths, and fallback notes it can never use
  (violates the context-economy principle the collection is built on).
- **No single answer surface.** "What can this host do?" has no one place to look; the answer
  is assembled from fragments with per-skill phrasing that drifts independently.

## 2. Goal

One home per host, loaded only when running under that host:

- **`skills/using-woostack/references/hosts/<host>.md`** — six files: `claude-code.md`,
  `codex.md`, `cursor.md`, `antigravity.md`, `opencode.md`, `omp.md`. Each answers a **fixed
  capability contract** (same section skeleton in every file):
  1. **Detection** — capability signals that identify the host (never env-sniffing prose
     beyond what skills already use).
  2. **Subagent spawn** — primitive name; per-call `model`/`effort` knob (yes/no + form);
     per-call `cwd` (yes/no); parallel dispatch shape.
  3. **Tier routing** — how `fast|standard|deep` resolves on this host (per-call arg,
     agent-by-tier defs, or single-session collapse), and the config keys it reads.
  4. **Host-level fallback** — what the host itself does on usage-limit/provider errors
     (e.g. omp credential rotation + `retry.fallbackChains`), and the boundary: woostack
     documents, never manages host config.
  5. **Per-skill notes** — host-specific steps consumed by named skills (init scaffold,
     commit fast-draft, review local dispatch row, overnight advisory).
  6. **Degradation** — what to do when a capability is absent (inherits the generic
     say-so-on-degrade law; states only the host-specific fallback path).
- **Full extraction** (user-selected over skill-side-only): `model-tiers.md` keeps the
  provider table, effort semantics, and override precedence — the *provider/tier* layer —
  and replaces its host buckets + fallback note with a **short pointer paragraph** to
  `hosts/`. Host routing is the *host* layer (memory `review-host-distinct-from-model-provider`).
- **Skills keep law, lose mechanics.** Each consuming skill carries (a) its generic
  invariants inline — never-silent degradation, gates, the capability *questions* to answer —
  and (b) a **hard load directive**: a structural barrier sentence "before dispatching
  subagents (or scaffolding, drafting), read
  `skills/using-woostack/references/hosts/<current-host>.md`; no matching file → treat the
  host as no-per-call-routing and degrade loudly." Host mechanics (agent names, generator
  invocations, knob forms) appear **only** in `hosts/`.

## 3. Non-goals

- **No behavior change.** Pure content reorganization; every instruction that exists today
  survives, relocated. No new config keys, no generator changes, no dispatch semantics change.
- **Review's CI path and prompt blobs untouched.** CI runners follow no links (memory
  `review-prompt-self-contained-blob`), so review's **per-host orchestrator prompts**
  (`prompts/anthropic.md`, `google.md`, `openai.md`, `opencode.md`) remain the self-contained
  home for review-orchestration host content — they are a different layer (review runner
  orchestration) and are **not** merged into `hosts/`. `load-prompt.sh`, `resolve-model.sh`,
  and the `<!-- WOO_MODEL_TIERS_TABLE -->` inline mechanism are unmodified; the inlined
  `model-tiers.md` body shrinks (buckets → pointer) but the provider table and precedence —
  the parts CI resolution actually mirrors — are byte-stable.
- **`hosts/` files are committed skill assets**, not generated artifacts (unlike
  `.omp/agents/` defs). No generator.
- **No SKILL.md moves/renames**; the twenty-two-file constraint holds.
- **Memory/wisdom note *content* is not rewritten** — only the `scope:` globs of notes that
  name relocated paths are updated so recall keeps firing (see §4.6).

## 4. Approach

### 4.1 New `hosts/` directory

`skills/using-woostack/references/hosts/{claude-code,codex,cursor,antigravity,opencode,omp}.md`,
each following the six-section contract in §2. Content is **moved**, not authored fresh:
the omp file absorbs the model-tiers omp bucket + fallback note, the subagent-driver omp
paragraph + fallback clause, the commit fast-draft note, the init scaffold step's mechanics,
the overnight advisory, and review's local omp dispatch row. The other five files absorb
their fragments from the same sites (per-call bucket → claude-code/codex/cursor/opencode;
single-session bucket → codex-action/antigravity; cursor's fragment is review's Stage 3 row —
plan-time discovery, `woostack-review/SKILL.md:335`). A short `hosts/README.md` states the
section contract so future host files stay uniform.

### 4.2 `model-tiers.md` (full extraction)

"Routing by host capability" section shrinks to: one paragraph defining the three capability
classes (per-call / single-session / agent-by-tier) + a pointer line "per-host mechanics:
`hosts/<host>.md`". Provider table, provider notes, effort semantics, and override precedence
stay. The omp "Host-level fallback" note moves to `hosts/omp.md` §4.

### 4.3 Consuming-skill edits (law stays, mechanics leave)

- **`subagent-driver.md`** — the capability-cases table and "Dispatch model" law stay
  (they are generic); the omp paragraph + fallback clause are replaced by the load directive
  (barrier form) + one line per capability question. The "can't run shell guard → inline"
  degradation law stays inline.
- **`woostack-review/SKILL.md` Stage 3** — the five per-host dispatch rows become: generic
  worker-profile law + load directive for **local** runs. The CI/single-session paragraph
  stays (CI cannot follow the link).
- **`woostack-commit/SKILL.md`** — fast-draft rule keeps the tier law + load directive;
  omp mechanics move to `hosts/omp.md` §5.
- **`woostack-init/SKILL.md`** — keeps "under omp, run the generator" as a one-line step
  (it is load-bearing scaffold behavior) but points to `hosts/omp.md` for the mechanics.
- **`woostack-execute-overnight/SKILL.md`** — the omp advisory becomes a host-generic
  advisory ("check the current host's fallback posture — see `hosts/<host>.md` §4") with
  the omp specifics in `hosts/omp.md` §5.

### 4.4 Load directive (structural barrier, uniform wording)

One canonical sentence, identical in every consuming skill (grep-assertable):
"**Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded)." Wisdom `autonomy-needs-structural-proof`: the directive is a barrier, and the say-so law it invokes remains inline in each skill.

### 4.5 Tests (structural lockstep)

- Extend/replace `skills/woostack-init/scripts/tests/test-omp-lockstep.sh` → a
  `test-host-references.sh` that asserts: (a) the six host files exist and each contains the
  six contract section headers; (b) each consuming skill (subagent-driver, review SKILL,
  commit SKILL, init SKILL, overnight SKILL) contains the canonical load directive;
  (c) `model-tiers.md` contains the pointer line and **still** contains the provider-table
  header row (CI-inline stability); (d) the relocated omp phrases (`agent-by-tier`,
  `Host-level fallback`, `usage-exhaustion resilience`, generator invocation) grep in
  `hosts/omp.md`.
- Keep assertions ASCII, one per physical line (memory `grep-assertion-single-physical-line`,
  `skill-test-assert-ascii-token`).

### 4.6 Lockstep riders

- **Memory scopes:** update `scope:` globs on notes naming relocated content —
  `omp-host-fallback-is-host-owned` (add `skills/using-woostack/references/hosts/**`),
  `review-host-distinct-from-model-provider` (unchanged paths still exist; verify). Rebuild
  `MEMORY.md`.
- **Site docs:** `site/content/docs/configuration.mdx` (host table + omp fallback sentence)
  and `concepts.mdx` (if it states the host taxonomy) updated to reference the `hosts/`
  contract; `pnpm -C site build` green. MDX escaping rules apply
  (memory `authored-mdx-escapes-jsx-and-table-pipes`).
- **Stacking:** this feature branches from `fix/omp-host-fallback-docs` (PR #475) because it
  relocates content #475 introduced; the spec+plan PR and increments stack on it.

## 5. Components & data flow

| Component | Role | Change |
| --- | --- | --- |
| `skills/using-woostack/references/hosts/README.md` | Section contract for host files | **New** |
| `skills/using-woostack/references/hosts/{claude-code,codex,cursor,antigravity,opencode,omp}.md` | Per-host capability + mechanics home | **New (content moved)** |
| `skills/using-woostack/references/model-tiers.md` | Provider/tier layer only; host buckets → pointer | Edited (shrinks) |
| `skills/woostack-execute/references/subagent-driver.md` | Generic dispatch law + load directive | Edited (shrinks) |
| `skills/woostack-review/SKILL.md` | Stage 3 local rows → directive; CI paragraph stays | Edited (shrinks) |
| `skills/woostack-commit/SKILL.md` | Fast-draft law + directive | Edited (shrinks) |
| `skills/woostack-init/SKILL.md` | Scaffold step keeps one line + pointer | Edited |
| `skills/woostack-execute-overnight/SKILL.md` | Host-generic fallback advisory + pointer | Edited |
| `skills/woostack-init/scripts/tests/test-host-references.sh` | Structural contract test (supersedes `test-omp-lockstep.sh`) | **New** (old test removed) |
| `.woostack/memory/omp-host-fallback-is-host-owned.md` | `scope:` gains `hosts/**` | Edited |
| `site/content/docs/configuration.mdx` | Authored host-taxonomy sync | Edited |

**Read flow (per session):**

```
skill needs host behavior (dispatch / scaffold / draft / preflight)
  └─ inline law: invariants + capability questions
       └─ load directive → hosts/<current-host>.md   (one file, on demand)
            ├─ found  → apply that host's mechanics
            └─ absent → no-per-call-routing degradation + say so (law already inline)
```

## 6. Error handling

- **Unknown/undetected host** → the load directive's fallback: treat as no-per-call-routing,
  degrade loudly (the say-so law is inline in each skill, so it survives even if no host file
  loads — wisdom `autonomy-needs-structural-proof`).
- **`hosts/` file missing after partial install** → same degradation path; the structural
  test catches it in this repo, and individual installs ship `using-woostack` with the
  command skills (it is the routing skill every install includes).
- **CI runners** → never read `hosts/` (no link-following); all CI-required content remains
  in the self-contained review prompts and the inlined provider table. Structural test (c)
  pins the table row byte-stable.
- **Stale cross-links after the move** → every relocated fragment's old site carries the
  pointer; the structural test greps the canonical directive in each consumer, so a dropped
  pointer fails the test.
- **Stacking risk** → the branch stacks on #475; if #475 changes under review, `gt sync`
  restacks; content conflicts surface as normal rebase conflicts in the worktree.

> **Angle pre-flight.** **security** → N/A (doc/test reorganization; no secrets, no config
> parsing). **observability** → degradation say-so stays inline (AC3); structural test emits
> per-assertion failures. **api/config-contract** → no config keys change; `models.<tier>`
> untouched (AC5). **database** → N/A. **edge/error** → unknown host, missing file, CI
> no-link-following, stacked-base rebase (§6, AC3/AC5/AC6).

## 7. Acceptance criteria

- **AC1 — host files exist and honor the section contract**
  - happy: six `hosts/*.md` + `README.md`; each host file has the six contract headers.
  - error: a host file missing a section header → `test-host-references.sh` fails naming it.
  - edge: future host file additions inherit the same test loop (test iterates `hosts/*.md`,
    not a hardcoded six-name list, excluding `README.md`).
- **AC2 — mechanics moved, not duplicated**
  - happy: omp mechanics phrases (`agent-by-tier` def selection, generator invocation,
    `Host-level fallback`, `usage-exhaustion resilience`) grep in `hosts/omp.md`.
  - error: the same mechanics sentence appearing in both a consuming skill and `hosts/`
    (other than the canonical directive + one-line pointers) is a review-blocking duplication.
  - edge: `woostack-init` keeps its one-line generator step (load-bearing scaffold), pointing
    at `hosts/omp.md` for mechanics.
- **AC3 — law stays inline**
  - happy: each consuming skill still greps its degradation law ("say so", "degraded") and
    carries the canonical load directive verbatim.
  - error: a consumer whose host content was removed without the directive → test fails.
  - edge: unknown host walkthrough — a host with no file resolves to no-per-call-routing +
    say-so using only inline text.
- **AC4 — model-tiers.md keeps the provider/tier layer**
  - happy: provider table header row, provider notes, and override precedence unchanged;
    buckets replaced by one class-definition paragraph + pointer line.
  - error: N/A (structural).
  - edge: `<!-- WOO_MODEL_TIERS_TABLE -->` still resolves; composed review orchestrator prompt
    contains the same provider table text as before the change.
- **AC5 — review CI asymmetry preserved**
  - happy: review SKILL.md Stage 3 local rows point to `hosts/`; the CI/single-session
    paragraph and `prompts/*.md` blobs are diff-clean.
  - error: N/A.
  - edge: `load-prompt.sh` / `resolve-model.sh` untouched (git diff shows no scripts changed
    under `woostack-review/scripts/`).
- **AC6 — lockstep riders land in the same change**
  - happy: memory note scope updated + `MEMORY.md` rebuilt; site pages updated;
    `pnpm -C site build` green; `test-omp-lockstep.sh` removed and superseded.
  - error: N/A.
  - edge: stacked base (#475) rebase leaves the structural test green.

## 8. Testing

Skill-collection repo (markdown + shell; no app harness):

- **Structural:** `test-host-references.sh` (bash, init tests idiom) — section-contract loop
  over `hosts/*.md`, canonical-directive grep per consumer, provider-table stability, moved-
  phrase greps (AC1–AC5). Runs in this repo's test convention (`bash skills/woostack-init/scripts/tests/…`).
- **Behavioral walkthroughs:** dry-run dispatch narratives per host (omp: agent-by-tier;
  Claude Code: per-call model+cwd; unknown host: degradation) recorded in the plan's
  verification steps (AC3).
- **Docs:** `pnpm -C site build` in the worktree after real `pnpm install`
  (memory `site-build-in-worktree-needs-real-node-modules`) (AC6).

## 9. Open questions

All resolved during harden (2026-07-10):

1. **Site pages** — `concepts.mdx` states only the generic principle ("subagents where the
   host can spawn them", line 114-116); no taxonomy table. **Only `configuration.mdx` needs
   the lockstep sync**; `concepts.mdx` is untouched. (Verified by grep.)
2. **Detection in the directive** — no. The canonical directive stays one grep-stable line;
   host detection lives in each host file's §1. A skill that cannot identify the host takes
   the unknown-host degradation path.
3. **Review omp row** — fully relocates. The deep-validator law is already stated generically
   at `woostack-review/SKILL.md:432` ("two opposing-bias `deep`-tier validator passes"), so
   `agent: woostack-deep` is host mechanics, not inline law. (Verified by grep.)

---

_Hardened 2026-07-10 — three open questions resolved with file evidence (above); angle
pre-flight recorded in §6; CI-asymmetry, barrier-law, and lockstep constraints folded into
§3/§4.4/§4.6 at authoring time from wisdom `review-ci-local-asymmetry`,
`autonomy-needs-structural-proof`, `lockstep-edit-sites`. No unresolved branches remain._
