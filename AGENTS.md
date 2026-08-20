# AGENTS.md

Follow this file first when it conflicts with generic agent defaults. `.claude/CLAUDE.md` is a
symlink to this file, and Antigravity CLI (`agy`) reads `AGENTS.md` natively, so this is the
single source of truth across agents.

## What this repo is

This is a published collection of skills, not an application codebase. It packages
decisions for building new web, mobile, and API projects so agents can install it with
`pnpx skills add howarewoo/woostack`.

The public command/adoption surface has twenty-one skills:

- [`using-woostack`](skills/using-woostack/SKILL.md)
- [`woostack-init`](skills/woostack-init/SKILL.md)
- [`woostack-bootstrap`](skills/woostack-bootstrap/SKILL.md)
- [`woostack-build`](skills/woostack-build/SKILL.md)
- [`woostack-fix`](skills/woostack-fix/SKILL.md)
- [`woostack-change`](skills/woostack-change/SKILL.md)
- [`woostack-plan`](skills/woostack-plan/SKILL.md)
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
- [`woostack-commit`](skills/woostack-commit/SKILL.md)
- [`woostack-review`](skills/woostack-review/SKILL.md)
- [`woostack-address-comments`](skills/woostack-address-comments/SKILL.md)
- [`woostack-status`](skills/woostack-status/SKILL.md)
- [`woostack-visualize`](skills/woostack-visualize/SKILL.md)
- [`woostack-debug`](skills/woostack-debug/SKILL.md)
- [`woostack-tdd`](skills/woostack-tdd/SKILL.md)
- [`woostack-doctor`](skills/woostack-doctor/SKILL.md)
- [`woostack-sweep`](skills/woostack-sweep/SKILL.md)
- [`woostack-qa`](skills/woostack-qa/SKILL.md)
- [`woostack-audit`](skills/woostack-audit/SKILL.md)
- [`woostack-eval`](skills/woostack-eval/SKILL.md)
- [`woostack-reflect`](skills/woostack-reflect/SKILL.md)

The collection also installs two internal sub-skills:
[`woostack-ideate`](skills/woostack-ideate/SKILL.md) and
[`woostack-harden`](skills/woostack-harden/SKILL.md). `woostack-build` delegates its ideate
phase to the former and its harden phase to the latter. Both are bundled building blocks, not
`/woostack-*` commands: they have no routing row and are absent from the twenty-one-skill command
surface above.

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

## Consumer development artifacts

The canonical persistent artifact store for `woostack-build` and project-backed `woostack-fix` is
local in `.woostack/tmp/runs/<run-id>/`. Linear is an optional mirror flow gated by
`linear.saveArtifacts: true` in `.woostack/config.json`. By default (`linear.saveArtifacts: false` or
omitted), Build and Fix operate with default zero-provider local authority. Supplying `--project`
when `linear.saveArtifacts` is false or absent fails closed immediately.

Gated Ideate, Harden, and delegated Plan work is managed in one permission-restricted run manifest
with zero provider cycles. Build and Fix write plain `project-spec.md` and `execution-plan.md`
directly under `.woostack/tmp/runs/<run-id>/` and proceed directly to a user-controlled handoff
(`Stop here`, `Execute`, `Abandon`). When `linear.saveArtifacts: true`, local artifacts mirror to
Linear in bounded post-drafting cycles; mirror failure is recorded in the manifest and is
nonblocking for local authority. Resuming work uses `/woostack-execute --run <exact-run-id> [--recheck]`,
`/woostack-build --run <exact-run-id>`, or `/woostack-fix --run <exact-run-id>`. All run artifacts in
`.woostack/tmp/runs/<run-id>/` are retained upon completion and upon explicit abandonment to preserve
an unbroken audit trail. Explicit abandonment sets `status: "abandoned"` in the manifest and does not
mutate a mirrored Linear project. Standalone Plan synchronization remains direct and unchanged. The
shared
[Local run artifact and provider mirror contract](skills/woostack-init/references/artifact-backends.md#minimal-resumable-manifest-schema)
owns the detailed manifest, ordering, recovery, identity mapping, retention, and Execute read
contract.
The user's request and each workflow's explicit approval gates authorize repository work; artifacts
record that work and never grant permission, assignment, ownership, acceptance, or source-control
authority. Git and GitHub own source, branches, commits, pull requests, reviews, and merge evidence.

`/woostack-init` may use only the official Linear MCP for narrow automatic authenticated read-only
discovery of non-secret repository/workspace/team/native-name defaults; it never selects
persistence or authorizes a provider write. `.woostack/config.json` supplies validated defaults
only after artifact selection. Credentials remain in the host secret store, and local diagnostic
reports remain non-authoritative. `woostack-change` never contacts Linear. Handoff, replanning, and
blockers leave project status unchanged.

External engineers such as Hermes are outside the installed woostack host/runtime surface. Hermes
may drive one persistent OMP session as an external decision-maker and reviewer, but woostack is
installed only in OMP or another coding harness. When Hermes participates in an active conversation,
the responsible user's live response must be relayed verbatim; cross-session resume against
retained unchanged local run artifacts does not require the original process to stay alive.
contract lives in the authored [Hermes guide](site/content/docs/hermes.mdx); it does not make Hermes a supported host
or grant it implementation authority.

This collection still has twenty-one public command/adoption skills at twenty-three fixed `SKILL.md`
locations. Linear support adds neither a command-routing row nor a per-provider skill.
## Modes

Identify the mode before acting.

**Mode A: edit this skill collection.** Use this when updating skill Markdown, reference
docs, HTML templates, review scripts, prompts, or JSON config. Keep edits in skill assets;
do not add application code, app build configs, or app lockfiles **outside the sanctioned
[`site/`](site/) docs-app subtree** (see the documentation-site exception above). Editing
`site/` is also Mode A.

**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-build`, `/woostack-fix`, `/woostack-change`, `/woostack-plan`, `/woostack-execute`, `/woostack-commit`,
`/woostack-review`, `/woostack-address-comments`, `/woostack-status`, `/woostack-visualize`, `/woostack-debug`,
`/woostack-tdd`, `/woostack-doctor`, `/woostack-sweep`, `/woostack-qa`, `/woostack-audit`, `/woostack-eval`, or `/woostack-reflect`, including intent-equivalent wording. Load the matching skill
before acting. For bootstrap work, the output belongs in a fresh repo in a different
directory, not in this repo.

## Hard constraints

- **Least code, still safe.** Skills — and the code they generate — write as little code as
  necessary: understand the change first, then take the first rung that holds, preferring
  deletion over addition and boring over clever — small because it is necessary, not golfed.
  Never buy that smallness by cutting edge cases or risks: validation, error handling, security,
  accessibility, and data-loss handling stay, and deliberate multi-layer safety redundancy is
  kept, not DRY-removed. Full standard — the ladder, its deltas, comments, and magic-literal
  rules — is [`patterns.md §10`](skills/woostack-bootstrap/references/patterns.md), enforced by
  the `simplify`/`comments` review angles.
- No fabricated versions. When a skill or generated project needs a version, resolve it
  live with `npm view <pkg> version` or an equivalent registry command.
- No hidden tools. Do not invent CI, app tests, package scripts, or app build steps for this
  repo.
- Benchmark and evaluation workflows default to local temporary repositories. Creating remote
  repositories requires the user's prior approval of the exact owner, names, count, purpose, and
  cleanup plan.
- Respect branch protection. `main` is protected and requires PRs; never force-push to
  `main`.
- **Merge authority is human-only.** Agents never mark a PR ready, enable auto-merge, enqueue it,
  merge it, or otherwise advance it toward merge. `Complete`, `deliver`, `execute`, passing
  verification, approved artifacts, and accepted reviews mean submit or update a reviewable open
  PR only. They do not grant merge authority. Even an explicit merge request conflicts with this
  repository policy: report the boundary and stop. Never run `gh pr ready`, `gh pr merge`, a
  merge-queue mutation, or an equivalent Graphite/GitHub operation.
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
- Do not move or rename any of the twenty-three `SKILL.md` files (the twenty-one public command/adoption
  skills plus internal `woostack-ideate` and `woostack-harden`).
- Do not rename files under
  [`skills/woostack-bootstrap/references/`](skills/woostack-bootstrap/references/) without
  updating every cross-link and the bootstrap skill table.
- Do not commit `.env*`, secrets, generated app files, or personal compressed prose.
- **Mode A Fix/Build self-hosted Eval corpus/fixture changes.** This is deterministic repository policy, not a Harden question: if a Mode A Fix/Build execution plan changes self-hosted Eval corpus or referenced fixture bytes, use deterministic validation only and defer full `/woostack-eval` to a separate explicit invocation after those bytes are committed and byte-identical to `HEAD`; otherwise, direct explicit `/woostack-eval` retains its existing approval path, including normal Eval for tracked bytes byte-identical to `HEAD`.

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
- Bounded non-bug change loop (public command; one reviewable PR, no approval gate or persisted plan):
  [`skills/woostack-change/SKILL.md`](skills/woostack-change/SKILL.md)
- Plan-writing engine for the build loop (public command):
  [`skills/woostack-plan/SKILL.md`](skills/woostack-plan/SKILL.md)
- Plan-execution engine for the build loop (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
- Stack review-sweep engine (public command):
  [`skills/woostack-sweep/SKILL.md`](skills/woostack-sweep/SKILL.md)
- Exploratory browser QA engine (public command; drives a running app via the `agent-browser`
  CLI, report-only findings under `.woostack/qa/`):
  [`skills/woostack-qa/SKILL.md`](skills/woostack-qa/SKILL.md)
- Standing-code audit engine (public command; repoints the review swarm at an all-added diff of a
  target, report-only): [`skills/woostack-audit/SKILL.md`](skills/woostack-audit/SKILL.md)
- Skill behavior and trigger evaluation engine (public command; approved corpora, isolated paired
  comparisons, transient reports, no target skill edits):
  [`skills/woostack-eval/SKILL.md`](skills/woostack-eval/SKILL.md)
- Session reflection (public report and internal final-reply hook):
  [`skills/woostack-reflect/SKILL.md`](skills/woostack-reflect/SKILL.md)
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
- Workspace health — diagnose + gated repair of `.woostack/`:
  [`skills/woostack-doctor/SKILL.md`](skills/woostack-doctor/SKILL.md)
- TDD doctrine home and add-tests command (public command):
  [`skills/woostack-tdd/SKILL.md`](skills/woostack-tdd/SKILL.md)
- Address-comments delegator:
  [`skills/woostack-address-comments/SKILL.md`](skills/woostack-address-comments/SKILL.md)
- Derived feature board (status command) and its canonical feature-state conventions:
  [`skills/woostack-status/SKILL.md`](skills/woostack-status/SKILL.md),
  [`skills/woostack-status/references/conventions.md`](skills/woostack-status/references/conventions.md)
- Init workspace and repository policy contract:
  [`skills/woostack-init/`](skills/woostack-init/)
- Docs site — shipped Fumadocs app; authored framing pages plus the per-`SKILL.md` generator
  (keep authored pages in sync with the skills, per Hard constraints):
  [`site/`](site/), authored pages [`site/content/docs/`](site/content/docs/), deploy notes
  [`site/README.md`](site/README.md)
