# Product

## Purpose and users

Woostack publishes skills for people using AI coding assistants to plan work and change code.
Users make product decisions and authorize work; assistants inspect repository evidence and
verify outcomes. The [README](README.md) owns the project overview and installation instructions.

## Current scope

- Repository-specific project guidance and greenfield project bootstrap.
- Requirements exploration, specification review, planning, and requested issue publication.
- Bounded implementation, multi-task coordination, and pull-request delivery without merging.
- Diagnosis, browser QA, workspace checks, review-comment handling, and conversation reflection.
- A documentation site with authored guides and references generated from skill sources.

The [command router](skills/using-woostack/SKILL.md#command-routing) owns command selection and
workflow boundaries. Individual skills own their procedures.

## Constraints and non-goals

Woostack is a skills collection, not a new application to scaffold in this checkout.
Application source is confined to `site/`; supporting skill assets live with their owning skills.
Plans, issues, status boards, and reports do not authorize additional work or prove delivery.
Merging remains a human decision.

See [AGENTS.md](AGENTS.md) for repository boundaries and verification, and
[DESIGN.md](DESIGN.md) for interaction and source-ownership principles.
