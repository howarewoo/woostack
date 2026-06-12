---
name: review-host-distinct-from-model-provider
type: gotcha
scope: skills/woostack-review/**, action.yml
tags: host, provider, gemini, antigravity, ci-runner, migration
hook: woostack-review's CLI host and model provider are separate layers — google.md is named per provider but its body is host orchestration. Migrate one without touching the other.
updated: 2026-06-12
source: .woostack/fixes/2026-06-12-antigravity-cli-migration.md
---
woostack-review separates the **host** (the CLI agent that runs the review) from the
**model provider** (the LLM that judges). The trap: `prompts/google.md` is named after the
*provider* (`google`) but its body is *host* orchestration — so a CLI-host change edits a
provider-named file.

When swapping a CLI host (e.g. gemini CLI → Antigravity CLI), the **host** surface to rename:
- `prompts/google.md` — title + subagent-dispatch narrative + `Host identifier` default slug.
- `prompts/_header.md` — the `<host>` slug whitelist, the env detection hint, and the
  `<cli> --version` runtime-introspection example.
- `using-woostack/references/model-tiers.md` — the single-model-per-session vs per-call bucket.
- `SKILL.md` — the host-agnostic list, the per-host dispatch note, the single-model note.
- `scripts/prefetch.sh` + `detect-angles.sh` — local/non-GHA host comments.

Leave the **model** surface alone (a CLI swap is not a model swap): `detect-provider.sh`
provider branch + API-key inputs, `resolve-model.sh` default model slug, the `gemini_api_key`
inputs in `action.yml`/`reusable-review.yml`, and `GEMINI.md` rule-file discovery (back-compat).

Sharp gotcha: `action.yml`'s `run-gemini-cli` CI runner is a *host* dependency, but a newer CLI
can't always replace it. Antigravity CLI (`agy`) authenticates via system keyring / Google
Sign-In with no documented non-interactive API-key path and ships no first-party GitHub Action,
so it **cannot run headless in an ephemeral CI runner** — the CI host stays on run-gemini-cli with
a deprecation note even when every doc/prompt host reference migrates. Verify non-interactive
auth + a pinned Action exist before migrating any CI runner. See [[review-prompt-self-contained-blob]]
(runner list) and [[review-model-resolution-two-paths]] (model layer).
