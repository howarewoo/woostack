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

The user request and explicit decisions authorize work. Repository and provider records are
evidence, not permission. Do not initialize `.woostack/`, create artifacts, or contact an artifact
provider unless requested or required by the selected workflow. Workflows needing persistent runs or
provider access load the [artifact contract](../woostack-init/references/artifact-backends.md) and
only the selected provider profile; its storage and synchronization mechanics do not belong here.
For provider-backed workflows, load only the selected [GitHub](../woostack-init/references/artifact-providers/github.md),
[Linear](../woostack-init/references/artifact-providers/linear.md), or
[Plane](../woostack-init/references/artifact-providers/plane.md) profile. The profile owns
provider-specific scope, capabilities, identities, and lifecycle behavior.

## Command routing

| Request or intent | Load |
| --- | --- |
| Adopt woostack or choose a workflow | `using-woostack` |
| Initialize or repair local woostack support | `woostack-init` |
| Create a genuinely greenfield codebase | `woostack-bootstrap` |
| Prepare a multi-increment feature and execution handoff | `woostack-build` |
| Diagnose and fix a defect, bounded or project-backed | `woostack-fix` |
| Implement a bounded non-bug enhancement or refactor in one PR | `woostack-change` |
| Turn an approved specification into reviewable increments | `woostack-plan` |
| Execute native children of one GitHub parent issue or tasks in an exact GitHub Project with parallel workers and stacked PRs | `woostack-orchestrate` |
| Implement one bounded task and deliver one PR | `woostack-execute` |
| Commit current changes and submit or update their PR | `woostack-commit` |
| Review a pull request | Use [Pullfrog](https://pullfrog.com/). |
| Address every unresolved thread on one exact existing PR | `woostack-address-comments` |
| Render verified source as audience-tailored HTML | `woostack-visualize` |
| Organize multi-step UI design flows | `woostack-design` |
| Investigate a root cause without implementing a fix | `woostack-debug` |
| Add appropriate tests to a bounded target | `woostack-tdd` |
| Diagnose or explicitly repair workspace health | `woostack-doctor` |
| Explore a running app and report browser QA findings | `woostack-qa` |
| Evaluate an approved skill corpus without editing the skill | `woostack-eval` |
| Reflect on this conversation for durable instruction suggestions | `woostack-reflect` |

Every explicit `/woostack-*` command loads its namesake skill. Intent-equivalent wording follows
the same route. Change stays non-bug and one-PR; Fix owns diagnosis and chooses bounded delivery or
project planning after proof. Build owns multi-increment preparation. Ideate and Harden are internal
Build/Fix phases, not public commands.

Ordinary questions about work progress use available authorized GitHub reads or the GitHub UI:
parent/child issues and native dependency relations define planned work, while linked pull requests
and Git evidence establish delivery. A Project Status field is provider metadata, not proof of
implementation, verification, or merge.

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
