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

The input to this loop is one Markdown increment's ordered task list or one Linear issue's
normalized ordered task list, already selected and claimed by the backend
[controller](controller.md). The driver implements and reviews task content only: it
does not transition Linear state, write branch/PR attribution, or decide dependency/Git-parent
readiness.

**Self-contained briefs.** Every dispatched brief (implementer, spec-reviewer, quality-reviewer)
is **self-contained**, and the workers run on a plain/general-purpose profile: they must **never**
load `skill://woostack-review` or route via `using-woostack` into the PR-review orchestrator. A
fresh subagent boots inside the consumer repo and inherits its `AGENTS.md`, so a bare "review this
task" brief otherwise routes "review" intent into the full `woostack-review` skill — the wrong
contract for a task-scoped reviewer, and ~14.7K tokens of the wrong instructions. This mirrors
`woostack-review`'s own worker-brief guard (issue #447).

## Sequencing (read first)

Tasks within an increment run **sequentially**. They share the controller's one working tree, so
implementer subagents are **never dispatched in parallel** — concurrent edits to one tree corrupt
it. This also matches woostack's "one increment per cycle."

There is **no per-task git commit.** Each implementer leaves its work uncommitted in the shared
tree and reports the files it changed plus its task diff. The single `woostack-commit` happens
once per increment (see [SKILL.md](../SKILL.md)), after every task in the increment reaches ✅.

## Worktree placement

Every implementer must do its writes in the increment's per-PR worktree `$wt`, never the primary
checkout (the [worktree contract](../../woostack-init/references/worktrees.md) §3: the primary tree
is never edited). The contract's `cwd = $wt` is satisfied in two layers, and the driver **always**
applies both where available:

- **Dispatch-prompt pin (always).** Fill the implementer prompt's `<worktree absolute path — $wt>`
  placeholder with `$wt`. The prompt's "Worktree pin (do this FIRST)" block makes the implementer
  `cd "$wt"` and hard-assert `git rev-parse --show-toplevel` equals `$wt` **before any write**,
  aborting (BLOCKED) otherwise. This is the **portable** mechanism — it works on a host whose spawn
  API has **no per-call cwd**, because the implementer self-pins.
- **Per-call cwd (when the host supports it).** If the host's spawn primitive accepts a per-call
  cwd, set it to `$wt` too — belt-and-suspenders; the prompt guard then merely double-checks a
  correctly-placed agent and costs nothing.

**Capability cases:**

| Host spawn API | Placement |
|---|---|
| Has per-call cwd | Set cwd = `$wt` **and** fill the prompt pin (guard double-checks). |
| No per-call cwd (e.g. Claude Code's `Agent` tool) | Fill the prompt pin; the implementer self-pins and aborts if not in `$wt`. Safe. |
| Can't run the self-pin shell guard at all | It also can't run the plan's TDD/verification — same class as "no test harness". Fall back to **inline** (say so; degraded, never pretend subagent ran). |

`isolation: "worktree"`-style host flags are **not** a substitute: they create a *fresh throwaway*
worktree, not the controller's tracked per-PR branch `$wt` (created + `gt track --parent <base>`),
so commits would land off the PR branch. Do not use them to satisfy this contract.

## Per-task loop

For each task in that selected increment task list, in order:

1. **Dispatch an implementer subagent** with [../prompts/implementer.md](../prompts/implementer.md).
   Pass the full task text and exactly the context it needs — the subagent never inherits this
   session's history. **Place it in the increment's worktree per [Worktree placement](#worktree-placement)
   above:** fill the prompt's `<worktree absolute path — $wt>` pin with `$wt`, and additionally set
   the spawn call's cwd to `$wt` where the host's API exposes one. Route its effective tier per
   [Dispatch model](#dispatch-model-resolve--map--pass) and [Tier selection](#tier-selection). It
   follows TDD, self-reviews, and **reports its changed files + diff; it does not commit.**
2. **Handle its status** — one of:
   - **DONE** → proceed to spec review.
   - **DONE_WITH_CONCERNS** → read the concerns; resolve correctness/scope ones before review,
     note observations and proceed.
   - **NEEDS_CONTEXT** → provide the missing context and re-dispatch.
   - **BLOCKED** → assess: context gap (re-dispatch with more context), task too large (split it),
     or the plan is wrong (escalate to the user). If a `fast` implementer specifically needs more
     reasoning, re-dispatch once at `standard` per [Tier selection](#tier-selection). A `standard`
     implementer never retries at `deep`; split the task or escalate instead. **Never** silently
     retry the same tier and host route unchanged.
3. **Dispatch a spec-compliance reviewer** with
   [../prompts/spec-reviewer.md](../prompts/spec-reviewer.md), scoped to the implementer's
   reported task diff (this isolates the current task from earlier tasks' still-uncommitted work,
   since there is no per-task SHA to diff against). If it finds gaps, the **same implementer**
   fixes them and the reviewer re-reviews. Loop until ✅. Route its effective tier per
   [Dispatch model](#dispatch-model-resolve--map--pass) and [Tier selection](#tier-selection).
4. **Dispatch a code-quality reviewer** with
   [../prompts/quality-reviewer.md](../prompts/quality-reviewer.md) — only after spec compliance
   is ✅ — scoped to the same diff. Fix-and-re-review loop until ✅. Route its effective tier per
   [Dispatch model](#dispatch-model-resolve--map--pass) and [Tier selection](#tier-selection).
5. **Record progress after both reviews pass.** For Markdown, tick the plan's checkboxes in place.
   For Linear, return the local verification result to [controller.md](controller.md); implementers
   and reviewers write no issue content or lifecycle/evidence fields.

A reviewer finding an issue the implementer cannot resolve surfaces as **BLOCKED** → escalate to
the user. This is the blocking-stop for subagent mode; there is no `woostack-review --fast`
`REQUEST_CHANGES` gate here.
The subagent driver does not transition Linear state. Implementers and reviewers never commit,
push, submit, or merge; the controller retains those boundaries.

## Model tiers

Use woostack's shared tier vocabulary — `fast | standard | deep` — resolved through the shared
Model Tiers table in
[`../../using-woostack/references/model-tiers.md`](../../using-woostack/references/model-tiers.md).
Each prompt template declares its `tier:` in frontmatter as the role default.

### Tier selection

Each role has a **default** tier (its prompt's `tier:` frontmatter): implementer `fast`,
spec-reviewer `standard`, quality-reviewer `deep`. The controller adjusts tiers **per role and
task** from complexity and risk — this table is the single home for the choice:

| Adjust | Effective tier | When |
|---|---|---|
| **Implementation escalate** | `standard` | the task touches security / auth / crypto, data migrations, concurrency / locking, money / billing, or is cross-cutting / architectural; the task spec is highly ambiguous; or a `fast` attempt returned **BLOCKED** specifically because it needs more reasoning. |
| **Implementation ceiling** | never `deep` | `standard` is the maximum for implementation. If it remains blocked, provide missing context, split the task, or escalate the plan to the user. |
| **Reviewer downgrade** | `fast` / `standard` | spec-reviewer → `fast` on a trivial diff; quality-reviewer → `standard` on a trivial diff (otherwise stays `deep`). |
| **No implementation escalation signal** | `fast` | favor the implementer default; use `standard` only when a signal above establishes the need. |

### Dispatch model (resolve → map → pass)

Before each subagent dispatch, resolve the task's **effective tier** (role default, adjusted per
[Tier selection](#tier-selection) above), then apply the current host's routing class. On a host
that consumes repository model configuration, resolve the tier through the shared
[model-tiers.md](../../using-woostack/references/model-tiers.md) provider table and configured
overrides, then pass the resolved values in the form its spawn API accepts. On a host with
host-owned role routing, map the effective tier to the fixed role-backed built-in worker named by
the host file and do not resolve or read repository model leaves. The effective tier remains the
single portable input; the host file owns how it is enacted.

**When the host supports explicit per-call model routing, every dispatch MUST pass the tier's
resolved values.** Omitting them makes the subagent inherit the parent session's settings,
silently defeating tier routing and burning multiples of the tokens on cheap work — the same
rationale `woostack-review`'s
[`prompts/anthropic.md`](../../woostack-review/prompts/anthropic.md) already states for its angle
spawns. **Host-owned role routing is also non-degraded:** select the mapped built-in worker and let
the host own its concrete model, role configuration, and fallback. **When the host offers neither
capability**, run at the session model and **say so** (degraded, not equivalent) — never pretend a
tier ran.

**Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded).

The host file answers the capability questions this doctrine needs: the spawn primitive and its
per-call model/effort/cwd knobs, the tier-routing class (host-owned role routing is **not**
degraded), and the host-level fallback posture. A host-applied **temporary** model fallback on a
usage-limit error is host-owned recovery, not the silent tier claim this doctrine forbids — the
driver has no re-report obligation.

## Review

Subagent mode's automated review **is** the per-task spec + quality loops above — it does **not**
run `woostack-review --fast` (that would double-review the same code). Each increment PR is
reviewed **manually by the human** after execution, which covers whole-increment integration.

## Hand back

When every task in the increment is ✅ and checked off, hand back to [SKILL.md](../SKILL.md) for
the single `woostack-commit` and distillation. **Never-merge carve-out:** this driver does
**not** call any branch-finishing or merge step and never offers or performs a merge.
