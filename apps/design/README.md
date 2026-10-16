# Design app

Project-owned React, TypeScript, and Vite component catalog using neutral shadcn Base UI foundations. The baseline contains 66 live entries: 64 upstream entries and two owned foundations. Project extensions remain separately recorded in `src/inventory.json`.

## Run

Requires Node `^20.19.0 || >=22.12.0` and pnpm 12.10.1. Run from the repository root:

```sh
pnpm install --frozen-lockfile
pnpm dev --filter=design
pnpm lint --filter=design
pnpm format:check --filter=design
pnpm verify --filter=design
pnpm build --filter=design
pnpm --filter design preview
```

The development server prints its local URL. Component URLs use stable hashes, for example `/#dialog`. Search accepts component names and groups. Arrow keys, Home, and End move between navigation links. Slash focuses search on desktop and opens the finder on mobile; it does not intercept text editing. Ctrl/Command-K opens the finder. Appearance supports system, light, and dark themes.

Each specimen is rendered from the same source shown by Copy example. Copy requires browser clipboard permission and a secure context; denied permission produces a manual-copy recovery message.

## Ownership and provenance

Created from the installed `woostack-design-system/templates/` skill assets, not from the Woostack source checkout. Inventory version 1 and its full baseline are retained. See `LICENSE` for MIT notices.

- Git Stacks source reference: `ee6bbcb012965780643856b01bfd1c15502780d8`, following earlier baseline `3a74ae5f211eed502967f7247a8c27b340ec554d`.
- shadcn example reference: `30a58d4498f270af1c1e981a7d78a15cf5740841`.
- Canonical guidance: https://ui.shadcn.com/docs/components.
- Controls were generated locally by shadcn 4.21.4 using the `base-nova` Base UI registry configuration. All 61 non-null registry selections were derived from the inventory. No overwrite or CLI initialization was used.
- No existing project controls were available to reuse. Generated controls serve both specimens and catalog chrome. Owned DatePicker, DataTable, and Typography recipes remain in `src/catalog/`.
- Neutral semantic tokens and system typography are catalog-owned. No Git Stacks branding or application UI was migrated.

Dependencies were selected from the authoritative npm registry on 2026-10-13. The shared root `pnpm-lock.yaml` records the workspace graph, replacing the original npm lockfile. Direct app selections were retained; four shared transitive snapshots use the documentation app's existing resolutions. Exact release-age exceptions for the already verified Lucide and Resizable Panels selections live in `pnpm-workspace.yaml`. React DayPicker 9.14.0 is retained for the calendar recipe's v9 class-name/component contract; TanStack Table v8 is retained for the owned table recipe. The shadcn CLI initially selected DayPicker's latest major; it was restored to the documented v9 contract before verification.

Edit `src/examples/` for specimens, `src/App.tsx` for chrome/navigation, and `src/styles.css` for tokens. Add project-specific specimens under `projectExtensions`; do not replace baseline entries with extensions. The app requires no Woostack, Git Stacks, shadcn CLI, or remote documentation access at runtime. Some illustrative specimen images use optional public URLs.

## Original standalone verification

- `npm run verify`: all 66 baseline specimens and public imports typechecked; zero extensions.
- `npm run build`: production build passed. Vite warned that the main bundle exceeds 500 kB; no warning threshold was suppressed.
- All 66 specimens rendered in Chromium without uncaught runtime errors.
- Browser checks covered matching/unmatched/cleared search, direct hashes, Back/Forward and reload, keyboard select, dialog and popover opening/dismissal, command-palette destination focus, light/dark themes, desktop and 390px mobile layouts, mobile navigation dismissal and heading focus, and source copying with exact clipboard comparison after explicit Chromium clipboard permission.
- Clipboard denial also exercised the manual-copy recovery message.
- Mechanical design inspection flagged the Typography blockquote's 3px inline-start border. It is an intentional content specimen treatment, retained rather than changing the canonical example.

These are local creation checks, not evidence for the skill's independent distribution, compatible-product, incompatible-product, or maintenance scenario fixtures. No Git initialization, branch, commit, push, PR, issue, or Woostack configuration was created.

## Workspace migration verification

The app now lives in `apps/design/` with package name `design`. Root Turborepo
commands use the interactive TUI; `pnpm dev --filter=design` selects this app.
The root frozen pnpm install passed. Root `pnpm verify` checked all 66 specimens
and public imports; `pnpm build` built both apps; the TUI typecheck task passed.
After migration, a browser opened the live dialog specimen at `/#dialog` and
exercised opening and Escape dismissal. The earlier full catalog browser pass
above remains standalone evidence, not a repeated workspace-wide interaction audit.

## Linting and formatting

Oxlint and Oxfmt provide linting and code formatting for the catalog. Oxlint configuration in
`.oxlintrc.json` registers `@shadcn/lint` via `jsPlugins` following upstream SETUP.md conservative
registration-only guidance: component and theme tokens are discovered automatically via `components.json`,
with no new rules or presets enabled. Configure custom rules or overrides under `.oxlintrc.json` as needed.
