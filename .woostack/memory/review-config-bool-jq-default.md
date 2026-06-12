---
name: review-config-bool-jq-default
type: gotcha
scope: skills/woostack-review/scripts/**
tags: jq, config, boolean, defaults, intersect-findings, load-config
hook: jq `// default` silently coerces an explicit `false` to the default — wrong for any default-TRUE config bool.
updated: 2026-06-04
source: .woostack/plans/2026-06-04-review-nit-comments.md
---
jq's `//` is the *alternative* operator: it returns the right-hand side when the
left is `null` **or** `false`. So `jq -r '.key // true'` returns `true` for an
explicit `{"key": false}` — silently ignoring the opt-out.

This is safe for the review config's default-**false** bools (`disable_adversarial`,
`metrics`): `.disable_adversarial // false` maps absent→false, true→true, false→false.
It is **wrong** for any default-**true** bool. `nits` (default true) was the first,
and `intersect-findings.sh` detects the opt-out explicitly instead:

```bash
nits_enabled="true"
v="$(jq -r '.nits' "$CONFIG" 2>/dev/null || echo null)"
[ "$v" = "false" ] && nits_enabled="false"
```

Any future default-true config key must use the same explicit `[ "$v" = "false" ]`
pattern, not `// true`. The canonical bool validation still lives in `load-config.sh`
(whitelist in `REVIEW_KEYS` + `isinstance(val, bool)` check); the consuming script
re-reads from `$OUTDIR/config.json` and applies this default. See [[woostack-feature-state-invariant]].
