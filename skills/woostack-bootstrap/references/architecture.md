# Architecture & Code Placement

Reference layout for new projects bootstrapped from this spec. Application code starts in the
deployable app that owns it. A package is created only when code must be shared across apps.

## Layout

Use the selected framework's native structure inside each deployable app:

```text
<project-root>/
├── apps/                      Deployable units (unscoped names, e.g. web, api, worker)
│   └── <app>/
│       └── src/
│           ├── contracts/    App-owned API and I/O contracts, when needed
│           ├── services/     App-owned business logic and handlers, when needed
│           ├── components/   App-owned UI, when needed
│           ├── layouts/      App-owned layouts, when needed
│           └── schemas/      App-owned validation schemas, when needed
└── packages/                 Code genuinely shared by multiple apps; omit when unused
    └── <shared-capability>/
```

## App-local first

- Put new code in the owning app and follow that framework's existing directory conventions.
- Extract code to `packages/<shared-capability>` only when multiple apps need the same
  implementation or contract.
- Name an extracted package for the capability it shares.
- After extraction, keep one shared implementation and have each consuming app import it instead
  of retaining app-local copies.
- Empty directories and unused `packages/` directories are omitted.

## Multi-language repositories

If requirements call for multiple programming languages:

1. Place each deployable service in `apps/<name>` and follow its language and framework conventions.
2. Keep dependencies scoped to each app or shared package through its native package manager, such
   as Cargo for Rust, Go modules for Go, and uv or Poetry for Python.
3. Use root task orchestration only when it simplifies real cross-app commands; do not add wrapper
   manifests solely to make unlike ecosystems look uniform.
4. When multiple apps need a shared cross-language contract, use a language-agnostic specification
   such as OpenAPI, Protocol Buffers, or JSON Schema.

## App internal structure

Within an app, group code by the roles its framework and product need. Empty directories are
omitted.

- `contracts/`: Typed interfaces and I/O validation schemas.
- `services/`: Business logic, database queries, and handlers.
- `components/`: App-owned UI components.
- `layouts/`: App-owned layout shells.
- `schemas/`: Internal validation schemas.

Prefer the selected framework's native convention when it already provides one.
