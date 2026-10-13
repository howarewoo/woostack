# Catalog scaffold assets

These non-runnable assets recreate a project-owned React + TypeScript + Vite catalog.
They do not bundle a shadcn component library. The target generates its own controls
with the shadcn CLI. The canonical upstream guidance is
[shadcn components](https://ui.shadcn.com/docs/components); do not copy upstream
usage, anatomy, or keyboard documentation into a parallel reference.

## Recreate in an admitted empty target

Follow the skill's target-admission and compatibility contract first. Locate this
`templates/` directory inside the **installed skill**, not the Woostack checkout.
Copy its files preserving relative paths, stripping only a terminal `.template`
suffix. Keep README and LICENSE. There are no replacement placeholders.
Do not overwrite existing files. For a compatible existing UI, omit source creation
and adapt specimen/chrome imports to actual project APIs instead.

The copied `components.json` is an initialized shadcn configuration: `base-nova`,
Base UI, neutral tokens, Lucide icons, `@/components/ui` aliases. **Do not run init
again over these files.** For a separately created unconfigured Vite project, the
current CLI initialization command is `npx shadcn@latest init --template vite
--base base --preset nova --no-monorepo --no-reinstall`; inspect its changes before
adapting this scaffold rather than using `--force`.

From the target root with Node `^20.19.0 || >=22.12.0`:

```sh
npm install
npm exec -- shadcn add --yes $(node --input-type=module -e 'import fs from "node:fs"; const inventory=JSON.parse(fs.readFileSync("src/inventory.json","utf8")); console.log([...new Set(inventory.entries.map(entry=>entry.registryItem).filter(Boolean))].join(" "))')
# The registry's calendar dependency is tagged latest. Keep the recipe's v9 contract.
npm install react-day-picker@9.14.0
npm run verify
npm run build
npm run dev
```

The add arguments come from the canonical inventory, not a second hardcoded list.
Never use `--overwrite` for adoption or maintenance. The CLI downloads source once;
the catalog runs without Woostack, Git Stacks, or documentation-service access.
It may use public image URLs in illustrative specimens; those images are optional
visual content, not a dependency of component interactions. Preserve the generated
target lockfile, but never copy one back into skill assets.

`npm run verify` checks every inventory specimen and typechecks public imports,
including project extensions. `npm run build` typechecks and produces static assets.
`npm run dev` starts the local Vite server; use its printed URL, not an assumed port.
`npm run preview` serves the production output. Browser verification is separate:
search/empty results, anchors and Back/Forward, narrow navigation, Tab/arrows,
Ctrl/Command-K and slash, destination focus after overlay dismissal, appearance,
copy examples/imports, and representative popover/dialog/menu interactions.

Illustrative `href="#"` links select a local example link and report that selection
in a live status message; they do not change catalog routing or execute product
workflows such as account recovery. Genuine catalog and external guidance links
keep their destinations. Pagination uses local page/row-count state. The Sidebar
example contains its desktop fixed layout in a bounded preview while retaining
the generated component's native mobile sheet and toggle behavior.

## Ownership and adaptation

`src/inventory.json` is the single versioned coverage inventory: reference revision,
canonical upstream URL/provenance, shipped baseline and separate project extensions.
Its `registryItem` is the CLI source name or `null` for owned catalog recipes.
`specimen` identifies a `.tsx` file under `src/examples/` (including nested
directories) rendered live and displayed raw for copying; hidden paths are not supported.
`importPath`/`importExample` describe the real public import checked by verification.
Imports are checked unchanged in separate temporary modules beside their specimens,
so relative imports resolve from the specimen directory. Verification never overwrites
existing import-check files and removes only the temporary files it created.
Adding a project extension means adding its example and an entry under
`projectExtensions`; do not claim it as upstream coverage.

Catalog chrome uses the generated project Button, Input, Sidebar, Command, Tooltip,
and Sonner. Existing compatible implementations are reused at their public imports:
change callers and example state/composition, not the project component API.
For an incompatible or non-React product, keep this root isolated and do not add
React dependencies to the product manifest or change its framework.

Owned helpers under `src/catalog/` are narrow compositions: DatePicker is a
single-date controlled recipe; DataTable is a generic TanStack v8 sorting/pagination
recipe; Typography is an owned semantic content style wrapper. Typeset and
Iconography are owned foundations. None is advertised as a generated upstream API.

## Provenance and dependency constraints

Git Stacks reference `ee6bbcb012965780643856b01bfd1c15502780d8` was revalidated
against the issue's earlier `3a74ae5f211eed502967f7247a8c27b340ec554d` baseline.
Its catalog groups, full component coverage, live/raw-example concept and navigation
behavior informed this scaffold. Its owned control APIs, Quiet Workbench tokens,
Git compositions, desktop integrations, and component library were not copied.
The typography/iconography foundations remain owned, distinct from upstream entries.

Live upstream examples were inspected at shadcn revision
`30a58d4498f270af1c1e981a7d78a15cf5740841`; local import paths, named Lucide icons,
browser-native image/link wrappers and catalog wrappers replace website plumbing.
Selection examples add accessible names without changing the generated public APIs.
Message and Message Scroller are local controlled conversation examples instead of
AI transports. MIT notices are retained in source and LICENSE (Adam Woo, shadcn).

Dependency selections were resolved on 2026-10-13 from the authoritative npm
registry (`https://registry.npmjs.org/<package>`). Resolve selections again when
actually adapting to a target; preserve compatible installed dependencies and
lockfiles. The shipped versions are reproducible scaffold selections, not mandates
for existing products. Vite's Node requirement comes from its registry `engines`.
DayPicker v9 is retained for the shipped calendar recipe's class-name and component
contracts (latest v10 is a separate major). TanStack v8 is intentional for the owned
DataTable recipe's `useReactTable`/row-model API; do not copy the reference's v9-owned
adaptation or silently move this recipe to v9. Recharts source uses its v3 recipe,
not the reference's v2 dependency. Generated controls must be inspected/typechecked
when the live registry changes; report incompatible API drift instead of silently
replacing existing project controls.

## Required assets

Every required scaffold source/configuration asset is linked below so installed
skill asset validation can prove availability outside this checkout.

- [.gitignore.template](.gitignore.template)
- [LICENSE.template](LICENSE.template)
- [components.json.template](components.json.template)
- [index.html.template](index.html.template)
- [package.json.template](package.json.template)
- [scripts/check-catalog.mjs.template](scripts/check-catalog.mjs.template)
- [src/App.tsx.template](src/App.tsx.template)
- [src/catalog/data-table.tsx.template](src/catalog/data-table.tsx.template)
- [src/catalog/date-picker.tsx.template](src/catalog/date-picker.tsx.template)
- [src/catalog/typography.tsx.template](src/catalog/typography.tsx.template)
- [src/components/example.tsx.template](src/components/example.tsx.template)
- [src/examples/accordion.tsx.template](src/examples/accordion.tsx.template)
- [src/examples/alert-dialog.tsx.template](src/examples/alert-dialog.tsx.template)
- [src/examples/alert.tsx.template](src/examples/alert.tsx.template)
- [src/examples/aspect-ratio.tsx.template](src/examples/aspect-ratio.tsx.template)
- [src/examples/attachment.tsx.template](src/examples/attachment.tsx.template)
- [src/examples/avatar.tsx.template](src/examples/avatar.tsx.template)
- [src/examples/badge.tsx.template](src/examples/badge.tsx.template)
- [src/examples/breadcrumb.tsx.template](src/examples/breadcrumb.tsx.template)
- [src/examples/bubble.tsx.template](src/examples/bubble.tsx.template)
- [src/examples/button-group.tsx.template](src/examples/button-group.tsx.template)
- [src/examples/button.tsx.template](src/examples/button.tsx.template)
- [src/examples/calendar.tsx.template](src/examples/calendar.tsx.template)
- [src/examples/card.tsx.template](src/examples/card.tsx.template)
- [src/examples/carousel.tsx.template](src/examples/carousel.tsx.template)
- [src/examples/chart.tsx.template](src/examples/chart.tsx.template)
- [src/examples/checkbox.tsx.template](src/examples/checkbox.tsx.template)
- [src/examples/collapsible.tsx.template](src/examples/collapsible.tsx.template)
- [src/examples/combobox.tsx.template](src/examples/combobox.tsx.template)
- [src/examples/command.tsx.template](src/examples/command.tsx.template)
- [src/examples/context-menu.tsx.template](src/examples/context-menu.tsx.template)
- [src/examples/data-table.tsx.template](src/examples/data-table.tsx.template)
- [src/examples/date-picker.tsx.template](src/examples/date-picker.tsx.template)
- [src/examples/dialog.tsx.template](src/examples/dialog.tsx.template)
- [src/examples/direction.tsx.template](src/examples/direction.tsx.template)
- [src/examples/drawer.tsx.template](src/examples/drawer.tsx.template)
- [src/examples/dropdown-menu.tsx.template](src/examples/dropdown-menu.tsx.template)
- [src/examples/empty.tsx.template](src/examples/empty.tsx.template)
- [src/examples/field.tsx.template](src/examples/field.tsx.template)
- [src/examples/hover-card.tsx.template](src/examples/hover-card.tsx.template)
- [src/examples/iconography.tsx.template](src/examples/iconography.tsx.template)
- [src/examples/input-group.tsx.template](src/examples/input-group.tsx.template)
- [src/examples/input-otp.tsx.template](src/examples/input-otp.tsx.template)
- [src/examples/input.tsx.template](src/examples/input.tsx.template)
- [src/examples/item.tsx.template](src/examples/item.tsx.template)
- [src/examples/kbd.tsx.template](src/examples/kbd.tsx.template)
- [src/examples/label.tsx.template](src/examples/label.tsx.template)
- [src/examples/marker.tsx.template](src/examples/marker.tsx.template)
- [src/examples/menubar.tsx.template](src/examples/menubar.tsx.template)
- [src/examples/message-scroller.tsx.template](src/examples/message-scroller.tsx.template)
- [src/examples/message.tsx.template](src/examples/message.tsx.template)
- [src/examples/native-select.tsx.template](src/examples/native-select.tsx.template)
- [src/examples/navigation-menu.tsx.template](src/examples/navigation-menu.tsx.template)
- [src/examples/pagination.tsx.template](src/examples/pagination.tsx.template)
- [src/examples/popover.tsx.template](src/examples/popover.tsx.template)
- [src/examples/progress.tsx.template](src/examples/progress.tsx.template)
- [src/examples/questionnaire.tsx.template](src/examples/questionnaire.tsx.template)
- [src/examples/radio-group.tsx.template](src/examples/radio-group.tsx.template)
- [src/examples/resizable.tsx.template](src/examples/resizable.tsx.template)
- [src/examples/scroll-area.tsx.template](src/examples/scroll-area.tsx.template)
- [src/examples/select.tsx.template](src/examples/select.tsx.template)
- [src/examples/separator.tsx.template](src/examples/separator.tsx.template)
- [src/examples/sheet.tsx.template](src/examples/sheet.tsx.template)
- [src/examples/sidebar.tsx.template](src/examples/sidebar.tsx.template)
- [src/examples/skeleton.tsx.template](src/examples/skeleton.tsx.template)
- [src/examples/slider.tsx.template](src/examples/slider.tsx.template)
- [src/examples/spinner.tsx.template](src/examples/spinner.tsx.template)
- [src/examples/switch.tsx.template](src/examples/switch.tsx.template)
- [src/examples/table.tsx.template](src/examples/table.tsx.template)
- [src/examples/tabs.tsx.template](src/examples/tabs.tsx.template)
- [src/examples/textarea.tsx.template](src/examples/textarea.tsx.template)
- [src/examples/toast.tsx.template](src/examples/toast.tsx.template)
- [src/examples/toggle-group.tsx.template](src/examples/toggle-group.tsx.template)
- [src/examples/toggle.tsx.template](src/examples/toggle.tsx.template)
- [src/examples/tooltip.tsx.template](src/examples/tooltip.tsx.template)
- [src/examples/typeset.tsx.template](src/examples/typeset.tsx.template)
- [src/examples/typography.tsx.template](src/examples/typography.tsx.template)
- [src/inventory.json.template](src/inventory.json.template)
- [src/main.tsx.template](src/main.tsx.template)
- [src/styles.css.template](src/styles.css.template)
- [src/vite-env.d.ts.template](src/vite-env.d.ts.template)
- [tsconfig.json.template](tsconfig.json.template)
- [vite.config.ts.template](vite.config.ts.template)
