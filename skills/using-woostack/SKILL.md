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
5. Load and apply the shared
   [Output Discipline](references/output-discipline.md) to every user-facing reply. It keeps
   the answer compact without compressing evidence, risk, or required contract fields.
6. At an ordinary final-reply boundary, apply [woostack-reflect](../woostack-reflect/SKILL.md)'s
   canonical candidate gate before loading or invoking it: the session already contains a concrete
   observed preventable instruction gap that could yield a durable instruction finding. If no
   candidate is admitted, emit no reflection headings. An explicit `/woostack-reflect` invocation
   always runs exactly once.

Do not run `/woostack-init`, create `.woostack/`, scaffold code, or add config unless the
user explicitly asks for that behavior or the loaded task-specific skill requires it as part
of an approved workflow.

**Artifact invariant:** The canonical persistent product record for builds and, after root-cause
proof, project-backed fixes is local in `.woostack/tmp/runs/<run-id>/`. Provider mirroring (Linear)
is an optional mirror flow gated by `linear.saveArtifacts: true` (default `false`). Each workflow uses
one exact run store under `.woostack/tmp/runs/<run-id>/`, owner-only `0700`/`0600` permissions, monotonic
revision compare-and-swap updates, raw UTF-8 SHA-256 local receipts, and two exact responsible-user
approval events.

Gated Ideate, Harden, and Build/Fix-delegated Plan work uses the permission-restricted local run
manifest and performs zero intermediate provider cycles. Each approval presentation streams the complete
exact local content and identity (or a verified same-process byte-complete revision diff with old/new
identities), immediately followed by a body-free `Accept`/`Abandon` Ask; approval records the local receipt,
and optional provider mirroring synchronizes to Linear in one bounded cycle after local approval. After
gate 2, Build/Fix display the verified project handoff and ask `Stop here`, `Execute`, or `Abandon`;
Execute is separately invoked or dispatched only for the selected choice. Standalone Plan keeps its
direct synchronization unchanged. Follow the
[`Local run artifact and provider mirror contract`](../woostack-init/references/artifact-backends.md#run-scoped-gated-draft-manifest)
for the detailed contract.

Linear assignment, status, labels, content, or an unreceipted response never authorizes work, and
development artifacts never replace direct Git/Graphite/GitHub source-control evidence. Other workflows
remain artifact-optional. `/woostack-init` may make authenticated read-only setup calls through the
official Linear MCP to validate non-secret defaults; it cannot select persistence, read development
artifact content, or write. `woostack-change` never contacts Linear. Explicit Build or
project-backed Fix abandonment retains all local run artifacts in `.woostack/tmp/runs/<run-id>/` and,
when optional mirroring is enabled, closes the exact project through configured canceled status/read-back;
source issues are preserved. Handoff, replanning, and blockers leave project status unchanged.

## Command Routing

| Request | Load |
|---|---|
| `/woostack-init [path] [--migrate-legacy]`, initialize or repair the `.woostack/` workspace, or explicitly migrate tracked legacy development records | `woostack-init` |
| `/woostack-bootstrap <goal>`, scaffold a new web/mobile/API project | `woostack-bootstrap` |
| `/woostack-build <goal> [--project <exact Linear URL-or-UUID>]`, prepare one canonical project through two exact Linear revision approvals, then hand off with `Stop here`, `Execute`, or `Abandon` | `woostack-build` |
| `/woostack-fix <prompt> [--project <exact Linear URL-or-UUID>] [--issue <exact canonical Linear issue reference>] [--inline\|--subagent]`, diagnose a free-form defect, resolve/create its project and direct-issue plan after root-cause proof, then hand off with `Stop here`, `Execute`, or `Abandon` after both approvals | `woostack-fix` |
| `/woostack-change <goal>`, implement a small bounded non-bug enhancement or refactor directly in one isolated worktree and one reviewable PR | `woostack-change` |
| `/woostack-plan <approved specification> [--project <exact Linear URL-or-UUID>]`, produce a PR-sized dependency-aware direct-issue plan; standalone persistence is optional | `woostack-plan` |
| `/woostack-execute <approved plan-or-task> [--project <exact Linear URL-or-UUID>] [--issue <exact canonical Linear issue reference>] [--inline\|--subagent]`, execute approved work from fresh exact Linear project/graph/receipt reads and Git/Graphite/GitHub ancestry evidence; fix/build origins require their exact approval records | `woostack-execute` |
| `/woostack-execute-overnight <approved plan> [--project <exact Linear URL-or-UUID>] [--inline\|--subagent]`, execute unattended; build origin requires its exact approved project graph | `woostack-execute-overnight` |
| `/woostack-sweep [PR#|branch] [--base R]`, drive one Graphite stack bottom-up: address pre-existing threads, run one multi-angle review per current head, address new findings, restack affected descendants, and halt unchanged recurring blockers | `woostack-sweep` |
| `/woostack-commit [--issue <exact canonical Linear issue reference>]`, commit session-relevant changes and update PR fields; artifact synchronization is optional | `woostack-commit` |
| `/woostack-review <PR#>`, review one exact existing PR through one detected multi-angle swarm and one evidence adjudicator, then post one batched native GitHub Review; report-only, never edits or merges | `woostack-review` |
| `/woostack-audit <target> [--all] [--simplify\|--prod-only]`, audit standing code (a file/dir/repo at rest) for simplification + production-readiness, report-only | `woostack-audit` |
| `/woostack-qa <url> [focus…] [--stop-first]`, exploratory-QA a running app in a real browser, report-only findings under `.woostack/qa/` | `woostack-qa` |
| `/woostack-eval <skill-path> [--behavior\|--triggers\|--all] [--runs <1..10>] [--baseline-ref <git-ref>\|--baseline-path <skill-dir>]`, evaluate an approved skill corpus without editing the target skill | `woostack-eval` |
| `/woostack-reflect`, review the current active conversation through this invocation for concrete durable instruction suggestions; report-only initially and never recursive | `woostack-reflect` |
| `/woostack-address-comments <PR#>`, address every unresolved thread on one exact existing PR with the smallest in-contract fix or evidence-backed pushback, verified replies, and resolution reads | `woostack-address-comments` |
| `/woostack-status [branch|PR#|exact Linear project URL-or-UUID|exact canonical Linear issue reference]`, show the read-only repository-derived work board | `woostack-status` |
| `/woostack-visualize <source> [for <audience>]`, render a source as audience-tailored HTML | `woostack-visualize` |
| `/woostack-debug <target>`, run an autonomous root-cause analysis before fixing (investigative only — hands back the root cause and a proposed fix) | `woostack-debug` |
| `/woostack-tdd <target> [--issue <exact canonical Linear issue reference>]`, add appropriate tests to a bounded code/PR target with optional artifact context (gate-light; TDD doctrine home) | `woostack-tdd` |
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
| "I'll infer an existing Linear artifact from the branch." | Never fuzzy-match artifacts. Use an exact caller-supplied resource or an explicitly requested creation with a retained stable identity. |

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
