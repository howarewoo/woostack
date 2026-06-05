---
tier: standard
---

# Subagent execution driver

The **subagent-driven** driver of [`woostack-execute`](../SKILL.md) — the subagent-driven
implementation pattern, internalized so woostack has no runtime dependency on any external skill.
Use it
when `--subagent` is passed, or when the smart default resolves to subagent (the host can spawn
subagents, e.g. an `Agent`/`Task` tool is available). See [inline-driver.md](inline-driver.md)
for the other mode.

**Core shape:** a fresh implementer subagent per task, followed by a two-stage review loop —
spec compliance first, then code quality — each looping until it passes. The controller
coordinates; it does not implement.

## Sequencing (read first)

Tasks within an increment run **sequentially**. They share the controller's one working tree, so
implementer subagents are **never dispatched in parallel** — concurrent edits to one tree corrupt
it. This also matches woostack's "one increment per cycle."

There is **no per-task git commit.** Each implementer leaves its work uncommitted in the shared
tree and reports the files it changed plus its task diff. The single `woostack-commit` happens
once per increment (see [SKILL.md](../SKILL.md)), after every task in the increment reaches ✅.

## Per-task loop

For each task in the increment, in order:

1. **Dispatch an implementer subagent** with [../prompts/implementer.md](../prompts/implementer.md).
   Pass the full task text and exactly the context it needs — the subagent never inherits this
   session's history. It follows TDD, self-reviews, and **reports its changed files + diff; it
   does not commit.**
2. **Handle its status** — one of:
   - **DONE** → proceed to spec review.
   - **DONE_WITH_CONCERNS** → read the concerns; resolve correctness/scope ones before review,
     note observations and proceed.
   - **NEEDS_CONTEXT** → provide the missing context and re-dispatch.
   - **BLOCKED** → assess: context gap (re-dispatch with more context), needs more reasoning
     (re-dispatch at a higher tier), task too large (split it), or the plan is wrong (escalate to
     the user). **Never** silently retry the same model unchanged.
3. **Dispatch a spec-compliance reviewer** with
   [../prompts/spec-reviewer.md](../prompts/spec-reviewer.md), scoped to the implementer's
   reported task diff (this isolates the current task from earlier tasks' still-uncommitted work,
   since there is no per-task SHA to diff against). If it finds gaps, the **same implementer**
   fixes them and the reviewer re-reviews. Loop until ✅.
4. **Dispatch a code-quality reviewer** with
   [../prompts/quality-reviewer.md](../prompts/quality-reviewer.md) — only after spec compliance
   is ✅ — scoped to the same diff. Fix-and-re-review loop until ✅.
5. **Tick the plan's checkboxes in place** for the completed task.

A reviewer finding an issue the implementer cannot resolve surfaces as **BLOCKED** → escalate to
the user. This is the blocking-stop for subagent mode; there is no `woostack-review --fast`
`REQUEST_CHANGES` gate here.

## Model tiers

Use woostack's shared tier vocabulary — `fast | standard | deep` — resolved through the Model
Tiers table in [`../../woostack-review/prompts/_header.md`](../../woostack-review/prompts/_header.md).
Each prompt template declares its `tier:` in frontmatter:

- **`fast`** — mechanical 1–2-file tasks with a complete spec (an implementer downgrade).
- **`standard`** — multi-file integration; the default implementer and the spec reviewer.
- **`deep`** — design/architecture judgment and the code-quality reviewer.

Where the host cannot route models per call, fall back to the session model.

## Review

Subagent mode's automated review **is** the per-task spec + quality loops above — it does **not**
run `woostack-review --fast` (that would double-review the same code). Each increment PR is
reviewed **manually by the human** after execution, which covers whole-increment integration.

## Hand back

When every task in the increment is ✅ and checked off, hand back to [SKILL.md](../SKILL.md) for
the single `woostack-commit` and distillation. **Never-merge carve-out:** this driver does
**not** call any branch-finishing or merge step and never offers or performs a merge.
