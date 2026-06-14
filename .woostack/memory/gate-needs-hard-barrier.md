---
name: gate-needs-hard-barrier
type: gotcha
scope: skills/**/SKILL.md
tags: gate, approval, barrier, HARD-GATE, low-effort-model, summarization, address-comments
hook: A load-bearing approval gate written only as soft body prose gets skipped by low-effort/fast models; make it a prominent STOP barrier AND restate it in Hard constraints.
updated: 2026-06-11
source: [[fixes/2026-06-11-address-comments-verdict-gate]]
---
A skill's load-bearing approval gate must be **structurally** enforced, not just described in
the workflow body. `woostack-address-comments` skipped its verdict gate under
`gpt-5.3-codex-spark` (Codex CLI, #282) because the gate lived only as soft prose
("By default it presents…", a Phase-2 bullet) with **no prominent STOP barrier** and was
**absent from `## Hard constraints`** — the most skim/summary-resistant section. A low-effort
model collapses the Phase 1→2→3 narrative and acts before rendering the gate.

Rule when authoring any gated skill: (1) add a `<HARD-GATE>`-style barrier near the top (the
construct `using-woostack`, `woostack-debug`, and `woostack-ideate` already use), and
(2) **restate the gate in `## Hard constraints`** with an unambiguous line like
`Silence is not a yes`. Redundancy across barrier + workflow + Hard-constraints is the feature,
not duplication — it is what survives summarization and low-reasoning runs. Keep any `--auto` /
non-interactive carve-out inside the barrier so autonomy is unchanged. Related:
[[fix-delegates-to-execute]].
