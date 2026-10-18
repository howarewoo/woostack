---
name: woostack-design-system
description: Use when asked to create a project-adapted design system and component catalog, inspect an existing catalog for gaps or drift, or explicitly add, repair, or update selected catalog content.
---

# woostack-design-system

Create a working, project-owned component catalog from the versioned assets shipped with this
skill. Use the [shadcn component documentation](https://ui.shadcn.com/docs/components) for canonical
upstream guidance; the shipped inventory defines reproducible catalog coverage, not copied upstream
documentation. This command owns component-system creation;
arranging multi-step flows is the separate woostack-design layout standard, unchanged here.

## Command and authorization

```text
/woostack-design-system
/woostack-design-system inspect the existing catalog
/woostack-design-system add a date-range specimen
/woostack-design-system repair catalog keyboard navigation
/woostack-design-system update the catalog's typography examples
```

| Repository state and request | Authorized operation |
| --- | --- |
| No catalog; ordinary invocation | Bounded local creation, necessary catalog dependency/configuration changes, and verification |
| Existing catalog; ordinary invocation or inspection | Read-only gap/drift report; no source, configuration, dependency, lockfile, or generated-file writes |
| Explicit add, repair, or update | Only the named maintenance scope and its necessary verification |

Inspect first; an undocumented catalog still counts as existing. A component library without a
catalog does not prevent creation, but its compatible controls must be reused. Explicit read-only
or local-only limits take precedence. Never create branches, commit, push, publish PRs/issues,
mutate Projects, initialize Woostack configuration, or migrate product UI automatically.

## Inspect and choose placement

Read repository instructions, design rules, manifests, lockfiles, public UI exports and their
callers, styles/tokens, existing catalogs and verification commands. Preserve unrelated work.
Use bundled [implementation patterns](references/patterns.md)
and [testing guidance](references/tdd.md); reading these invokes no
other workflow and authorizes no implementation.

Apply [compatibility](references/compatibility.md) to actual imports, props, composition, style
setup and dependencies. Choose repository-native catalog placement, not a copied workspace path.
Reuse compatible controls in both specimens and navigation/chrome. Adapt catalog callers to their
public APIs; do not rewrite existing components to fit the starter. For incompatible or non-React
products, use an isolated React catalog whose dependencies and configuration do not alter the
product's framework, runtime dependency set or behavior.

If a catalog exists and maintenance was not requested, stop before installation or generation.
Report its location, observed coverage, API/style compatibility, provenance, interaction gaps,
and concrete scoped repair options. Distinguish inspected facts from unverified runtime behavior.

## Create or maintain locally

Follow [adaptation and recreation](references/adaptation.md) using the assets next to the
**installed** `SKILL.md`, not a Woostack checkout or a runtime fetch from Git Stacks. Templates
are minimal catalog-specific inputs, not a bundled UI library or completed implementation. The
versioned canonical inventory defines full baseline coverage and provenance; retain it and keep
project extensions separate.

Respect project tokens, typography and design rules. Without rules, use the neutral shadcn
baseline, not Git Stacks branding or Quiet Workbench styling. Source newly needed, inventory-selected
controls through the current shadcn CLI using Base UI; never CLI-overwrite existing UI or initialize
over custom setup. Compatible existing primitives are reused, not migrated. Creation may require
CLI network access; the resulting catalog has no remote-source requirement at runtime.
Resolve only newly selected dependencies from authoritative registries under the bundled
[dependency guidance](references/patterns.md#6-dependencies-resolution-ownership-and-integrity).

Do not overwrite custom components, tokens, examples, rules or unrelated work. Compare before
changing existing destinations. Report a conflict and leave the conflicting surface unchanged;
complete independent in-scope work without silently substituting a duplicate implementation.
Maintenance is not permission to regenerate the catalog or upgrade unrelated dependencies.

## Verify and report

Use [verification](references/verification.md) and the target's native commands. Verify real
imports, complete declared baseline coverage, live specimens, and actual browser behavior; a
placeholder catalog, successful source copy, typecheck alone, or site packaging check is not
recreation. Leave no mock controls, dead specimens or unsupported "complete" claims.

Report catalog placement and commands, template/baseline provenance, reused versus newly created
controls, design adaptations, preserved customizations, conflicts, and checks actually observed.
Separate deterministic checks, installed-skill/host outcomes and browser evidence. Failed or unrun
required checks remain unverified; name the missing prerequisite and do not claim completion.
Local verified changes are the endpoint; publication requires a separate user request.
