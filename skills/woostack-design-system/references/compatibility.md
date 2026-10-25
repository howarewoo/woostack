# Compatibility and preservation

React, shadcn provenance, similar filenames and screenshots are not compatibility evidence.
Inspect the public contract and a real consumer before choosing reuse. Follow the bundled
[placement and API guidance](patterns.md), not a new framework
migration workflow.

## Inspection record

For each control needed by a specimen or catalog chrome, record:
| Evidence | What to inspect |
| --- | --- |
| Public import | Exported module/package, aliases, package exports, supported client/server boundary; no private product source imports |
| Props and events | Required props, variants, controlled/uncontrolled state, event signatures, disabled/loading semantics, ref support |
| Composition | Trigger/content ownership, portals/providers, render/slot/child contracts, nested controls, focus and dismissal behavior |
| Styling | Token names and values, theme selector, CSS order, utility generation/content discovery, fonts, icons and responsive rules |
| Dependencies | Installed versions, peer ranges, supported runtime, workspace resolution and lockfile; dependencies needed by imported shared code |
| Consumer evidence | At least one real use of the public API and applicable tests; source declarations alone do not prove interaction behavior |

Necessary custom catalog chrome is a consumer too: inspect its controls alongside specimens and
reuse compatible public UI. Storybook's manager is tooling UI, not a duplicate product component;
do not rebuild its navigation or search with project controls merely to satisfy reuse.

## Choose the smallest supported integration

1. **Compatible shared UI:** import actual public components and tokens into stories/specimens and
   any necessary custom chrome. Adapt callers to the project's props and composition. Remove
   obsolete task-owned generated controls and imports; do not leave a second Button, Input or
   overlay merely because its API is familiar.
   Describe project API adaptations as owned examples, not upstream shadcn defaults.
2. **Partially compatible UI:** reuse supported controls and create only genuinely missing controls
   within the repository's UI owner using the current Base UI-backed shadcn CLI. Assess each component,
   not the library as a whole. Never run CLI initialization over custom setup or use overwrite flags
   on existing components. If a required composition cannot be implemented without changing a
   published component contract, report that boundary rather than silently changing the API or
   duplicating the control.
3. **Framework boundary:** prefer a supported native Storybook integration when it can render the
   project's real public controls; a non-React product alone does not require a React replica.
   Tooling support does not make React/shadcn controls compatible with another framework. When
   the required controls cannot run natively, put the React catalog in its own unit and manifest.
   Keep product source, framework and runtime dependencies unchanged; label catalog-only examples
   accurately. Do not import framework-specific private components into React or claim replicas
   are native controls. A workspace lockfile may record catalog dependencies where native policy
   requires it; preserve unrelated entries and verify the product dependency graph is unchanged.

An isolated catalog may represent product tokens and guidance without claiming framework-native
control integration. It must still run and cover the declared coverage. Do not add a package-manager
workspace or root build system merely to host one catalog if a native independent unit suffices.

## Conflicts and explicit maintenance

Inventory existing catalogs across routes, packages, examples and documentation before selecting
creation. Ordinary existing-catalog invocation is read-only: no dependency install, lockfile touch,
formatting, code generation, snapshot update or browser action that persists project state.

For explicit maintenance, identify exact affected owners and callers before editing. Preserve
custom labels, variants, state examples, navigation IDs, token values, theme conventions and design
rules outside the authorized change. A mismatch against the catalog's recorded provenance or agreed coverage is evidence of drift,
not permission to replace owned source. Report incompatible requests with the public API or design
constraint and the smallest viable scoped options. Do not hide conflicts by copying another control,
renaming the old one, suppressing type errors, or dropping required specimens.

Use focused behavioral coverage from the bundled
[testing guidance](tdd.md)
to prove reuse, untouched product behavior and preservation. Tests of instruction wording or a
mock copy of the adaptation logic do not prove these boundaries.
