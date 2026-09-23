# AGENTS.md

Follow this file first when it conflicts with generic agent defaults. `.claude/CLAUDE.md` is a
symlink to this file, and Antigravity CLI (`agy`) reads `AGENTS.md` natively, so this is the
single source of truth across agents.

## What this repo is

This is a published collection of skills, not an application codebase. It packages
decisions for building new web, mobile, and API projects so agents can install it with
`pnpx skills add howarewoo/woostack`.

The public command/adoption surface has eighteen skills:

- [`using-woostack`](skills/using-woostack/SKILL.md)
- [`woostack-init`](skills/woostack-init/SKILL.md)
- [`woostack-bootstrap`](skills/woostack-bootstrap/SKILL.md)
- [`woostack-ideate`](skills/woostack-ideate/SKILL.md)
- [`woostack-harden`](skills/woostack-harden/SKILL.md)
- [`woostack-prepare`](skills/woostack-prepare/SKILL.md)
- [`woostack-plan`](skills/woostack-plan/SKILL.md)
- [`woostack-orchestrate`](skills/woostack-orchestrate/SKILL.md)
- [`woostack-execute`](skills/woostack-execute/SKILL.md)
- [`woostack-commit`](skills/woostack-commit/SKILL.md)
- [`woostack-address-comments`](skills/woostack-address-comments/SKILL.md)
- [`woostack-visualize`](skills/woostack-visualize/SKILL.md)
- [`woostack-design`](skills/woostack-design/SKILL.md)
- [`woostack-debug`](skills/woostack-debug/SKILL.md)
- [`woostack-doctor`](skills/woostack-doctor/SKILL.md)
- [`woostack-qa`](skills/woostack-qa/SKILL.md)
- [`woostack-eval`](skills/woostack-eval/SKILL.md)
- [`woostack-reflect`](skills/woostack-reflect/SKILL.md)

Ideate and Harden are public standalone phases and composable callers for Prepare. They exchange
complete plain content with explicit repository/evidence identity; no run manifest, provider mirror,
or wrapper admission is required to invoke either one.

Prepare is the planning-only composition for feature and defect preparation. It invokes the relevant
public phases and ends at a verified GitHub issue graph; it never implements work or invokes
Execute/Orchestrate.

There is no application source code, app lockfile, build, or CI for this repo's own
push/PR events. `skills-lock.json` is the dev-skill manifest and is currently empty.


The user-facing documentation site: [`site/`](site/) is a shipped
Fumadocs (Next.js) application subtree — the docs site for these skills. It is a shipped asset,
not stray app code. Its `package.json`, `pnpm-lock.yaml`, and build config are the one sanctioned
exception to the "no application source code / no app lockfile" rule above. Its per-skill reference
pages are **generated** from `skills/*/SKILL.md` at build time and are gitignored; only the app shell
and authored framing pages are committed. Deploy notes live in [`site/README.md`](site/README.md).
Prepare and Plan use complete plain packets and GitHub's native parent/child issues as the planning
handoff. They do not create a local run, provider mirror, replacement work board, source branch,
worktree, commit, pull request, or implementation worker. Existing `.woostack/tmp/runs/<run-id>/`
records from retired workflows remain readable user data and are never migrated or mutated.

An existing retained draft or issue may be supplied explicitly only with its exact identity,
complete content, and fresh repository/evidence validation. It does not authorize publication,
implementation, assignment, ownership, acceptance, or source-control action. Plan owns direct
GitHub issue and relationship publication; Orchestrate owns scheduling and Execute owns bounded
implementation and PR delivery.



`/woostack-init` may use only the official Linear MCP or an authorized GitHub read capability for
narrow automatic authenticated read-only discovery of non-secret repository/workspace/team/native-name
defaults; it never selects persistence or authorizes a provider write. `.woostack/config.json` supplies
validated defaults only after artifact selection. Credentials remain in the host secret store, and
local diagnostic reports remain non-authoritative. Goal-only Execute makes no development-artifact
provider calls; an explicitly selected exact GitHub issue permits only the read-only GitHub capability
defined in Execute's optional issue contract, even with `artifacts.provider` local or omitted. That
exception does not select artifact mirroring or authorize work. Handoff, replanning, and blockers
leave project status unchanged.

Explicit [`woostack-orchestrate`](skills/woostack-orchestrate/SKILL.md) execution selects one
GitHub specification parent with native task children, one configured GitHub Project, or an
explicit canonical list of GitHub issues. Parent-issue execution does not require provider
mirroring or Project configuration; list execution does not require a parent, Project, or native
dependency publication. Orchestrate owns scheduling and independent post-submission validation; each
Execute worker owns one task's delivery through Commit. This preserves the planning-only Prepare
boundary and does not grant merge authority.

External engineers such as Hermes are outside the installed woostack host/runtime surface. Hermes
may drive one persistent OMP session as an external decision-maker and reviewer, but woostack is
installed only in OMP or another coding harness. When Hermes participates in an active conversation,
the responsible user's live response must be relayed verbatim; cross-session resume against retained
unchanged local run artifacts does not require the original process to stay alive. The contract lives
in the authored [Hermes guide](site/content/docs/hermes.mdx); it does not make Hermes a supported
host or grant it implementation authority.

This collection has eighteen public command/adoption skills at eighteen fixed `SKILL.md` locations.

Identify the mode before acting.

**Mode A: edit this skill collection.** Use this when updating skill Markdown, reference
docs, HTML templates, supporting scripts, prompts, or JSON config. Keep edits in skill assets;
do not add application code, app build configs, or app lockfiles **outside the sanctioned
[`site/`](site/) docs-app subtree** (see the documentation-site exception above). Editing
`site/` is also Mode A.

**Mode B: run a woostack command.** Use this when the user asks for `/woostack-init`,
`/woostack-bootstrap`, `/woostack-ideate`, `/woostack-harden`, `/woostack-prepare`,
`/woostack-plan`, `/woostack-orchestrate`, `/woostack-execute`, `/woostack-commit`,
`/woostack-address-comments`, `/woostack-visualize`, `/woostack-design`, `/woostack-debug`,
`/woostack-doctor`, `/woostack-qa`, `/woostack-eval`, or `/woostack-reflect`, including
intent-equivalent wording. Load the matching skill before acting. For bootstrap work, the output
belongs in a fresh repo in a different directory, not in this repo.

## Hard constraints

- **Least code, still safe.** Skills — and the code they generate — write as little code as
  necessary: understand the change first, then take the first rung that holds, preferring
  deletion over addition and boring over clever — small because it is necessary, not golfed.
  Never buy that smallness by cutting edge cases or risks: validation, error handling, security,
  accessibility, and data-loss handling stay, and deliberate multi-layer safety redundancy is
  kept, not DRY-removed. Full standard — the ladder, its deltas, comments, and magic-literal
rules — is [`patterns.md §7`](skills/woostack-bootstrap/references/patterns.md#7-least-code--comments), enforced by
the repository's simplify/comments guidance.
- **Remove before add.** When relaxing or removing a repository restriction, delete the obsolete
  rule and its dependent explanations first. Add replacement text only when needed to preserve a
  necessary positive invariant; never enumerate behavior that is merely no longer forbidden.
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
- Use native Git with an available, authorized GitHub integration for source control; prefer the
  host's native GitHub tools when suitable and use host-authenticated `gh` where appropriate.
  Discover the actual capabilities and preserve the [source-control contract](skills/woostack-commit/references/graphite.md);
  Graphite is optional and must be selected explicitly or by verified existing management evidence.
  Backend errors stop the operation rather than trigger a fallback. Never force-push.
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
- Do not move or rename any of the nineteen `SKILL.md` files. Public command/adoption names and
  fixed paths are part of the installed interface, except for an explicitly approved
  retirement that removes the complete skill and its references.
- Do not rename files under
  [`skills/woostack-bootstrap/references/`](skills/woostack-bootstrap/references/) without
  updating every cross-link and the bootstrap skill table.
- Do not commit `.env*`, secrets, generated app files, or personal compressed prose.
- **Mode A Prepare self-hosted Eval corpus/fixture changes.** This is deterministic repository policy,
  not a Harden question: if a Mode A Prepare execution plan changes self-hosted Eval corpus or
  referenced fixture bytes, use deterministic validation only and defer full `/woostack-eval` to a
  separate explicit invocation after those bytes are committed and byte-identical to `HEAD`;
  otherwise, direct explicit `/woostack-eval` retains its existing approval path, including normal
  Eval for tracked bytes byte-identical to `HEAD`.

## Quick file map

- Project adoption and command routing:
  [`skills/using-woostack/SKILL.md`](skills/using-woostack/SKILL.md)
- Bootstrap decisions, architecture, frameworks, infrastructure, patterns, development, and
  procedure:
  [`skills/woostack-bootstrap/references/`](skills/woostack-bootstrap/references/)
- Preparation and publication composition:
  [`skills/woostack-prepare/SKILL.md`](skills/woostack-prepare/SKILL.md)
- Public specification elicitation phase:
  [`skills/woostack-ideate/SKILL.md`](skills/woostack-ideate/SKILL.md)
- Public repository reconciliation phase:
  [`skills/woostack-harden/SKILL.md`](skills/woostack-harden/SKILL.md)
- Shared plain planning input and handback contract:
  [`skills/using-woostack/references/planning-inputs.md`](skills/using-woostack/references/planning-inputs.md)
- Plan-owned GitHub issue publication engine (public command):
  [`skills/woostack-plan/SKILL.md`](skills/woostack-plan/SKILL.md)
- Bounded task execution engine delivering one task through one PR (public command):
  [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)
- GitHub parent-issue, explicit issue-list, or explicit Project orchestration (public command):
  [`skills/woostack-orchestrate/SKILL.md`](skills/woostack-orchestrate/SKILL.md)
- Execute testing doctrine:
  [`skills/woostack-execute/references/tdd.md`](skills/woostack-execute/references/tdd.md)
- Exploratory browser QA engine (public command; drives a running app via the `agent-browser`
  CLI, report-only findings under `.woostack/qa/`):
  [`skills/woostack-qa/SKILL.md`](skills/woostack-qa/SKILL.md)
- Skill behavior and trigger evaluation engine (public command; approved corpora, isolated paired
  comparisons, transient reports, no target skill edits):
  [`skills/woostack-eval/SKILL.md`](skills/woostack-eval/SKILL.md)
- Session reflection (public report and internal final-reply hook):
  [`skills/woostack-reflect/SKILL.md`](skills/woostack-reflect/SKILL.md)
- Commit and PR update flow:
  [`skills/woostack-commit/SKILL.md`](skills/woostack-commit/SKILL.md)
- Systematic-debugging engine (public command + internal hook invoked by execute):
  [`skills/woostack-debug/SKILL.md`](skills/woostack-debug/SKILL.md)
- Visualization engine (audience-tailored HTML renders):
  [`skills/woostack-visualize/SKILL.md`](skills/woostack-visualize/SKILL.md)
- Design flow layout standard (standardized multi-step flow layouts):
  [`skills/woostack-design/SKILL.md`](skills/woostack-design/SKILL.md)
- Workspace health — diagnose + gated repair of `.woostack/`:
  [`skills/woostack-doctor/SKILL.md`](skills/woostack-doctor/SKILL.md)
- Address-comments delegator:
  [`skills/woostack-address-comments/SKILL.md`](skills/woostack-address-comments/SKILL.md)
- The work-tracking source of truth is canonical GitHub parent/child issues, native dependency
  relations, and associated pull requests; GitHub Project Status fields remain provider metadata.
  Inspect those records directly. Local run manifests remain workflow progress and recovery
  artifacts, not a replacement work board.
- Init workspace and repository policy contract:
  [`skills/woostack-init/`](skills/woostack-init/)
- Docs site — shipped Fumadocs app; authored framing pages plus the per-`SKILL.md` generator
  (keep authored pages in sync with the skills, per Hard constraints):
  [`site/`](site/), authored pages [`site/content/docs/`](site/content/docs/), deploy notes
  [`site/README.md`](site/README.md)
