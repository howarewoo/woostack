---
name: review-prompt-self-contained-blob
type: gotcha
scope: skills/woostack-review/**
tags: load-prompt, _header, ci-prompt, inline, cross-reference, model-tiers
hook: woostack-review prompts ship as ONE self-contained blob to CI runners that follow no markdown links — shared content must be inlined, not just linked.
updated: 2026-06-05
source: .woostack/plans/2026-06-05-execute-vary-subagent-model.md
recall_count: 8
last_recalled: 2026-06-08
---
`load-prompt.sh` concatenates `_header.md` + the provider body into a single
prompt string handed to external runners (`claude-code-action`, `codex-action`,
`run-gemini-cli`, `opencode`). Those runners receive **one text blob** and do
**not** follow markdown cross-links.

So when you factor shared content out of a review prompt into another file (e.g.
the tier→model table → `using-woostack/references/model-tiers.md`), a plain link
**silently drops it from the CI prompt**. You must inline it back into the
composed blob. Pattern used here: a `<!-- WOO_MODEL_TIERS_TABLE -->` marker in
`_header.md` that `load-prompt.sh` replaces with the shared doc's body, **failing
loud** (`exit 1`) when the doc or the marker is missing:

```bash
HEADER_INLINED="${HEADER_RAW/<!-- WOO_MODEL_TIERS_TABLE -->/$(cat "$TIERS_FILE")}"
```

Verify output-neutrality by composing the prompt with stub env
(`ACTION_PATH=… PROVIDER=anthropic … GITHUB_OUTPUT=/tmp/out bash load-prompt.sh`)
and grepping the raw `$GITHUB_OUTPUT` file for the moved content — the framing
lines carry no payload, so a content grep is a clean presence check.

Caveat: any **executable mirror** of inlined doc content (here
`default_model_for()` resolves tier→model in bash, since bash can't read a
markdown table) must be kept in sync with the doc by hand — leave a
`# canonical source:` comment on it. See [[review-config-bool-jq-default]] (same
scripts dir).
