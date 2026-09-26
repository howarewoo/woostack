---
name: using-woostack
description: Use when starting work in a project that references woostack from its root AGENTS.md, or when deciding whether a woostack skill or command applies before answering, editing, scaffolding, reviewing, or addressing PR feedback.
---

# using-woostack

This skill loads project rules and routes requests. It does not initialize, scaffold, edit, review,
or push anything by itself. A dispatched worker follows its bounded task; it loads project-level
woostack rules only when the dispatch requires them.

## Project entry

1. Follow the project's root `AGENTS.md` and the user's explicit request, then the applicable
   woostack skill, other installed skills, and default agent behavior. Prefer project policy when
   it conflicts with a skill, and state a material conflict.
2. Route by intent using the table below and load the current matching `SKILL.md` before acting.
   The matching skill owns its arguments, approval boundaries, and recovery procedure.
3. Before host-dependent work, use the [host index](references/hosts/README.md) to select and load
   only the supported adapter for the active host.
4. Apply the shared [output discipline](references/output-discipline.md). At an ordinary final
  reply, load Reflect only when its [canonical candidate gate](../woostack-reflect/SKILL.md#invocation-and-snapshot-boundary)
   admits a concrete observed instruction gap; otherwise emit no reflection headings.
5. An explicit `/woostack-reflect` invocation always runs exactly once to review the current active
   conversation through this invocation; an ordinary final reply loads it only when the session
   already contains a concrete observed preventable instruction gap.

The user's request and explicit decisions authorize work. Repository and GitHub records are evidence,
not permission. Do not initialize `.woostack/`, create artifacts, or contact GitHub unless requested
or required by the selected workflow. The selected workflow loads the references its own operation
needs; routing alone loads none. Retired managed-provider data is never imported or reinterpreted.

## Command routing

| Request or intent | Load |
| --- | --- |
| Adopt woostack or choose a workflow | `using-woostack` |
| Initialize or repair local woostack support | `woostack-init` |
| Create a genuinely greenfield codebase | `woostack-bootstrap` |
| Elicit a complete user-verified specification from a goal or existing specification | `woostack-ideate` |
| Reconcile a supplied specification or candidate issue plan against repository evidence | `woostack-harden` |
| Prepare a feature or proved defect for a verified GitHub issue graph without implementation | `woostack-prepare` |
| Turn an approved specification into reviewable increments and publish the selected GitHub issue graph | `woostack-plan` |
| Interpret understandable multi-task work, resolve executable tasks and dependencies, and schedule verified bounded work | `woostack-orchestrate` |
| Implement one bounded task — enhancement, refactor, test-only work, or authorized understood correction — and deliver one PR | `woostack-execute` |
| Commit current changes and submit or update their PR | `woostack-commit` |
| Review a pull request | Use [Pullfrog](https://pullfrog.com/). |
| Address every unresolved thread on one exact existing PR | `woostack-address-comments` |
| Render verified source as audience-tailored HTML | `woostack-visualize` |
| Organize multi-step UI design flows | `woostack-design` |
| Investigate a root cause without implementing a fix | `woostack-debug` |
| Diagnose or explicitly repair workspace health | `woostack-doctor` |
| Explore a running app and report browser QA findings | `woostack-qa` |
| Reflect on this conversation for durable instruction suggestions | `woostack-reflect` |

`woostack-build`, `woostack-fix`, `woostack-change`, `woostack-status`, and
`woostack-tdd` are retired, not missing installations, and have no aliases. Do not invoke them.
For old Build/Fix planning inputs, explain Prepare's retained-input boundary rather than loading or
reinstalling a retired wrapper. Route bounded enhancements, corrections, or test-only work to
Execute; unresolved scope belongs in the public planning phases.

Every supported explicit `/woostack-*` command loads its namesake skill. Intent-equivalent wording follows
the same route. Ideate and Harden are public, directly callable phases that exchange complete plain
packets. Prepare composes Debug for defects, Ideate, Harden, and Plan as needed and ends at a fully
read-back GitHub issue graph; it never implements, creates source branches, dispatches workers, or
invokes Execute or Orchestrate. Plan is the sole issue publisher. Execute is the explicit bounded
implementation and draft-PR path, including proven corrections and test-only tasks under its
[testing guidance](../woostack-execute/references/tdd.md). Unknown defects require Debug's causal
proof before correction. Planning phases never edit source, commit, submit a PR, or grant merge authority.

An exact task-bearing GitHub issue URL alone, or `/woostack-execute --issue <url>`, routes to
Execute: it reads the selected issue and resolves one bounded task before implementation. Inline
task instructions remain valid with or without an issue association. For work that spans multiple
tasks, Orchestrate interprets the available conversation, repository, and GitHub context and owns
its own resolution, dependency, and recovery procedure; the router does not restate it. Issue,
issue-list, and Project arguments are convenience interpretation hints, not exhaustive admission
types. A Project is included only when explicitly selected; its status lifecycle is used only when
that selection requests status mutation.

Ordinary questions about work progress use available authorized GitHub reads or the GitHub UI:
issues, native relationships when present, and linked pull requests and Git evidence describe planned
work and delivery. A Project Status field is provider metadata, not proof of implementation,
verification, or merge.

## AGENTS.md usage

Keep project policy in `AGENTS.md` and reusable workflow details in their owning skills:

```markdown
This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.

Follow this file first when it conflicts with generic agent defaults.
```

## Missing skills

Name the missing skill and ask whether to install the collection. Do not approximate a gated
workflow unless the user explicitly asks to proceed without that skill.
