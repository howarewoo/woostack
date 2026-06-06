---
name: review-add-angle-sites
type: convention
scope: skills/woostack-review/**
tags: angle, detect-angles, _header, enumeration, add-angle, tier
hook: Adding a woostack-review angle means touching 8 enumeration sites — miss the _header count or the Python footer whitelist and the angle only half-works.
updated: 2026-06-06
source: .woostack/plans/2026-06-06-review-self-contained.md
recall_count: 0
---
Angles are registered across **eight** sites. Touch all of them or the angle
silently misbehaves (runs but renders no footer, or never runs at all):

1. `scripts/detect-angles.sh` — the gate: a `has_<angle>_file()` / `has_<angle>_diff_token()`
   predicate (or reuse an existing one like `has_code_file`) **and** an `ANGLES+=("<angle>")`
   block, plus the angle-gating doc-header comment near the top.
2. `prompts/angles/<angle>.md` — the new angle prompt (`tier:` frontmatter, Scope / Find /
   Skip / Severity / Output, writing `findings.<angle>.json`).
3. `prompts/_header.md` — the count word ("up to **N** distinct review angles"). Easy to miss.
4. `prompts/_header.md` — the **Review Angles** table row.
5. `prompts/_header.md` — the Python footer **whitelist set** (`if angle in {…}`). An angle
   absent here runs but renders **no attribution footer** on its comments. Easiest to miss.
6. `prompts/_header.md` — the Findings-schema `angle` discriminator enumeration.
7. `SKILL.md` — the prose conditional-angle list (Stage 2 / Detect Angles).
8. `SKILL.md` — the model-routing **tier table** row.

Sites 3–6 all live in `_header.md`, which is why a count or whitelist edit is the one people
forget. Verify a new angle end-to-end by running `detect-angles.sh` against a fixture diff and
asserting the angle name appears in `angles.txt`. Bumping an existing angle's tier touches a
subset: the prompt frontmatter (site 2) and the SKILL.md tier table (site 8). See
[[review-angle-trigger-precision]] and [[review-prompt-self-contained-blob]].
