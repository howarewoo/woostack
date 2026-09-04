# woostack-review configuration

## Public mode

The only public invocation is `/woostack-review <PR#>`, which requires one exact existing pull
request. Configuration cannot create a local-diff target or expose alternate command modes.
Internal worker tier routing (`fast`, `standard`, `deep`) remains available to the swarm and
the sole evidence adjudicator; it is not a user-selectable review mode. See [commands.md](commands.md)
for the public surface and [`../prompts/_orchestrator-header.md`](../prompts/_orchestrator-header.md) for
the canonical posting contract.

## Event-floor rule (prior threads)

`prior-findings.json` (unresolved + resolved threads on the *current* PR) is still produced for incremental mode, but it is used for one thing only: **open** prior threads are an event floor — a non-empty set keeps the new review at minimum `REQUEST_CHANGES`. Resolved threads do not gate the event; a clean incremental pass can `APPROVE`.

## Noise control (`severity_floor` + nits)

`severity_floor` **defaults to `high`** and is a **blocking/visibility threshold**, not a drop gate. Findings at/above the floor are normal findings; validated findings **below** the floor are surfaced as non-blocking **nits** (`Nit:` title prefix, `· NIT` footer) rather than dropped. A below-floor finding that is `blocking: true` is never demoted — it surfaces as a normal blocking finding (blocking overrides the floor). Nits are event-neutral: a PR whose only findings are nits still gets `APPROVE`, with the nits posted inline.

The floor is applied in one place — `scripts/intersect-findings.sh` (Stage 4c) — after the sole evidence adjudicator, so swarm and CI paths agree. Widen the floor per-repo with `review.severity_floor` (`"low"` / `"medium"`).

Set **`review.nits: false`** to restore the old behavior: below-floor non-blocking findings are dropped entirely. (Below-floor *blocking* findings still surface — the override is a global safety rule independent of this knob.)

## Knowledge Aggregation

woostack-review uses bundled rubrics and a bounded external tool inside specific angles:

| Source | Used by | How |
|---|---|---|
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | `design` | `npx -y impeccable detect --json` (run once; feeds both quant + qual passes inside the angle prompt) |
| [coreyhaines31/seo-audit](https://www.skills.sh/coreyhaines31/marketingskills/seo-audit) framework | `seo` | Embedded as the audit rubric in `prompts/angles/seo.md` |
| [coreyhaines31/ai-seo](https://www.skills.sh/coreyhaines31/marketingskills/ai-seo) | `aeo` | Embedded as the rubric in `prompts/angles/aeo.md`; deeper `references/` (platform-ranking-factors, content-patterns, content-types) fetched on demand via `gh api` |

The review bundle is self-sufficient for security and database analysis. Installing the recommended
design and search skills only enhances the host agent's general vocabulary.

## Project Rules

Prefetch auto-discovers project rule files (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.windsurfrules`, `GEMINI.md`) at the repo root, and additionally walks up from each changed file path to collect any `AGENTS.md` / `CLAUDE.md` along the way. The discovered content is concatenated (each section prefixed by a `## SOURCE: <path>` header, 100KB cap) into `$OUTDIR/rules.md` and surfaced to every angle as additional rubric. When that file is present, an extra `conventions` angle fires; the validator drops any finding that claims a rule violation but cannot quote the rule verbatim. Repos without rule files run unchanged.

## Per-repo Configuration (`.woostack/config.json`)

Drop an optional `.woostack/config.json` (and optional primary-checkout `.woostack/config.local.json`)
in the consumer repo to tune the review under the canonical
[effective configuration contract](../../woostack-init/references/artifact-backends.md#effective-repository-configuration-and-precedence).
**Review settings nest under a top-level `review` object** so the file can hold sibling config namespaces
for other woostack tools without collision; keys outside `review` are ignored by the review loader.
Prefetch parses effective configuration into `$OUTDIR/config.json` (canonical copy, flattened);
downstream stages read from there. Missing files = defaults (`severity_floor: high`). **All keys are optional —
specify only the ones you want to override; the rest keep their built-in defaults.** Invalid JSON, an empty
config file, a non-object `review`, or an unknown key *inside* `review` → loud
`::error file=.woostack/config.json,line=N::<msg>` annotation and the workflow fails (no false-pass on typos).

> **Transition note:** review keys placed at the top level (the pre-nesting layout) are still accepted but emit a deprecation `::warning`. Migrate them under `review`. The one exception is `models`, which is a deliberate root-level sibling of `review` (see below) — a nested `review.models` is a hard error, not a deprecation.

Minimal example — override one knob, everything else stays default:

```json
{ "review": { "severity_floor": "medium" } }
```

Full schema (every key shown; all optional):

```json
{
  "models": {
    "fast": "anthropic/claude-haiku-4-5",
    "standard": { "model": "openai/gpt-5.5", "effort": "medium" },
    "deep": "anthropic/claude-opus-4-8",
    "openai": {
      "fast": { "model": "gpt-5.5", "effort": "low" },
      "standard": { "model": "gpt-5.5", "effort": "medium" },
      "deep": { "model": "gpt-5.5", "effort": "high" }
    },
    "anthropic": {
      "fast": { "model": "claude-opus-4-8", "effort": "low" },
      "standard": { "model": "claude-opus-4-8", "effort": "medium" },
      "deep": { "model": "claude-opus-4-8", "effort": "xhigh" }
    }
  },
  "review": {
    "angles": {
      "force": ["database"],
      "skip": ["seo"]
    },
    "severity_floor": "high",
    "nits": true,
    "defer_markers": true,
    "ignore": [
      "**/*.generated.ts",
      "migrations/*.sql"
    ],
    "project_rules": [
      "constitution.md",
      "docs/standards/*.md"
    ],
    "authors_skip": [
      "dependabot[bot]",
      "renovate[bot]"
    ],
    "release_rollup_pattern": "^(staging|release|chore\\(release\\))",
    "fix_commands": ["pnpm lint:fix", "pnpm format"],
    "chunking": {
      "max_loc": 4000
    }
  }
}
```

Key reference (JSON has no comments, so the per-key semantics live here):
- **`angles.force`** — always run these, even if not auto-detected. **`angles.skip`** — never run these (`bugs`/`security`/`simplify` cannot be skipped).
- **`severity_floor`** — one of `low` | `medium` | `high`; a blocking/visibility threshold, **not** a drop gate. **Default `high`**. Findings below the floor surface as non-blocking nits (see `nits`); set `low`/`medium` to treat more findings as normal (at/above-floor). Applied once by `intersect-findings.sh` (Stage 4c).
- **`nits`** — `true` | `false`; default **`true`**. When `true`, validated findings below `severity_floor` surface as non-blocking nits instead of being dropped. Set `false` to drop them (the pre-reframe behavior). Below-floor `blocking` findings always surface regardless of this knob.
- **`defer_markers`** — `true` | `false`; default **`true`**. When `true`, the evidence adjudicator honors inline `woostack-defer(<ref>)` markers (authored by `woostack-execute` under an approved plan): a finding that flags work a later increment intentionally completes is demoted to a non-blocking `Deferred to <ref>` nit instead of a normal finding (issue #224). Set `false` to ignore the markers. It never defers `security` findings or wrong code present in this PR; reads the marker from the PR's own diff, so it fetches no other PRs.
- **`ignore`** — fnmatch globs; ignored paths skip angle triggers + diff body.
- **`project_rules`** — fnmatch globs appended to auto-discovered `rules.md`.
- **`authors_skip`** — PR author logins that short-circuit the entire review. Defaults: `dependabot[bot]`, `renovate[bot]`, `github-actions[bot]`. Set to `[]` to opt out.
- **`release_rollup_pattern`** — Python regex on the PR title; default: `^(staging|release|chore\(release\))` (note `\\(` to escape the paren in JSON). An empty string opts out.
- **`models`** — **root-level** per-tier model overrides (moved out of `review.models`; a lingering `review.models` is now a hard loader error — `woostack-doctor` warns on it too). Each tier leaf is a model-slug string, an object `{ "model": "<slug>", "effort": "<level>" }`, or a non-empty ordered array of those forms. Array entry 0 is the primary used wherever one concrete model is required; later entries remain available to hosts such as OMP that enact fallback routing. `effort` is one of `minimal | low | medium | high | xhigh` (empty = unset). Use flat `models.fast` / `.standard` / `.deep` as provider-agnostic fallbacks, or provider-scoped maps such as `models.openai.deep`, `models.anthropic.standard`, `models.google.standard`, and `models.openrouter.fast` when the same repo is reviewed by multiple coding agents. The action input `inputs.model` still wins. Effort is consumed by OpenAI/Codex (`load-prompt.sh`) and by Anthropic per-call spawns (`prompts/anthropic.md`, where it is the sole tier differentiator now that every Anthropic tier is `claude-opus-4-8`), config-first over the built-in tier default.
- **`fix_commands`** — reserved for implementation workflows; review never executes them.
- **`metrics`**: opt in to per-angle signal/noise metrics (bool, default `false`) — emit `findings.metrics.json` per run and fold a rolling `.woostack/metrics.json` aggregate (local only). Each angle also carries `overlap_total` + `overlap_with` (how often another angle raised the same issue, on the raw pre-validation set — a redundancy signal). Aggregate schema is v3; an older aggregate is reseeded on first fold. See Stage 6 in the root skill.
- **`chunking.max_loc`** — diff-chunking threshold (issue #14). When the post-ignore diff exceeds this many changed lines, prefetch splits it into chunks honoring workspace package roots > top-level dirs > file-LOC-balanced groups; each angle fans out as angles × chunks parallel sub-agents. `0` disables chunking; default is 4000.

**Precedence**: for the angle set, `angles.force` beats `angles.skip` when the same angle is listed
in both. Internal model resolution consults `models.<provider>.<tier>` before flat
`models.<tier>` and then the canonical defaults in `prompts/_orchestrator-header.md`. `ignore` is
applied to both file paths and the per-file diff sections before angle gates evaluate.
