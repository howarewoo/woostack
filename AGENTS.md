# AGENTS.md

This repository follows woostack. At the start of work, use
[`using-woostack`](skills/using-woostack/SKILL.md) to load repo rules and route
`/woostack-*` requests to the matching skill.

Follow this file first when it conflicts with generic agent defaults. `.claude/CLAUDE.md`
is a symlink to this file, so this is the single source of truth.

## What this repo is

This is a published collection of skills, not an application codebase. It packages
decisions for building new web, mobile, and API projects so agents can install it with
`npx skills add howarewoo/woostack`.

The public command/adoption surface has thirteen skills:

- [`using-woostack`](skills/using-woostack/SKILL.md)
- [`woostack-init`](skills/woostack-init/SKILL.md)
- [`woostack-bootstrap`](skills/woostack-bootstrap/SKILL.md)
- [`woostack-build`](skills/woostack-build/SKILL.md)
- [`woostack-plan`](skills/woostack-plan/SKILL.md)
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
- [`woostack-execute-overnight`](skills/woostack-execute-overnight/SKILL.md)
- [`woostack-commit`](skills/woostack-commit/SKILL.md)
- [`woostack-review`](skills/woostack-review/SKILL.md)
- [`woostack-address-comments`](skills/woostack-address-comments/SKILL.md)
- [`woostack-status`](skills/woostack-status/SKILL.md)
- [`woostack-visualize`](skills/woostack-visualize/SKILL.md)
- [`woostack-debug`](skills/woostack-debug/SKILL.md)

The collection also installs two internal sub-skills:
[`woostack-ideate`](skills/woostack-ideate/SKILL.md) and
[`woostack-harden`](skills/woostack-harden/SKILL.md). `woostack-build` delegates its ideate
phase to the former and its harden phase to the latter. Both are bundled building blocks, not
`/woostack-*` commands: they have no routing row and are absent from the thirteen-skill command
surface above. Like [`action.yml`](action.yml), they are shipped assets — do not delete them as
strays.

There is no application source code, app lockfile, build, or CI for this repo's own
push/PR events. `skills-lock.json` is the dev-skill manifest and is currently empty.

The exception is consumer-facing review delivery: [`action.yml`](action.yml) and
[`.github/workflows/reusable-review.yml`](.github/workflows/reusable-review.yml) ship from
this repo so consumers can run `woostack-review` in their own CI. They are shipped assets,
not self-CI, and should not be deleted as stray workflows.

## Modes

Identify the mode before acting.

**Mode A: edit this skill collection.** Use this when updating skill Markdown, reference
docs, HTML templates, review scripts, prompts, or JSON config. Keep edits in skill assets;
do not add application code, app build configs, or app lockfiles.

**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-build`, `/woostack-plan`, `/woostack-execute`, `/woostack-execute-overnight`, `/woostack-commit`,
`/woostack-review`, `/woostack-address-comments`, `/woostack-status`, `/woostack-visualize`, or
`/woostack-debug`, including intent-equivalent wording. Load the matching skill
before acting. For bootstrap work, the output belongs in a fresh repo in a different
directory, not in this repo.

## Hard constraints

- No fabricated versions. When a skill or generated project needs a version, resolve it
  live with `npm view <pkg> version` or an equivalent registry command.
- No hidden tools. Do not invent CI, app tests, package scripts, or app build steps for this
  repo.
- Respect branch protection. `main` is protected and requires PRs; never force-push to
  `main`.
- Use Graphite for source control when mutating history or opening/updating PRs. Prefer
  `gt create`, `gt modify`, `gt sync`, `gt submit`, `gt track`, and `gt log`; use raw `git`
  for read-only inspection and low-level fallback.
- Cross-link, do not duplicate. If a fact belongs in a reference file, link to it from
  related docs instead of restating it.
- Reference frameworks by name, not version, except in
  [`frameworks.md`](skills/woostack-bootstrap/references/frameworks.md) when an
  incompatibility forces an exact version.
- Keep `SKILL.md` descriptions accurate and concise. The description drives discovery; the
  workflow belongs in referenced docs.
- Do not move or rename any of the fifteen `SKILL.md` files (the thirteen public command/adoption
  skills plus the internal `woostack-ideate` and `woostack-harden`).
- Do not rename files under
  [`skills/woostack-bootstrap/references/`](skills/woostack-bootstrap/references/) without
  updating every cross-link and the bootstrap skill table.
- Do not commit `.env*`, secrets, generated app files, or personal compressed prose.

## Quick file map

- Project adoption and command routing:
  [`skills/using-woostack/SKILL.md`](skills/using-woostack/SKILL.md)
- Bootstrap decisions, architecture, frameworks, infrastructure, patterns, development, and
  procedure:
  [`skills/woostack-bootstrap/references/`](skills/woostack-bootstrap/references/)
- Build loop:
  [`skills/woostack-build/SKILL.md`](skills/woostack-build/SKILL.md)
- Plan-writing engine for the build loop (public command):
  [`skills/woostack-plan/SKILL.md`](skills/woostack-plan/SKILL.md)
- Plan-execution engine for the build loop (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
- Overnight (unattended, autonomous) plan-execution engine (public command):
  [`skills/woostack-execute-overnight/SKILL.md`](skills/woostack-execute-overnight/SKILL.md)
- Ideate phase engine for the build loop (internal sub-skill):
  [`skills/woostack-ideate/SKILL.md`](skills/woostack-ideate/SKILL.md)
- Harden phase engine for the build loop (internal sub-skill):
  [`skills/woostack-harden/SKILL.md`](skills/woostack-harden/SKILL.md)
- Commit and PR update flow:
  [`skills/woostack-commit/SKILL.md`](skills/woostack-commit/SKILL.md)
- Review engine:
  [`skills/woostack-review/`](skills/woostack-review/)
- Systematic-debugging engine (public command + internal hook invoked by execute/review):
  [`skills/woostack-debug/SKILL.md`](skills/woostack-debug/SKILL.md)
- Visualization engine (audience-tailored HTML renders):
  [`skills/woostack-visualize/SKILL.md`](skills/woostack-visualize/SKILL.md)
- Address-comments delegator:
  [`skills/woostack-address-comments/SKILL.md`](skills/woostack-address-comments/SKILL.md)
- Derived feature board (status command) and its canonical feature-state conventions:
  [`skills/woostack-status/SKILL.md`](skills/woostack-status/SKILL.md),
  [`skills/woostack-status/references/conventions.md`](skills/woostack-status/references/conventions.md)
- Init workspace and memory contract:
  [`skills/woostack-init/`](skills/woostack-init/)
