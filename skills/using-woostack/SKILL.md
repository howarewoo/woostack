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
7. If the request maps to **no** woostack command but you will still answer or edit from the
   project's accumulated knowledge, **recall first** (read-only). Load the scoped
   `.woostack/memory/` notes for your working set via the procedure in
   [`memory.md`](../woostack-init/references/memory.md) — script-assisted when the
   `woostack-init` scripts are present, the manual fallback otherwise, skipped when
   `.woostack/memory/` is absent. For a read-only question prefer
   [`/woostack-ask`](../woostack-ask/SKILL.md), which owns this recall. Recall never writes —
   distillation and curation stay owned by `woostack-execute`, `woostack-address-comments`,
   and `woostack-dream`.

Do not run `/woostack-init`, create `.woostack/`, scaffold code, or add config unless the
user explicitly asks for that behavior or the loaded task-specific skill requires it as part
of an approved workflow.

**Development-record invariant:** official host-exposed Linear MCP is the only development-record
interface. The canonical Linear MCP
[managed-resource and event schemas](../woostack-init/references/artifact-backends.md#versioned-managed-metadata)
and [issue-event actor/receipt schemas](../woostack-init/references/artifact-backends.md#canonical-issue-event-dispatch-and-pre-commit-evidence)
own managed identity, exact payloads and relations, type-aware ownership, and PR attribution. The
[issue-state/current-event conventions](../woostack-status/references/conventions.md#issue-state-and-events)
own lifecycle derivation and terminal reconciliation. Link those authorities; never replace them
with local specification/plan/fix records, Linear documents, repository credentials, custom
provider transports, or duplicated lifecycle/receipt schemas.

**Engineer-agent invariant:** a host that pairs a decision-maker with a coder must follow the
[provider-neutral engineer-agent authority protocol](references/engineer-agents.md). Each active
unit pins one standing authority envelope, one stable `ENGINEER_NAME`, one Linear principal, one
decision-maker profile/session, one isolated coding profile/session, and one run. The two profiles
resolve their unit principal only through separate host secret/token/session contexts; concurrent
units share none of those identities or contexts. A freshly resolved project lead or standalone
dispatcher deliberately allocates work, the current type-aware owner records and independently
reads back `assignmentAccepted` before work, and the decision-maker rechecks owner, state, and
relations before each side effect. Host mechanics and reviewer delegation never weaken role
isolation, bounded mutation, review independence, or acceptance authority.

## Command Routing

| Request | Load |
|---|---|
| `/woostack-init [path] [--migrate-legacy]`, initialize or repair the `.woostack/` workspace, or explicitly migrate tracked legacy development records | `woostack-init` |
| `/woostack-bootstrap <goal>`, scaffold a new web/mobile/API project | `woostack-bootstrap` |
| `/woostack-build <goal>`, build a feature through the woostack loop | `woostack-build` |
| `/woostack-fix <target> [description]`, resolve a bug/issue through the unified fix loop | `woostack-fix` |
| `/woostack-change <goal>`, implement a bounded non-bug enhancement or refactor that fits one reviewable PR | `woostack-change` |
| `/woostack-plan <Linear project UUID-or-exact-URL>`, reconcile an approved feature project's PR-sized increment issue graph | `woostack-plan` |
| `/woostack-execute <Linear project UUID-or-exact-URL> [--issue <increment UUID-or-exact-URL>] [--inline\|--subagent]`, or `/woostack-execute <standalone issue UUID-or-exact-URL> [--inline\|--subagent]`, execute verified assigned Linear work as an issue-scoped Graphite PR | `woostack-execute` |
| `/woostack-execute-overnight <Linear project UUID-or-exact-URL> [--inline\|--subagent]`, execute a verified feature project unattended (autonomous, terminal handback) | `woostack-execute-overnight` |
| `/woostack-sweep [PR#] [--base R] [--interactive]`, drive a stack of PRs to a clean review | `woostack-sweep` |
| `/woostack-commit`, commit session-relevant changes and update PR fields | `woostack-commit` |
| `/woostack-review [PR#]`, review a PR or local diff | `woostack-review` |
| `/woostack-audit <target> [--all] [--simplify\|--prod-only]`, audit standing code (a file/dir/repo at rest) for simplification + production-readiness, report-only | `woostack-audit` |
| `/woostack-qa <url> [focus…] [--stop-first]`, exploratory-QA a running app in a real browser, report-only findings under `.woostack/qa/` | `woostack-qa` |
| `/woostack-respond <signal> [scope…]`, investigate bounded production errors, write a sanitized report, and gate fix handoffs | `woostack-respond` |
| `/woostack-eval <skill-path> [--behavior\|--triggers\|--all] [--runs <1..10>] [--baseline-ref <git-ref>\|--baseline-path <skill-dir>]`, evaluate an approved skill corpus without editing the target skill | `woostack-eval` |
| `/woostack-address-comments [PR#]`, address unresolved review threads | `woostack-address-comments` |
| `/woostack-status [--all] [--fetch]`, show the derived feature board (what's in flight, what to do next) | `woostack-status` |
| `/woostack-visualize <source> [for <audience>]`, render a source as audience-tailored HTML | `woostack-visualize` |
| `/woostack-debug <target>`, run an autonomous root-cause analysis before fixing (investigative only — hands back the root cause and a proposed fix) | `woostack-debug` |
| `/woostack-tdd <target>`, add appropriate tests to code, a PR, or an exact verified Linear project and issue (gate-light; TDD doctrine home) | `woostack-tdd` |
| `/woostack-dream [instructions]`, curate the memory store and recommend doc updates (gated) | `woostack-dream` |
| `/woostack-doctor [path] [--check]`, diagnose + gated-repair `.woostack/` workspace health (store integrity + conventions; `--check` is CI-friendly exit-coded) | `woostack-doctor` |


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
| "This is only a review comment." | Review and address flows have posting, validation, and memory rules. |
| "I'll write another plan for this project." | One verified Linear feature project owns one managed increment issue graph. Reconcile the existing graph by stable identity instead of creating another authority. |
| "I'll just set lifecycle state from prose." | The workflow derives lifecycle from verified typed Linear events and native state, then independently reads every mutation back. |
| "I'll identify the work by a local spec or plan." | Development work is selected only by an exact, ownership-verified Linear project or issue identity; local knowledge never becomes scope or lifecycle authority. |
| "I'll answer straight from the `.woostack/` store." | Recall the scoped memory for your working set first (read-only) per [`memory.md`](../woostack-init/references/memory.md); for a read-only question use `/woostack-ask`. |

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
