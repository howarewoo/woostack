# Design

## Workflow interaction

Inspect repository evidence before asking questions. Ask only about material unresolved choices,
preserve user decisions, and keep the requested action separate from contextual evidence.
Init's guided document authoring additionally consults on repository intention, structure,
direction, and architecture before drafting, per
[Init](skills/woostack-init/SKILL.md#guided-authoring); the rule above remains the default for the
other workflows.
Each skill owns its activation, routing, workflow steps, and approval gates; the
[command router](skills/using-woostack/SKILL.md) is an optional index and adoption aid that names
public commands and imposes no activation prerequisite. No skill loads, invokes, or requires a
sibling Woostack workflow. [Design's external-skill exception](CONTRIBUTING.md#external-design-skills)
leaves that boundary intact; optional navigation never becomes an executable dependency.
Shared procedures are reused through
[bundled references](CONTRIBUTING.md#shared-canonical-references) maintained from one canonical
source, so the active workflow keeps its own gates and evidence rules at every boundary.
Whiteboard is the experimental collaborative planning entry point for goals needing refinement,
including new projects. It develops shared understanding through requirements, design walkthroughs,
and a visual model kept consistent with one portable plan. Ideate, Harden, and Plan remain
available during the trial, with issue publication still owned by Plan. Bounded creation belongs
to Execute. These workflows require neither one another nor Init; Init owns project guidance.
Saving a Whiteboard plan does not start implementation; an explicit Orchestrate request selects
the plan as input to its separately approved execution proposal.
Execute and the other implementing skills bundle the applicable shared standards and load them
only for relevant changes.
Design coordinates UI work using a selected external lead and relevant specialists, with agreement
before consequential design changes. Flow Layout arranges existing screen frames without redesigning
them. Design System owns project component catalogs; a catalog's components, tokens, examples,
coverage record, and rules belong to the target project.
Existing compatible APIs stay intact, with adaptations at catalog callers. Existing-catalog
inspection is read-only unless maintenance is explicitly requested.

Report observed outcomes and blockers. Distinguish verified facts from inference. Git and GitHub evidence establish
delivery; issue status and agent reports do not. The
[building rules](apps/docs/content/docs/concepts/building-rules.mdx) explain these authority boundaries.
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
