# Product

<!-- impeccable:product-schema 1 -->

## Users

People using AI coding assistants to plan work and change code.
Users make product decisions and authorize work.

## Product Purpose

WooStack brings together a recommended tech stack, skills for coding agents, and an autonomous
agent setup in development. The skills guide assistants to inspect repository evidence and verify
outcomes. The stack and skills can be adopted independently; neither requires the autonomous setup.
The [README](README.md) owns the project overview and skill installation instructions.

## Capabilities and Constraints

Current scope:

- Repository-specific project guidance and greenfield planning without a checkout.
- Requirements exploration, specification review, planning, and requested issue publication.
- Bounded implementation including initial project creation, multi-task coordination, and
  pull-request delivery without merging. Local-only creation needs no GitHub destination.
- Diagnosis, browser QA, review-comment handling, and conversation reflection.
- UI design coordinated through selected external skills, plus layout of existing screen flows.
- Project-owned design catalogs adapted to existing UI and design rules, with bounded local
  creation, read-only inspection, and explicitly scoped maintenance.
- A documentation site with authored guides and references generated from skill sources.
- A standalone component catalog for inspecting components, tokens, and examples.
- An optional Pi subagent UI for fleet inspection, transcripts, steering, and confirmed stops,
  backed by the separately installed pi-subagents runtime.

Every skill is independently installable and owns its own activation, workflow, and approval
boundaries. The [command router](skills/using-woostack/SKILL.md#command-routing) is an optional
command index and adoption aid; reusable procedures are shared through locally bundled references
maintained from one canonical source. No sibling Woostack workflow is required.
[Design](skills/woostack-design/SKILL.md#selected-skills) requires its selected external skills;
installation and execution remain subject to its dependency and permission boundaries.

The implemented repository contains the skills collection, stack documentation, two supporting
applications, and an optional host-specific UI extension. The autonomous setup remains in development, with installation and configuration
not yet documented. This repository is not a place to scaffold unrelated products.
Application source is confined to `apps/docs/` and
`apps/design/`; host extensions live in `packages/`, and supporting skill assets live with their
owning skills. The [Pi UI](packages/pi-subagents-ui/README.md) does not implement delegation,
worktree management, or Orchestrate policy and is not a prerequisite of any skill.
A pnpm workspace and Turborepo coordinate the apps and extension with a shared root lockfile,
while each package owns its dependencies.
Plans, issues, status boards, and reports do not authorize additional work or prove delivery.
Merging remains a human decision.

See [AGENTS.md](AGENTS.md) for repository boundaries and verification, and
[DESIGN.md](DESIGN.md) for interaction and source-ownership principles.
