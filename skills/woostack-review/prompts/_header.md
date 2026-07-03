# Compatibility shim for woostack-review prompts

`_header.md` is intentionally no longer a review contract. It exists only so older
links fail safe instead of reloading the historical monolith.

Load the split contract that matches the role:

- `prompts/_worker-header.md` — angle-worker contract: output discipline, prefetched
  artifacts, finding schema, blocking criteria, and receipt proof.
- `prompts/_orchestrator-header.md` — orchestrator/publisher contract: model-tier table,
  per-repo config, review status/event rules, batched GitHub Review payload, pending-review
  preflight, watermark, and credits.

Do not cite this shim as the worker schema or posting procedure; it deliberately omits both.
