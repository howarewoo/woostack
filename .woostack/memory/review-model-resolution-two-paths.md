---
name: review-model-resolution-two-paths
type: gotcha
scope: skills/woostack-review/**
tags: review, model, tier, config, resolve-model, load-prompt, dispatch
hook: woostack-review resolves the tier→model on two paths (CI single-session and local per-call); a config-aware resolver wired into only one silently regresses the other.
updated: 2026-06-11
source: .woostack/fixes/2026-06-11-review-local-model-resolution.md
---
woostack-review picks each worker's model on **two independent paths**, and both
must apply the same config precedence (`models.<provider>.<tier>` → flat
`models.<tier>` from `$OUTDIR/config.json` → default table):

1. **CI single-session host** — `load-prompt.sh` resolves one `run_model` and emits
   it to `$GITHUB_OUTPUT`.
2. **Local per-call-routing host** (Claude Code `Task`, Codex/opencode subagents) —
   resolves a model *per spawn* and must call
   `scripts/resolve-model.sh --provider <p> --tier <t>`, using the slug for both the
   spawn `model` override and the receipt `model`.

Issue #295: the config-aware resolver lived only in `load-prompt.sh`, so local
spawns read the static `_header.md` default table and ignored
`models.openai.standard` overrides. Fix: extract `provider_tier_model` /
`default_model_for` into `resolve-model.sh` as the single source of truth
(`load-prompt.sh` sources it) and point SKILL.md's local dispatch at it.

Rule: any change to model resolution must cover **both** paths — reading the
`_header.md` table directly anywhere but as the final default is a routing bug.
The `_header.md` table is precedence step 5 only. See
[[review-openai-tier-effort-override]] for the parallel effort-default rule.
