---
type: spec
status: approved
date: 2026-07-10
branch: feature/tier-fallback
links:
  - "[[2026-07-10-tier-fallback-list]]"
---

**Plan:** [[plans/2026-07-10-tier-fallback-list]]

# Tier fallback lists — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth.

> `status:` is the build-loop phase enum defined once in
> [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

A `.woostack/config.json` tier leaf holds exactly one configuration (`"slug"` or
`{ model, effort }`). When that model's provider runs out of usage (e.g. a Codex
subscription hits its limit), woostack has no declared alternative: on omp the user must
hand-maintain `retry.fallbackChains` in omp's own settings (outside the repo, unshared,
unversioned); on other hosts there is nothing to consult. Multi-provider consumers want to
declare, in the one shared config, an ordered list of configurations per tier so agents can
fall back across providers.

## 2. Approved design (Option A, ideate 2026-07-10)

Every tier leaf — flat `models.<tier>` and provider-scoped `models.<provider>.<tier>` —
additionally accepts an **ordered array** of leaf values:

```json
{
  "models": {
    "deep": [
      { "model": "openai/gpt-5.3-codex", "effort": "xhigh" },
      { "model": "anthropic/claude-opus-4-8", "effort": "high" }
    ],
    "standard": "openai/gpt-5.5"
  }
}
```

- **Entry 0 is the primary** and carries today's exact semantics. A one-element array is
  equivalent to the bare value (back-compat: string and object forms unchanged).
- **Entries 1..n are static preference order owned by woostack.** The array declares
  *intent*; **runtime enactment is exclusively per-host** and each
  `hosts/<host>.md` "Host-level fallback" section states what its host does with them.
- **The layer boundary from `omp-host-fallback-is-host-owned` is preserved**: woostack still
  never performs mid-run failover; it only *feeds* the host machinery that does.

## 3. Per-host enactment

| Host | Entries 1..n become |
|---|---|
| omp | Real runtime fallback: `gen-omp-agents.sh` derives a **project-scoped** omp retry fallback chain (primary model → [fallback models]) alongside the generated tier defs. **V1 probe gates this** (§7). |
| Claude Code / Codex / Cursor / Antigravity / opencode | Documented preference order only: no spawn-time auth probe exists, so the consumer switches manually (or re-runs after editing config). The host file says so; no automation is pretended. |

Never written: user-global host config (`~/.omp/**`) — the generator writes only
project-scoped artifacts, same boundary as the existing gitignored tier defs
(memory `review-host-distinct-from-model-provider`).

## 4. Resolution contract (all consumers)

1. **Resolvers read entry 0.** `load-prompt.sh` (CI single-session), `resolve-model.sh`
   (local per-call), and `gen-omp-agents.sh` (def generation) treat an array leaf as its
   first element — both review paths move in lockstep
   (wisdom `review-ci-local-asymmetry`; one shared array-normalization point per script
   pair, not two divergent parsers).
2. **Per-candidate effort.** Each array entry carries its own optional `effort`. Under omp
   *mid-run* fallback the def's `thinkingLevel` continues to apply to the substitute model
   (host semantics — a chain swaps `model` only); a candidate's own `effort` takes effect
   when that candidate is *statically* resolved (promoted to entry 0, or selected by a
   future host that supports it). Documented, not hidden.
3. **Precedence unchanged.** The array changes leaf *shape*, not the override ladder
   (forced tier → explicit model → per-provider → flat → table default,
   `model-tiers.md` §Override precedence). An explicit model input still beats the whole
   list.

## 5. Validation & doctor

- Schema: leaf = `string | {model, effort} | array(1..) of (string | {model, effort})`.
  Empty array → hard config error (same class as `review.models`).
- `woostack-doctor` warns when a fallback list is declared but the current host cannot
  enact entries 1..n (informational-only posture), and errors on malformed entries.

## 6. Edit sites (lockstep, wisdom `lockstep-edit-sites`)

1. `skills/using-woostack/references/model-tiers.md` — leaf-shape paragraph (§54-57 today).
2. `skills/woostack-init/scripts/gen-omp-agents.sh` + its tests — entry-0 def generation +
   fallback-chain emission (V1-gated).
3. `skills/woostack-review/scripts/load-prompt.sh` and `scripts/resolve-model.sh` — array
   normalization (entry 0) in both paths; CI prompt content otherwise untouched.
4. `skills/woostack-doctor/scripts/checks/` — schema/enactment checks.
5. `skills/using-woostack/references/hosts/*.md` — each "Host-level fallback" section gains
   one entries-1..n sentence (six files; contract loop in `test-host-references.sh` keeps
   passing untouched — no new section header).
6. `site/content/docs/configuration.mdx` — leaf-shape + fallback semantics (authored page).
7. Structural tests: extend `gen-omp-agents` tests (array leaf, empty-array error) and add
   a leaf-shape assertion to the init suite.

## 7. V1 probe (verify in plan, non-blocking)

**Does omp honor project-scoped retry fallback config** (e.g. `<project>/.omp/config.yml`
`retry.fallbackChains`), and what are the exact key path + file location? Grounding so far:
omp docs describe `retry.fallbackChains` in omp settings and project-level config overlays
(`omp://settings.md`, `omp://providers.md`), but the project-scope behavior of the retry
block is unverified.

- **Supported** → generator emits the chain file idempotently (gitignored, like the defs),
  keyed primary-model → fallback models from entries 1..n.
- **Unsupported** → generator emits nothing; the list stays informational on omp too
  (documented in `hosts/omp.md`); no other site changes. The feature degrades to
  shared-and-versioned preference order, never to a broken write.

## 8. Non-goals

- No mid-run failover logic in woostack (host-owned, unchanged).
- No writes to user-global host config (`~/.omp/**`).
- No change to the override precedence ladder or the provider table (CI-inlined; byte-stable).
- No spawn-time provider-auth probing on per-call hosts.
- No translation for non-omp hosts.

## 9. Acceptance criteria

- AC1: bare string / object leaves behave byte-identically (resolver outputs unchanged on
  existing fixtures).
- AC2: array leaf resolves to entry 0 in `load-prompt.sh`, `resolve-model.sh`, and
  `gen-omp-agents.sh` (test-pinned in each).
- AC3: empty array → loud config error in generator + doctor; no silent fallback.
- AC4: with the probe positive, omp fallback chain artifact generated idempotently and
  project-scoped; with it negative, zero host-config writes.
- AC5: six host files document the entries-1..n posture; `test-host-references.sh` still
  green with no contract change.
- AC6: provider table + `WOO_MODEL_TIERS_TABLE` marker byte-stable; review `prompts/`
  diff-clean.
- AC7: site builds; `configuration.mdx` documents the array form.

## 10. Open questions

All resolved during harden (2026-07-10):

1. **Provider-scoped arrays too** — one uniform leaf grammar everywhere
   (`string | {model, effort} | array`), so every reader shares a single normalization
   point (wisdom `lockstep-edit-sites`). A provider-scoped array expresses same-provider
   model fallback (e.g. `gpt-5.3-codex` → `gpt-5.5`), which is coherent.
2. **Chain keying** — one chain entry per distinct primary selector; identical primaries
   across tiers dedupe naturally. Two tiers declaring the *same primary with different
   fallback orders* → loud generator error (no silent choice; law from
   `autonomy-needs-structural-proof`).
3. **Chain artifact home** — the probe (§7) resolved to `<repo>/.omp/config.yml`
   (omp's documented project settings layer, merged over global; `omp://settings.md`
   §Where-settings-live, §Project-local-config). Because that file is user-editable, the
   generator performs a **non-clobbering merge**: it owns only the
   `retry.fallbackChains.<primary>` keys it derives, preserves everything else, and on any
   parse failure refuses loudly and prints the block for manual addition (degraded, never
   a corrupting write). Gitignore follows the defs precedent: only a file the generator
   itself created is added to `.omp/.gitignore`; a pre-existing user file is never
   ignored or rewritten wholesale.
4. **Slug injection** (security angle) — YAML/JSON metachars in a configured slug follow
   the same quote-or-reject rule the def generator already enforces
   (spec `2026-07-09-omp-model-tiers` §140).

### V1 probe — narrowed by doc evidence

`omp://settings.md` confirms: project `.omp/config.yml` is a real settings layer
(precedence: defaults < global < project < overlays < runtime), mappings merge per-key
(worked example), and `retry.fallbackChains` is a settings-schema record key. Remaining
plan-time verification (non-blocking): (a) record-value merge semantics for
`retry.fallbackChains` specifically (per-key merge vs whole-record replace), (b) a live
session picks up the project layer for retry settings. Negative on either → the §7
unsupported branch (informational list, zero writes).

---

_Hardened 2026-07-10 — ideate forks resolved by user (shape=A, probe=V1-in-plan); leaf
grammar uniform; chain keyed by primary with conflict-error; non-clobbering project-config
merge with loud refusal branch; slug quoting inherited from the def generator; angle
pre-flight (security / observability / bugs / tests / api / deps / infra) walk clean._
