---
name: using-woostack
description: Use when starting work in a project that references woostack from its root AGENTS.md, or when deciding whether a woostack skill or command applies before answering, editing, scaffolding, reviewing, or addressing PR feedback.
---

# using-woostack

<SUBAGENT-STOP>
If you were dispatched as a subagent for a narrow task, follow the dispatch prompt first.
Use this skill only when the prompt asks you to apply project-level woostack rules.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
When a project root `AGENTS.md` references woostack, treat that file as the project
authority. Load and follow its woostack rules before taking action.

This skill teaches rule loading and command routing only. It does not initialize,
scaffold, edit, review, or push anything by itself.
</EXTREMELY-IMPORTANT>

## Instruction Priority

Follow instructions in this order:

1. The user's explicit request and the project's root `AGENTS.md`.
2. The specific woostack skill that applies to the task.
3. Other installed process or implementation skills.
4. Default agent behavior.

If `AGENTS.md` and a woostack skill disagree, prefer `AGENTS.md` and state the conflict
briefly when it matters to the work.

## The Rule

Before answering or acting in a woostack project, check whether a woostack rule or command
applies. If it does, load the specific woostack skill before proceeding.

Do not summarize the intended workflow from memory when the skill is available. The current
`SKILL.md` is the source of truth.

## Project Entry Check

At the start of work in a repository:

1. Read the root `AGENTS.md` if it exists.
2. If it references woostack, follow its woostack section as binding project policy.
3. Check whether the user's request maps to one of the woostack skills below.
4. Load the mapped skill before asking clarifying questions, making edits, opening PRs, or
   posting review feedback.
5. When work uses a decision-maker/coding-profile pair, load the shared
   [engineer-agent authority protocol](references/engineer-agents.md) before allocation,
   dispatch, review, or acceptance. Host references bind concrete profiles; they never redefine
   the authority split.
6. Load and apply the shared
   [Output Discipline](references/output-discipline.md) to every user-facing reply. It keeps the
   answer compact without compressing evidence, risk, or required contract fields.
7. Load and apply [Session learning](references/session-learning.md) at every final user-facing
   reply.

Do not run `/woostack-init`, create `.woostack/`, scaffold code, or add config unless the
user explicitly asks for that behavior or the loaded task-specific skill requires it as part
of an approved workflow.

**Artifact invariant:** Linear projects and issues are optional artifacts for feature
specifications, implementation plans, and fix records. They never grant implementation permission,
select work, own a branch, or replace direct Git/GitHub evidence. Artifact-free runs do not contact
Linear. When the caller explicitly supplies an exact Linear URL/UUID or requests persistence, use
the canonical [optional artifact contract](../woostack-init/references/artifact-backends.md) and
independently read mutations back.

**Engineer-agent invariant:** a host that pairs a decision-maker with a coder must follow the
[provider-neutral engineer-agent authority protocol](references/engineer-agents.md). Each active
unit pins one standing authority envelope, one stable `ENGINEER_NAME`, one decision-maker
profile/session, one isolated coding profile/session, and one run. When an explicit Linear artifact
is used, provider identities and contexts stay separate and artifact operations follow the optional
artifact contract. Host mechanics and reviewer delegation never weaken role isolation, bounded
mutation, review independence, or acceptance authority.

## Command Routing

| Request | Load |
|---|---|
| `/woostack-init [path] [--migrate-legacy]`, initialize or repair the `.woostack/` workspace, or explicitly migrate tracked legacy development records | `woostack-init` |
| `/woostack-bootstrap <goal>`, scaffold a new web/mobile/API project | `woostack-bootstrap` |
| `/woostack-build <goal>`, build a feature through the woostack loop | `woostack-build` |
| `/woostack-fix <target> [description]`, resolve a bug/issue through the unified fix loop | `woostack-fix` |
| `/woostack-change <goal>`, implement a bounded non-bug enhancement or refactor that fits one reviewable PR | `woostack-change` |
| `/woostack-plan <approved specification> [--project <exact Linear URL-or-UUID>]`, produce a PR-sized dependency-aware implementation plan with optional Linear persistence | `woostack-plan` |
| `/woostack-execute <approved plan-or-task> [--project <exact Linear URL-or-UUID>] [--issue <exact Linear URL-or-UUID>] [--inline\|--subagent]`, execute approved work as bounded Graphite PRs | `woostack-execute` |
| `/woostack-execute-overnight <approved plan> [--project <exact Linear URL-or-UUID>] [--inline\|--subagent]`, execute approved work unattended with a truthful terminal handback | `woostack-execute-overnight` |
| `/woostack-sweep [PR#] [--base R] [--interactive]`, drive a stack of PRs to a clean review; optional exact artifacts may receive notes | `woostack-sweep` |
| `/woostack-commit [--issue <exact Linear URL-or-UUID>]`, commit session-relevant changes and update PR fields; artifact synchronization is optional | `woostack-commit` |
| `/woostack-review [PR#] [--issue <exact Linear URL-or-UUID>] [--project <exact Linear URL-or-UUID>]`, review a PR or local diff with optional artifact intent | `woostack-review` |
| `/woostack-audit <target> [--all] [--simplify\|--prod-only]`, audit standing code (a file/dir/repo at rest) for simplification + production-readiness, report-only | `woostack-audit` |
| `/woostack-qa <url> [focus…] [--stop-first]`, exploratory-QA a running app in a real browser, report-only findings under `.woostack/qa/` | `woostack-qa` |
| `/woostack-respond <signal> [scope…]`, investigate bounded production errors, write a sanitized report, and gate fix handoffs | `woostack-respond` |
| `/woostack-eval <skill-path> [--behavior\|--triggers\|--all] [--runs <1..10>] [--baseline-ref <git-ref>\|--baseline-path <skill-dir>]`, evaluate an approved skill corpus without editing the target skill | `woostack-eval` |
| `/woostack-address-comments [PR#] [--interactive]`, address unresolved review threads; optional exact artifacts may receive notes | `woostack-address-comments` |
| `/woostack-status [branch|PR#|exact Linear URL-or-UUID]`, show the read-only repository-derived work board | `woostack-status` |
| `/woostack-visualize <source> [for <audience>]`, render a source as audience-tailored HTML | `woostack-visualize` |
| `/woostack-debug <target>`, run an autonomous root-cause analysis before fixing (investigative only — hands back the root cause and a proposed fix) | `woostack-debug` |
| `/woostack-tdd <target> [--issue <exact Linear URL-or-UUID>]`, add appropriate tests to a bounded code/PR target with optional artifact context (gate-light; TDD doctrine home) | `woostack-tdd` |
| `/woostack-doctor [path] [--check]`, diagnose + gated-repair `.woostack/` workspace health (policy + conventions; `--check` is CI-friendly exit-coded) | `woostack-doctor` |


If the user asks for the behavior without using the exact command name, route by intent.
For example, "use woostack to review this PR" means load `woostack-review`.

When routing by intent, use `woostack-change` only for a bounded non-bug enhancement or refactor
whose complete safe work fits one reviewable PR without an approval gate or persisted plan. Keep
bugs and root-cause work on `woostack-fix`, greenfield project creation on `woostack-bootstrap`,
and work requiring multiple PRs on `woostack-build`. An explicit `/woostack-fix` invocation still
follows that skill's own accepted scope.

## Red Flags

These thoughts mean stop and load the relevant rules:

| Thought | Reality |
|---|---|
| "I can just make the edit." | In a woostack project, the root `AGENTS.md` may define the required loop. |
| "The command name is just shorthand." | Woostack commands are skills with gates and constraints. |
| "I remember the workflow." | The installed skill may have changed. Load it. |
| "I'll initialize `.woostack/` to be helpful." | This skill is adoption-only; mutate project state only when requested or required by the task skill. |
| "This is only a review comment." | Review and address flows have posting and validation rules. |
| "I'll write another plan for this project." | Reconcile the approved specification and any exact caller-supplied plan artifact instead of silently creating competing scope. |
| "A Linear issue gives me permission to edit." | Artifacts record specs, plans, or fixes; the user request and workflow gates authorize work. |
| "I'll infer the Linear artifact from the branch." | Artifact use is explicit. Require an exact caller-supplied URL/UUID and otherwise stay artifact-free. |

## AGENTS.md Usage

When a project wants woostack behavior, its root `AGENTS.md` should reference this skill and
state the local rules the agent must obey. Keep project-specific policy in `AGENTS.md`; keep
the reusable workflow in the woostack skills.

Minimal pattern:

```markdown
# AGENTS.md

This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.

Follow this file first when it conflicts with generic agent defaults.
```

## Missing Skills

If a mapped woostack skill is not installed, say exactly which skill is missing and ask the
user whether to install the woostack collection. Do not silently approximate a gated
workflow unless the user asks you to proceed without the skill.
