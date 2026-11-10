# Design

## Workflow interaction

Inspect repository evidence before asking questions. Resolve discoverable facts and routine technical
implementation details within authority; preserve user decisions and keep requested actions separate
from contextual evidence. Whiteboard tests solution-first requests against users, their current
workaround, and the desired improvement, considering removal, reuse, or a smaller alternative.
It leads with an evidence-backed direction and trade-offs, distinguishing product value assumptions
from technical feasibility without requiring a business case or experiment for every task.
Whiteboard resolves material ambiguity upfront, including consequential product behavior, acceptance,
permissions, data handling, compatibility, cost, and recovery. Minor observable details within agreed
behavior remain agent-owned; that distinction cannot bypass safety constraints. Reversibility
does not authorize a consequential choice. Its concrete walkthrough inspects material transitions
and relevant failure and recovery paths rather than requiring an exhaustive questionnaire.
Authorized host-supported read-only scouts may gather evidence; Whiteboard reconciles their findings
and owns user questions. Scouting grants no implementation, experiment, or publication authority.
Init's guided document authoring additionally consults on repository intention, structure,
direction, and architecture before drafting, per
[Init](skills/woostack-init/SKILL.md#guided-authoring); the rule above remains the default for the
other workflows.
Each skill owns its activation, routing, workflow steps, and approval gates; the
[command router](skills/using-woostack/SKILL.md) is an optional index and adoption aid that names
public commands and imposes no activation prerequisite. Skills require no sibling installation.
Orchestrate delegates approved outcomes to task owners, normally using installed Execute, while
retaining cross-task planning, capacity, integration acceptance, and delivery coordination.
Task owners choose implementation decomposition and specialist handoffs within inherited limits;
composition adds no user approval or publication authority. See the
[composition boundary](CONTRIBUTING.md#editing-conventions). Prototype may use
[optional design guidance](CONTRIBUTING.md#optional-design-guidance) without depending on it.
Shared procedures are reused through
[bundled references](CONTRIBUTING.md#shared-canonical-references) maintained from one canonical
source, so the active workflow keeps its own gates and evidence rules at every boundary.
Whiteboard is the planning entry point for people and delegated agents, including new projects.
It develops requirements, design walkthroughs, and a visual model consistent with one portable plan,
without requiring questions when context suffices. The plan carries requirements, acceptance,
settled decisions and rationale, material behavior, real dependencies, and precise unresolved
questions with owners and resolution conditions. A fresh Orchestrate session can propose execution
from that plan alone without inventing behavior or allocating blocked dependents; execution
grouping, allocation, and delivery stay with Orchestrate. Requirements-only exploration stops at the
requested depth without forcing a solution or delivery plan. Whiteboard also owns review-only
requests and explicit issue publication; Ideate, Plan, and Harden are retired.
Bounded creation belongs to Execute. These workflows require neither one another nor Init;
Init owns project guidance. Completing, saving, or publishing a Whiteboard plan does not start
implementation. Orchestrate preserves settled decisions and requires user approval by default;
explicit user delegation can authorize a named coordinator to validate covered execution decisions.
Roles, plans, and worker messages cannot grant authority, and uncovered consequential choices remain
undecided. During execution, park only affected work while independent authorized implementation,
required review, healthy checks, and eligible requested delivery continue. Nonblocking questions go
to the final handoff with affected acceptance, a recommendation, and a resume condition, not guessed
defaults. Workers escalate to the coordinator without host-blocking questions; an execution owner
asks a blocking user question only when the answer blocks all remaining useful authorized work.
An accurate blocked disposition is valid; unmet acceptance is never completion.
The same senior bot can plan and coordinate assignments to one existing junior using Execute.
Execute and the other implementing skills bundle the applicable shared standards and load them
only for relevant changes.
Prototype explores and refines interactive UI references outside the target project, which stays
read-only. For an existing product, bounded investigation anchors the proposal to affected owning
surfaces and behavior, not a whole-repository audit. Iteration keeps that baseline distinct from
prototype revisions; recoverable source checkpoints protect approved directions and risky changes.
Its portable handoff carries baseline provenance, preserved behavior, intentional differences, and
prototype evidence separately from required production acceptance tied to discovered surfaces and
tests. Greenfield work needs no existing-product baseline. Approval belongs to a snapshot and starts
neither planning nor implementation. External design guidance is optional. Flow Layout arranges
existing screen frames without redesigning them. Design System owns project component catalogs;
a catalog's components, tokens, examples,
coverage record, and rules belong to the target project.
Existing compatible APIs stay intact, with adaptations at catalog callers. Existing-catalog
inspection is read-only unless maintenance is explicitly requested.

Report observed outcomes and blockers. Distinguish verified facts from inference. Git and GitHub evidence establish
delivery; issue status and agent reports do not. The
[workflow explanation](apps/docs/content/docs/concepts/workflows.mdx#authority-boundaries) explains these authority boundaries.
The [output discipline](shared/references/output-discipline.md) owns communication
conventions.

## Canonical sources

Skill behavior belongs in the owning `skills/<name>/SKILL.md` and its supporting assets.
Reusable procedures are authored once in `shared/references/` and projected into each consuming
skill with `node shared/sync.mjs`; a `skills/<name>/references/` file that mirrors a shared path
is a generated copy, not a hand-editable source. Link to canonical contracts instead of
duplicating them. Simplify existing instructions before
adding new layers, while preserving independent safety checks. The
[contributor guide](CONTRIBUTING.md) owns the detailed change map and instruction-review criteria.

Public skill names and paths are installed interfaces. Changes to them require explicit approval
under [AGENTS.md](AGENTS.md). Preserve retained records as historical user data; they cannot authorize work.

## Application boundaries

The pnpm workspace contains the documentation app in `apps/docs/` and the standalone
component catalog in `apps/design/`. Each app owns its source, build configuration,
and dependency manifest. Root pnpm and Turborepo configuration orchestrate app tasks;
the root `pnpm-lock.yaml` is the shared dependency-resolution record.
The catalog remains a separate application rather than a documentation route.

## Documentation surface

The documentation application uses Next.js and Fumadocs. Authored guides live in
`apps/docs/content/docs/`; skill references are generated from `skills/*/SKILL.md` during development
and builds. Edit the source, not generated pages. The [docs README](apps/docs/README.md) owns app-specific
development, generation, and deployment instructions.

Keep tutorials, how-to guides, reference, and explanation separate. Preserve the existing
information architecture and use plain, direct prose, as defined in
[apps/docs/AGENTS.md](apps/docs/AGENTS.md). Documentation app changes follow those scoped instructions.

Read [PRODUCT.md](PRODUCT.md) for current product scope.
