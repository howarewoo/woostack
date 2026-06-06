---
name: review-add-angle-sites
type: convention
scope: skills/woostack-review/**
tags: angle, detect-angles, _header, load-config, anthropic, enumeration, add-angle, tier
hook: Adding a woostack-review angle touches 11 sites — the easy-to-miss four are load-config VALID_ANGLES, the anthropic.md tier list, the _header footer whitelist, and the committed gating test.
updated: 2026-06-06
source: .woostack/plans/2026-06-06-review-self-contained.md
recall_count: 3
last_recalled: 2026-06-06
---
Registering an angle so it is **fully** wired (runs, is config-addressable, renders its
footer, routes to the right model, and is tested) touches **eleven** sites. Touch fewer and
the angle only half-works — it may run but render no attribution footer, route to the wrong
tier, or be rejected when named in config. Verified 2026-06-06 adding the `comments` angle
(the first pass missed sites 3, 10, 11 — the angle shipped under-wired and needed a fixup PR).

1. `scripts/detect-angles.sh` — the gate: a `has_<angle>_*` predicate (or reuse one like
   `has_code_file`), an `ANGLES+=("<angle>")` block, **and** the leading doc-header catalog entry.
2. `prompts/angles/<angle>.md` — the worker prompt (`tier:` frontmatter + Scope/Find/Skip/
   Severity/Output writing `findings.<angle>.json`).
3. `scripts/load-config.sh` — add the name to the `VALID_ANGLES` set, else
   `angles.force`/`angles.skip: ["<angle>"]` in `.woostack/config.json` is **rejected as unknown**.
4. `prompts/_header.md` — the angle **count** word ("up to **N** distinct review angles").
5. `prompts/_header.md` — the **Review Angles** catalog table row.
6. `prompts/_header.md` — the **Python footer whitelist** set (`if angle in {…}`). Absent here,
   the angle's findings render with **no attribution footer** (the `skills` angle was itself
   missing from it until 2026-06-06).
7. `prompts/_header.md` — the **Findings-schema** `angle` discriminator enumeration.
8. `SKILL.md` — the Stage 2 prose conditional-angle list.
9. `SKILL.md` — the Stage 3 model-routing **tier table** row.
10. `prompts/anthropic.md` — the per-angle tier prose list (the Sonnet/Haiku enumeration).
    `openai.md` / `google.md` / `opencode.md` read tier from frontmatter and need **no** edit.
11. `scripts/tests/test-detect-angles-<angle>.sh` — the committed gating test (assert the angle
    appears in `angles.txt` for a triggering diff and is absent otherwise).

Sites 4–7 all live in `_header.md`. **Bumping an existing angle's tier** is a strict subset:
the prompt frontmatter (2), the SKILL.md tier table (9), **and** the `anthropic.md` list (10) —
miss 10 and the default Anthropic orchestrator still routes the old tier. See
[[review-angle-trigger-precision]] and [[review-prompt-self-contained-blob]].
