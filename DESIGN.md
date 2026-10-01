# Design

## Workflow interaction

Inspect repository evidence before asking questions. Ask only about material unresolved choices,
preserve user decisions, and keep the requested action separate from contextual evidence.
The [command router](skills/using-woostack/SKILL.md) owns routing and authorization semantics;
individual skills own workflow steps and approval gates.
New-project planning and bounded creation belong to Plan and Execute by requested intent.
Neither requires the other or Init; Init remains the owner of requested project guidance.
Execute owns reusable implementation standards, loaded only for relevant changes.

Report observed outcomes and blockers. Distinguish verified facts from inference. Git and GitHub evidence establish
delivery; issue status and agent reports do not. The
[building rules](site/content/docs/concepts/building-rules.mdx) explain these authority boundaries.
The [output discipline](skills/using-woostack/references/output-discipline.md) owns communication
conventions.

## Canonical sources

Skill behavior belongs in the owning `skills/<name>/SKILL.md` and its supporting assets.
Link to canonical contracts instead of duplicating them. Simplify existing instructions before
adding new layers, while preserving independent safety checks. The
[contributor guide](CONTRIBUTING.md) owns the detailed change map and instruction-review criteria.

Public skill names and paths are installed interfaces. Changes to them require explicit approval
under [AGENTS.md](AGENTS.md). Preserve retained records as historical user data; they cannot authorize work.

## Documentation surface

The documentation application uses Next.js and Fumadocs. Authored guides live in
`site/content/docs/`; skill references are generated from `skills/*/SKILL.md` during development
and builds. Edit the source, not generated pages. The [site README](site/README.md) owns development,
generation, and deployment instructions.

Keep tutorials, how-to guides, reference, and explanation separate. Preserve the existing
information architecture and use plain, direct prose, as defined in
[site/AGENTS.md](site/AGENTS.md). Site changes follow those scoped instructions.

Read [PRODUCT.md](PRODUCT.md) for current product scope.
