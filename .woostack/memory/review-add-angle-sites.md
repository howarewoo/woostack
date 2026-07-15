---
name: review-add-angle-sites
type: convention
scope: skills/woostack-review/**
tags: angle, detect-angles, worker-header, orchestrator-header, load-config, anthropic, enumeration, add-angle, tier
hook: Adding a woostack-review angle touches 12 live registration points; `_header.md` is only a compatibility shim, while worker schema and orchestrator count/table/footer/schema live in the split headers.
updated: 2026-07-14
source: [[fixes/2026-07-14-review-acceptance-angle]]
---
Registering an angle so it is **fully** wired (runs, is config-addressable, renders its
footer, routes to the right model, and is tested) touches **twelve** live registration
points. Touch fewer and the angle only half-works — it may run but render no attribution
footer, route to the wrong tier, or be rejected when named in config. Verified 2026-07-14
while adding the `acceptance` angle; `_header.md` is now only a compatibility shim.

1. `scripts/detect-angles.sh` — the gate plus its leading catalog entry.
2. `prompts/angles/<angle>.md` — worker prompt with `tier:` frontmatter and output contract.
3. `scripts/load-config.sh` — `VALID_ANGLES`, or `angles.force`/`angles.skip` rejects it.
4. `prompts/_orchestrator-header.md` — angle-count word.
5. `prompts/_orchestrator-header.md` — Review Angles table row.
6. `prompts/_orchestrator-header.md` — Python attribution-footer whitelist.
7. `prompts/_worker-header.md` — findings-schema `angle` discriminator.
8. `prompts/_orchestrator-header.md` — duplicated posting-schema `angle` discriminator.
9. `SKILL.md` — Stage 2 conditional-angle list.
10. `SKILL.md` — Stage 3 model-routing tier table.
11. `prompts/anthropic.md` — explicit per-angle effort list. OpenAI, Google, and OpenCode
    read `tier:` from frontmatter and need no matching edit.
12. `scripts/tests/test-detect-angles-<angle>.sh` — committed positive and negative gate test,
    plus registry guards for the easy-to-miss sites above.

An angle that consumes a new prefetched artifact also adds that artifact to
`_worker-header.md`, `SKILL.md`'s artifact table/worker brief, and the resolver/prefetch
tests. Public catalog or count changes also update the authored docs site under
`site/content/docs/`; generated per-skill pages are rebuilt, never hand-edited.

**Bumping an existing angle's tier** is a strict subset: prompt frontmatter (2), the
`SKILL.md` tier table (10), and `anthropic.md` (11). See
[[review-angle-trigger-precision]] and [[review-prompt-self-contained-blob]].
