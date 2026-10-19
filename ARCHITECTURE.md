# Architecture

Woostack publishes independently installable coding-agent skills, with two supporting
applications. This overview maps the implemented repository; [DESIGN.md](DESIGN.md)
remains the owner of workflow interaction and source-ownership principles.
[CONTRIBUTING.md](CONTRIBUTING.md#what-to-change) provides the detailed change map.

## Skills and shared assets

Each `skills/<name>/SKILL.md` owns a public workflow, with supporting references,
scripts, and templates inside the same skill directory. The host assistant follows
these instructions; the documentation site and source checkout are not runtime
prerequisites. [using-woostack](skills/using-woostack/SKILL.md#command-routing) is an
optional command index, not a workflow dependency.

Reusable assets are authored in `shared/references/`, `shared/scripts/`, and
`shared/templates/`. [shared/mapping.json](shared/mapping.json) maps each canonical
file to consuming skills. [shared/sync.mjs](shared/sync.mjs) projects byte-identical
copies into matching skill-local paths, including transitively needed assets.
Installed skills therefore carry their own procedures without loading sibling
workflows. The synchronizer uses the documentation app's
[asset validator](apps/docs/scripts/skill-assets.mjs) to check bundle integrity;
that repository maintenance dependency is not an installed-skill dependency.

Edit shared sources rather than projected copies. The
[bundle contract](CONTRIBUTING.md#shared-canonical-references) owns synchronization
commands and consistency requirements. Skill-specific assets remain with their owner.

## Documentation application

[apps/docs/](apps/docs/README.md) is the Next.js and Fumadocs application.
Authored guides live in `apps/docs/content/docs/`. Its
[generator](apps/docs/scripts/gen-skills.mjs) validates the skill collection, reads
skill frontmatter and bodies, transforms agent markup and links, and writes MDX
pages and navigation under `apps/docs/content/docs/skills/`.

The app's development and build entrypoints run generation before Next.js.
Generated skill pages are ignored by Git: edit the owning skill, not its rendered
page. Builds need access to the repository-level `skills/` directory. App-specific
commands and deployment requirements stay in the docs README.

## Component catalog

[apps/design/](apps/design/README.md) is a separate React, TypeScript, and Vite
application, not a documentation route or skill runtime. Its `src/App.tsx` owns
catalog chrome and navigation; `src/examples/` owns specimens, `src/components/ui/`
owns UI controls, and `src/styles.css` owns tokens. `src/inventory.json` records the
baseline and project extensions. The catalog README owns provenance and maintenance
rules; the app owns its own source and is not generated from skill assets at runtime.

## Workspace and verification boundaries

The root [package.json](package.json), [pnpm workspace](pnpm-workspace.yaml), and
[turbo.json](turbo.json) coordinate app tasks with one root lockfile. Each app owns
its dependencies, source, and build configuration. [scripts/turbo.mjs](scripts/turbo.mjs)
adds the active Node/platform/architecture identity to task cache keys; Turborepo
keeps cache files within the checkout.

Deterministic generator, asset, and projection tests live in `apps/docs/scripts/`;
workspace-runner tests live in `scripts/`. These checks do not establish that a
host assistant followed a workflow. [AGENTS.md](AGENTS.md#validation) owns conditional
verification, including separate workflow smoke recipes. The shipped
[Pullfrog workflow](.github/workflows/pullfrog.yml) runs review agents, not a repository
test pipeline.

Configuration, publication, and retained-data changes follow the canonical
[artifact contract](shared/references/artifact-backends.md). Product scope belongs
in [PRODUCT.md](PRODUCT.md); permissions and delivery rules remain in
[AGENTS.md](AGENTS.md), not this orientation.
