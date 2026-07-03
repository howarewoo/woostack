# AGENTS.md

This repository follows woostack. At the start of work, use
[`using-woostack`](skills/using-woostack/SKILL.md) to load repo rules and route
`/woostack-*` requests to the matching skill.

Follow this file first when it conflicts with generic agent defaults. `.claude/CLAUDE.md` is a
symlink to this file, and Antigravity CLI (`agy`) reads `AGENTS.md` natively, so this is the
single source of truth across agents.

## What this repo is

This is a published collection of skills, not an application codebase. It packages
decisions for building new web, mobile, and API projects so agents can install it with
`pnpx skills add howarewoo/woostack`.

The public command/adoption surface has twenty skills:

- [`using-woostack`](skills/using-woostack/SKILL.md)
- [`woostack-init`](skills/woostack-init/SKILL.md)
- [`woostack-bootstrap`](skills/woostack-bootstrap/SKILL.md)
- [`woostack-build`](skills/woostack-build/SKILL.md)
- [`woostack-fix`](skills/woostack-fix/SKILL.md)
- [`woostack-plan`](skills/woostack-plan/SKILL.md)
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
- [`woostack-execute-overnight`](skills/woostack-execute-overnight/SKILL.md)
- [`woostack-commit`](skills/woostack-commit/SKILL.md)
- [`woostack-review`](skills/woostack-review/SKILL.md)
- [`woostack-address-comments`](skills/woostack-address-comments/SKILL.md)
- [`woostack-status`](skills/woostack-status/SKILL.md)
- [`woostack-visualize`](skills/woostack-visualize/SKILL.md)
- [`woostack-debug`](skills/woostack-debug/SKILL.md)
- [`woostack-tdd`](skills/woostack-tdd/SKILL.md)
- [`woostack-dream`](skills/woostack-dream/SKILL.md)
- [`woostack-doctor`](skills/woostack-doctor/SKILL.md)
- [`woostack-sweep`](skills/woostack-sweep/SKILL.md)
- [`woostack-qa`](skills/woostack-qa/SKILL.md)
- [`woostack-audit`](skills/woostack-audit/SKILL.md)

The collection also installs two internal sub-skills:
[`woostack-ideate`](skills/woostack-ideate/SKILL.md) and
[`woostack-harden`](skills/woostack-harden/SKILL.md). `woostack-build` delegates its ideate
phase to the former and its harden phase to the latter. Both are bundled building blocks, not
`/woostack-*` commands: they have no routing row and are absent from the twenty-skill command surface above. Like [`action.yml`](action.yml), they are shipped assets — do not delete them as
strays.

There is no application source code, app lockfile, build, or CI for this repo's own
push/PR events. `skills-lock.json` is the dev-skill manifest and is currently empty.

The exception is consumer-facing review delivery: [`action.yml`](action.yml) and
[`.github/workflows/reusable-review.yml`](.github/workflows/reusable-review.yml) ship from
this repo so consumers can run `woostack-review` in their own CI. They are shipped assets,
not self-CI, and should not be deleted as stray workflows.

The second exception is the user-facing documentation site: [`site/`](site/) is a shipped
Fumadocs (Next.js) application subtree — the docs site for these skills. Like
[`action.yml`](action.yml), it is a shipped asset, not stray app code. Its `package.json`,
`pnpm-lock.yaml`, and build config are the one sanctioned exception to the "no application
source code / no app lockfile" rule above. Its per-skill reference pages are **generated**
from `skills/*/SKILL.md` at build time and are gitignored; only the app shell and authored
framing pages are committed. Deploy notes live in [`site/README.md`](site/README.md).

## Modes

Identify the mode before acting.

**Mode A: edit this skill collection.** Use this when updating skill Markdown, reference
docs, HTML templates, review scripts, prompts, or JSON config. Keep edits in skill assets;
do not add application code, app build configs, or app lockfiles **outside the sanctioned
[`site/`](site/) docs-app subtree** (see the documentation-site exception above). Editing
`site/` is also Mode A.

**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-build`, `/woostack-fix`, `/woostack-plan`, `/woostack-execute`, `/woostack-execute-overnight`, `/woostack-commit`,
`/woostack-review`, `/woostack-address-comments`, `/woostack-status`, `/woostack-visualize`, `/woostack-debug`, `/woostack-dream`,
`/woostack-tdd`, `/woostack-doctor`, `/woostack-sweep`, `/woostack-qa`, or `/woostack-audit`, including intent-equivalent wording. Load the matching skill
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
- Keep the docs site in sync. When a change alters what an **authored** [`site/`](site/) page
  states — the skill surface or its count, the build loop and its gates, the core concepts, or
  the getting-started flow — update the matching page under
  [`site/content/docs/`](site/content/docs/) as part of the same change. The per-skill reference
  pages need no manual edit: they regenerate from each `SKILL.md` at build time (see the
  documentation-site exception above). When in doubt, run `pnpm -C site build` to confirm the
  site still builds.
- Do not move or rename any of the twenty-two `SKILL.md` files (the twenty public command/adoption
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
- Small-change fix loop (public command; diagnose → fix plan → approve → delegate execution to woostack-execute):
  [`skills/woostack-fix/SKILL.md`](skills/woostack-fix/SKILL.md)
- Plan-writing engine for the build loop (public command):
  [`skills/woostack-plan/SKILL.md`](skills/woostack-plan/SKILL.md)
- Plan-execution engine for the build loop (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
- Overnight (unattended, autonomous) plan-execution engine (public command):
  [`skills/woostack-execute-overnight/SKILL.md`](skills/woostack-execute-overnight/SKILL.md)
- Stack review-sweep engine (public command + delegated-to by execute-overnight):
  [`skills/woostack-sweep/SKILL.md`](skills/woostack-sweep/SKILL.md)
- Exploratory browser QA engine (public command; drives a running app via the `agent-browser`
  CLI, report-only findings under `.woostack/qa/`):
  [`skills/woostack-qa/SKILL.md`](skills/woostack-qa/SKILL.md)
- Standing-code audit engine (public command; repoints the review swarm at an all-added diff of a
  target, report-only): [`skills/woostack-audit/SKILL.md`](skills/woostack-audit/SKILL.md)
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
- Memory & docs curation engine (public command; agent-agnostic "dreams"):
  [`skills/woostack-dream/SKILL.md`](skills/woostack-dream/SKILL.md)
- Workspace health — diagnose + gated repair of `.woostack/` (the 17th public command):
  [`skills/woostack-doctor/SKILL.md`](skills/woostack-doctor/SKILL.md)
- TDD doctrine home and add-tests command (public command):
  [`skills/woostack-tdd/SKILL.md`](skills/woostack-tdd/SKILL.md)
- Address-comments delegator:
  [`skills/woostack-address-comments/SKILL.md`](skills/woostack-address-comments/SKILL.md)
- Derived feature board (status command) and its canonical feature-state conventions:
  [`skills/woostack-status/SKILL.md`](skills/woostack-status/SKILL.md),
  [`skills/woostack-status/references/conventions.md`](skills/woostack-status/references/conventions.md)
- Init workspace and memory contract:
  [`skills/woostack-init/`](skills/woostack-init/)
- Docs site — shipped Fumadocs app; authored framing pages plus the per-`SKILL.md` generator
  (keep authored pages in sync with the skills, per Hard constraints):
  [`site/`](site/), authored pages [`site/content/docs/`](site/content/docs/), deploy notes
  [`site/README.md`](site/README.md)
