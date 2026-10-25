# Product

<!-- impeccable:product-schema 1 -->

## Users

People using AI coding assistants to plan work and change code.
Users make product decisions and authorize work.

## Product Purpose

Woostack publishes skills that guide assistants to inspect repository evidence
and verify outcomes. The [README](README.md) owns the project overview and
installation instructions.

## Capabilities and Constraints

Current scope:

- Repository-specific project guidance and greenfield planning without a checkout.
- Requirements exploration, specification review, planning, and requested issue publication.
- Bounded implementation including initial project creation, multi-task coordination, and
  pull-request delivery without merging. Local-only creation needs no GitHub destination.
- Diagnosis, browser QA, workspace checks, review-comment handling, and conversation reflection.
- UI design coordinated through selected external skills, plus layout of existing screen flows.
- Project-owned design catalogs adapted to existing UI and design rules, with bounded local
  creation, read-only inspection, and explicitly scoped maintenance.
- A documentation site with authored guides and references generated from skill sources.
- A standalone component catalog for inspecting components, tokens, and examples.

Every skill is independently installable and owns its own activation, workflow, and approval
boundaries. The [command router](skills/using-woostack/SKILL.md#command-routing) is an optional
command index and adoption aid; reusable procedures are shared through locally bundled references
maintained from one canonical source. No sibling Woostack workflow is required.
[Design](skills/woostack-design/SKILL.md#selected-skills) requires its selected external skills;
installation and execution remain subject to its dependency and permission boundaries.

Woostack is a skills collection with two supporting applications, not a place to scaffold
unrelated products. Application source is confined to `apps/docs/` and
`apps/design/`; supporting skill assets live with their owning skills.
A pnpm workspace and Turborepo coordinate the apps with a shared root lockfile,
while each app owns its dependencies.
Plans, issues, status boards, and reports do not authorize additional work or prove delivery.
Merging remains a human decision.

See [AGENTS.md](AGENTS.md) for repository boundaries and verification, and
[DESIGN.md](DESIGN.md) for interaction and source-ownership principles.
