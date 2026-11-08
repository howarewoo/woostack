# woostack

WooStack has three parts: a recommended tech stack, agent skills for coding harnesses,
and an autonomous agent setup in development. Start with the part you need:

- [Tech stack](apps/docs/content/docs/recommended-stack.mdx): recommended technologies and how they fit together.
- [Agent skills](apps/docs/content/docs/getting-started.mdx): workflows for planning, building, and checking products inside a coding harness.
- [Agent teams](apps/docs/content/docs/agent-teams/index.mdx): the coordinated setup being developed, with a [manual R&D setup guide](apps/docs/content/docs/agent-teams/setup.mdx) for OpenMausBot teams. No packaged runtime or installer is provided.

You can adopt the tech stack or the skills independently. Using the skills does not require
the recommended stack or the autonomous setup. You make the product decisions and authorize work.

The rest of this overview covers the agent skills. They guide an AI coding assistant to inspect
the repository and GitHub and verify outcomes before reporting what changed or is ready for review.

For a goal that needs refinement, use [Whiteboard](skills/woostack-whiteboard/SKILL.md): develop
requirements, challenge the design, and refine a visual model and written plan. It works for a
person or delegated agent without requiring questions when the context is sufficient. Review-only
requests preserve the supplied plan; document saves and issue publication remain explicit.
A small, understood change can go directly to implementation. Verify changes and request independent
review when required or warranted by risk.

Start with the [getting-started guide](apps/docs/content/docs/getting-started.mdx), or use the
[command index](skills/using-woostack/SKILL.md#command-routing) to choose a workflow among the
installed commands.


## Getting started

This section installs and introduces the agent skills.

### 1. Install the skills

With Node.js and pnpm installed, run this from your project's repository root
to install the collection for your coding assistant:

```bash
pnpx skills add howarewoo/woostack
```

Each skill installs separately and bundles its reusable Woostack procedures, so it needs no sibling
Woostack skill or source checkout. Installing or updating one does not mutate the others.
Design additionally uses selected external skills, described below. To install only Execute:

```bash
pnpx skills add howarewoo/woostack --skill woostack-execute
```

A single-skill install changes only which directories arrive, not the workflow's semantics.

The public commands are listed in the
[command index](skills/using-woostack/SKILL.md#command-routing). Ideate, Plan, and Harden are retired
without aliases; use Whiteboard for requirements exploration, planning, specification review,
and requested issue publication.

For UI work, [Design](skills/woostack-design/SKILL.md#selected-skills) uses
[Impeccable](https://github.com/pbakaus/impeccable) as its design lead, with relevant specialists
from [Emil Kowalski's collection](https://github.com/emilkowalski/skills).
Install the selected skills using your assistant's supported mechanism and their current upstream
instructions. The Woostack install does not install these dependencies. Design checks availability
and asks before a missing dependency is installed; it does not silently substitute generic advice.
Only the skills needed for the task are required. See the
[dependency boundary](skills/woostack-design/SKILL.md#dependency-boundary) for permissions and recovery.

### 2. Create useful project guidance

Open your coding assistant in the project root and enter:

```text
/woostack-init
```

Init inspects your repository and existing decisions, consults with you on the project's
intention, structure, direction, and architecture before writing, and helps create or update
`README.md`, `PRODUCT.md`, `DESIGN.md`, `ARCHITECTURE.md`, and `AGENTS.md`. It preserves useful content
linked to canonical documents rather than copying them. You can limit the request to one document
or ask for drafts without writes. During Woostack adoption, Init includes the concise
[adoption paragraph](skills/woostack-init/SKILL.md#document-responsibilities) in the proposed agent
instructions, so no Woostack skill becomes a prerequisite of another.

Init uses the current applicable [document formats](skills/woostack-init/references/document-schemas.md):
an evidence-backed README landing page, Impeccable's product record, the visual DESIGN.md
specification, technical orientation in ARCHITECTURE.md, and unversioned AGENTS.md guidance.
Existing architecture documents keep their established authority; the root overview links to them.

Document authoring needs no Woostack configuration or GitHub access. Init does not scaffold an
application, handle credentials, or create issues, branches, commits, or PRs. See
[Init](skills/woostack-init/SKILL.md) for the workflow.

Skills require no Woostack setup or configuration files. They use your request, repository guidance,
and available host capabilities. Keep credentials in your host's secret store.

For pull-request review, use [Pullfrog](https://pullfrog.com/). This repository includes the
Pullfrog workflow at [`.github/workflows/pullfrog.yml`](.github/workflows/pullfrog.yml).

See the [workflow inputs reference](apps/docs/content/docs/configuration/index.mdx) for task scope,
verification, branch selection, authentication, and output locations.


Whiteboard handles a goal or incomplete issue directly. It inspects relevant source, resolves
material choices within supplied authority, and escalates uncovered consequential decisions.
Requirements-only requests can stop at exploration without a solution or implementation plan.
Debug remains available for diagnosis, not a mandatory handoff. An explicit GitHub Project is
optional for requested issue publication. Existing records remain historical user data and are never
migrated or mutated; retained drafts are evidence, not publication or implementation authority.

The [artifact contract](shared/references/artifact-backends.md) explains direct
GitHub publication, recovery, and retained historical record handling. Saved plans and remote
records record decisions; they do not authorize new work or prove that code was delivered.

For OpenMausBot teams, follow the
[R&D setup guide](apps/docs/content/docs/agent-teams/setup.mdx) for work-in-progress guidance on
roles, scoped access, shared knowledge, and handoffs.

## Choose a development workflow

For goals needing refinement, [whiteboard a goal into a plan](apps/docs/content/docs/guides/whiteboard.mdx),
then separately authorize implementation. The plan and visual stay in the conversation unless you
request a document save or publication. Orchestrate accepts that prose directly and presents its
execution proposal before dispatching workers; no issue export or mandatory plan file is needed.
Its default is user approval, with bounded user-delegated authority available for a named coordinator.

For requested issue publication, use Whiteboard. An understood bounded task can go directly to
Execute.

| What you need | Command | What happens |
| --- | --- | --- |
| Plan a goal or existing design, including a new project | [/woostack-whiteboard](skills/woostack-whiteboard/SKILL.md) | Develops requirements and a portable visual plan, using supplied context without a mandatory interview or checkout. |
| Create a bounded initial application | [/woostack-execute](skills/woostack-execute/SKILL.md) | Checks target safety, creates the requested working slice, and verifies it; local-only needs no GitHub or PR. |
| Explore requirements | [/woostack-whiteboard](skills/woostack-whiteboard/SKILL.md) | Returns a focused specification or answer, alternatives, and open decisions without forcing an implementation plan. |
| Review a specification or plan | [/woostack-whiteboard](skills/woostack-whiteboard/SKILL.md) | A review-only request returns evidence-backed discrepancies without rewriting the supplied content. |
| File a plan as issues | [/woostack-whiteboard](skills/woostack-whiteboard/SKILL.md) | Publishes and reads back issues only when explicitly requested. |
| A bounded implementation task | [/woostack-execute](skills/woostack-execute/SKILL.md) | Implements and verifies an enhancement, refactor, test-only task, or understood correction; delivers a draft PR when requested. |
| Simplify an existing implementation | [/woostack-simplify](skills/woostack-simplify/SKILL.md) | Reworks selected code and removes unnecessary machinery while preserving required behavior; local edits by default, analysis-only when requested. |
| Coordinate multiple authorized tasks | [/woostack-orchestrate](skills/woostack-orchestrate/SKILL.md) | Resolves tasks and dependencies from prose, issues, or an explicitly selected Project; delegates to native-host workers in owned workspaces and verifies draft PRs without merging. |
| Design, prototype, refine, or critique UI | [/woostack-design](skills/woostack-design/SKILL.md) | Coordinates selected external design skills, agrees consequential directions before implementation, and checks the rendered result within the request's scope. |
| Arrange existing screen flows | [/woostack-flow-layout](skills/woostack-flow-layout/SKILL.md) | Positions screen sequences and branches without redesigning their contents. |
| Create or inspect a project component catalog | [/woostack-design-system](skills/woostack-design-system/SKILL.md) | Creates locally when no catalog exists; inspects an existing catalog without writes unless you explicitly request maintenance. |

Whiteboard stops before implementation. Execute, Simplify, and Orchestrate start only on an authorized
change request; planning is not a prerequisite for a bounded task with settled decisions. Simplify
does not require Execute; commits and PRs remain opt-in, and each skill performs its own requested
delivery with its bundled procedures. Init separately owns requested project
guidance, not application scaffolding.

See the [workflow maps](apps/docs/content/docs/concepts/workflows.mdx) for the full sequences.

For component-system work, follow [Create and maintain a design catalog](apps/docs/content/docs/guides/design-system.mdx).
Design System adapts to project components and design rules; incompatible products get an isolated
React catalog. The target owns the result without a Woostack or Git Stacks runtime dependency.
Use `/woostack-flow-layout` separately to arrange multi-step UI flows.

`woostack-design` now coordinates UI design using selected external skills. The previous
screen-flow arrangement workflow is available as `woostack-flow-layout`.

## Review and check your work

| What you need | Tool |
| --- | --- |
| Investigate and address every unresolved review thread | [/woostack-address-comments](skills/woostack-address-comments/SKILL.md) |
| Explore a running web app and reproduce browser bugs | [/woostack-qa](skills/woostack-qa/SKILL.md) |
| Prove a root cause without implementing a correction | [/woostack-debug](skills/woostack-debug/SKILL.md) |
| Plan a proved defect as issues | [/woostack-whiteboard](skills/woostack-whiteboard/SKILL.md) |
| Find concrete improvements to instructions from this conversation | [/woostack-reflect](skills/woostack-reflect/SKILL.md) |

Pullfrog handles pull-request review. Address-comments can resolve the resulting GitHub threads;
QA remains report-only and does not fix source or post findings.

Reports help you decide what to do next. They do not expand the agreed scope or replace
Git/GitHub evidence. Agents never merge PRs; merging is a human decision.

## Contributing

Open a PR to improve a skill, correct guidance, or document a known problem. Read
[CONTRIBUTING.md](CONTRIBUTING.md) for the editing workflow, [ARCHITECTURE.md](ARCHITECTURE.md)
for component boundaries and source flows, and [AGENTS.md](AGENTS.md) for repository rules.

## Monorepo development

The pnpm workspace uses Turborepo to run the documentation app in `apps/docs/` and
the standalone catalog in `apps/design/`. Each app owns its dependencies; root
tooling includes Wrangler so default deployment commands resolve locally.
Installation uses the shared root `pnpm-lock.yaml`.

Run from the repository root with Node `>=22.12.0` and pnpm 12.10.1:

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm build
pnpm test
pnpm lint
pnpm lint:fix
pnpm format
pnpm format:check
pnpm verify
pnpm types:check
```

Root tasks use Turborepo's interactive TUI. Use Up/Down to select a task and inspect its
logs; `pnpm dev --ui=tui` explicitly selects the same UI.

To select one app while retaining Turborepo, use `pnpm dev --filter=docs` or
`pnpm dev --filter=design` (and the same filters for other root task commands).
Docs defaults to port 3000; the catalog defaults to port 5173. See the
[docs README](apps/docs/README.md) and
[catalog README](apps/design/README.md) for app-specific development guidance.

The docs build produces a deployable Cloudflare Worker and root Wrangler discovery
metadata. After building, `npx wrangler deploy` publishes the docs Worker and
`npx wrangler preview` deploys a branch Preview without promoting it to production.
Use `pnpm --filter docs run build:next` when only the Next.js output is needed.

`pnpm verify` runs the repository verification graph: docs tests, typechecking, Oxlint
and Oxfmt checks, plus catalog specimen and lint/format checks in `apps/design`, alongside
root script linting and root code/configuration formatting checks. Constituent checks are cached
and run non-redundantly: running `pnpm test`, `pnpm lint`, `pnpm format:check`, or `pnpm types:check`
caches those constituents so subsequent `pnpm verify` runs reuse them. App formatting checks track
changes to the shared root `.oxfmtrc.json`.
Use `pnpm verify --force` to execute all checks freshly, including nested docs and design checks.
Oxlint and Oxfmt provide repository-wide linting and code formatting, scoped to code and configuration
files while ignoring generated artifacts and historical skill prose. UI lint configs in `apps/docs/`
and `apps/design/` register `@shadcn/lint` via `jsPlugins` following upstream SETUP.md's conservative
registration-only guidance: no new persistent rules, presets, or overrides are enabled, leaving design
system policy decisions to user configuration. Theme and component settings are discovered independently
per app.

Repository caching isolates each checkout via `cacheDir: ".turbo/cache"` in `turbo.json`
to prevent cross-worktree cache sharing and foreign absolute path leaks in build/typecheck
outputs. Cache keys track the active Node version and architecture via `TURBO_RUNTIME_HASH`
passed by `scripts/turbo.mjs` and declared in `globalEnv`, so changing the active Node runtime
invalidates tasks deterministically.

`pnpm-workspace.yaml` permits only the reviewed native build scripts for esbuild and
Sharp. Exact release-age exceptions retain the selected Turborepo release and two
previously verified design dependencies; the general supply-chain checks remain enabled.

## Spec version

`2.0.0`

For older installations, see [upgrading from a pre-cutover release](apps/docs/content/docs/concepts/workflows.mdx#upgrading-from-a-pre-cutover-release).

## License

[MIT](LICENSE) &copy; Adam Woo
