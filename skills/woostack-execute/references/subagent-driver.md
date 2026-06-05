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
   session's history. Resolve and pass its model per
   [Dispatch model](#dispatch-model-resolve--map--pass) and [Tier selection](#tier-selection). It
   follows TDD, self-reviews, and **reports its changed files + diff; it does not commit.**
2. **Handle its status** — one of:
   - **DONE** → proceed to spec review.
   - **DONE_WITH_CONCERNS** → read the concerns; resolve correctness/scope ones before review,
     note observations and proceed.
   - **NEEDS_CONTEXT** → provide the missing context and re-dispatch.
   - **BLOCKED** → assess: context gap (re-dispatch with more context), needs more reasoning
     (re-dispatch per [Tier selection](#tier-selection) — a prior BLOCKED is itself
     a bump-UP signal), task too large (split it), or the plan is wrong (escalate to the user).
     **Never** silently retry the same model unchanged.
3. **Dispatch a spec-compliance reviewer** with
   [../prompts/spec-reviewer.md](../prompts/spec-reviewer.md), scoped to the implementer's
   reported task diff (this isolates the current task from earlier tasks' still-uncommitted work,
   since there is no per-task SHA to diff against). If it finds gaps, the **same implementer**
   fixes them and the reviewer re-reviews. Loop until ✅. Resolve and pass its model per
   [Dispatch model](#dispatch-model-resolve--map--pass) and [Tier selection](#tier-selection).
4. **Dispatch a code-quality reviewer** with
   [../prompts/quality-reviewer.md](../prompts/quality-reviewer.md) — only after spec compliance
   is ✅ — scoped to the same diff. Fix-and-re-review loop until ✅. Resolve and pass its model per
   [Dispatch model](#dispatch-model-resolve--map--pass) and [Tier selection](#tier-selection).
5. **Tick the plan's checkboxes in place** for the completed task.

A reviewer finding an issue the implementer cannot resolve surfaces as **BLOCKED** → escalate to
the user. This is the blocking-stop for subagent mode; there is no `woostack-review --fast`
`REQUEST_CHANGES` gate here.

## Model tiers

Use woostack's shared tier vocabulary — `fast | standard | deep` — resolved through the shared
Model Tiers table in
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md).
Each prompt template declares its `tier:` in frontmatter as the role default.

### Tier selection

Each role has a **default** tier (its prompt's `tier:` frontmatter): implementer `standard`,
spec-reviewer `standard`, quality-reviewer `deep`. The controller adjusts that default **per task**
from complexity and risk — this table is the single home for the choice:

| Adjust | Effective tier | When |
|---|---|---|
| **Bump UP** | `deep` | the task touches security / auth / crypto, data migrations, concurrency / locking, money / billing, or is cross-cutting / architectural; the task spec is highly ambiguous; or the task previously returned **BLOCKED** for "needs more reasoning". |
| **Bump DOWN** | `fast` | the task is mechanical, fully specified, single-file, and low-risk (rename, copy/string change, mechanical refactor, config tweak, docstring/comment). |
| **Reviewer downgrade** | `fast` / `standard` | spec-reviewer → `fast` on a trivial diff; quality-reviewer → `standard` on a trivial diff (otherwise stays `deep`). |
| **Ambiguous signals** | role default | default-safe — never downgrade risky work on uncertainty. |

### Dispatch model (resolve → map → pass)

Before each subagent dispatch, resolve the task's **effective tier** (role default, adjusted per
[Tier selection](#tier-selection) above), map it to the host's model via the shared
[model-tiers.md](../../using-woostack/references/model-tiers.md) (use the column for the host's
provider — usually the session's), and **pass that model on the dispatch** (the `model:` arg of
the `Agent`/`Task` call). Pass whatever value the host's subagent API accepts — a concrete slug
where it takes slugs, or the tier's model **family** (`haiku`/`sonnet`/`opus`) where it takes
families.

**When the host supports per-call routing, every dispatch MUST pass the resolved model.** Omitting
it makes the subagent inherit the parent session's model (typically Opus), silently defeating tier
routing and burning multiples of the tokens on cheap work — the same rationale
`woostack-review`'s [`prompts/anthropic.md`](../../woostack-review/prompts/anthropic.md) already
states for its angle spawns. **When the host cannot route per call**, run at the session model and
**say so** (degraded, not equivalent) — never pretend a tier ran.

## Review

Subagent mode's automated review **is** the per-task spec + quality loops above — it does **not**
run `woostack-review --fast` (that would double-review the same code). Each increment PR is
reviewed **manually by the human** after execution, which covers whole-increment integration.

## Hand back

When every task in the increment is ✅ and checked off, hand back to [SKILL.md](../SKILL.md) for
the single `woostack-commit` and distillation. **Never-merge carve-out:** this driver does
**not** call any branch-finishing or merge step and never offers or performs a merge.
