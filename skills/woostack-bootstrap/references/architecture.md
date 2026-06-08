# Architecture & Package Slicing

Reference monorepo layout for new projects bootstrapped from this spec. AI agents must reproduce this structure.

## Layout

Regardless of the chosen programming languages or frameworks, the project must follow a clean separation between **Apps** (deployable units), **Features** (business logic packages), and **Infrastructure** (shared libraries and vendor SDK wrappers).

```
<project-root>/
├── apps/                      Deployable units (unscoped names, e.g., web, api, worker)
├── packages/
│   ├── features/              Business logic packages (one package per feature slice)
│   │   └── <feature>/
│   │       ├── src/
│   │       │   ├── contracts/     Clean API contracts (Zod, Protobuf, OpenAPISchema)
│   │       │   ├── services/      Business logic procedures and handlers
│   │       │   ├── components/    Feature-specific internal UI components
│   │       │   └── layouts/       Feature-specific layouts
│   │       ├── package.json
│   │       └── tsconfig.json
│   └── infrastructure/        Shared libraries and SDK wrappers
│       ├── db-client/         Database connector wrapper
│       ├── auth/              Authentication client wrapper
│       ├── observability/     Logging and error tracking
│       ├── ui/                Design tokens and global styling
│       └── utils/             Cross-platform helpers
```

---

## Package Tiers

The monorepo enforces three main tiers with strict import directions:

```
Apps  →  Features  →  Infrastructure
```

- **Apps** may import **Features** and **Infrastructure**.
- **Features** may import **Infrastructure** but *never* other Features or Apps.
- **Infrastructure** may import other Infrastructure libraries, but *never* Features or Apps.

| Tier | Path | Role | May Import |
|---|---|---|---|
| **Apps** | `apps/*` | Deployable apps (e.g., frontends, APIs, workers). | Features, Infrastructure |
| **Features** | `packages/features/*` | Core business logic separated by domain slice. | Infrastructure |
| **Infrastructure** | `packages/infrastructure/*` | Technical wrappers (e.g., DB clients, Auth SDKs, loggers). | Other Infrastructure |

---

## Multi-Language Monorepos

If a project's requirements dictate using multiple programming languages (e.g., a Next.js TypeScript frontend and a Python or Go API), follow this guidance for multi-language monorepos to maintain package boundaries:

1. **Service Placement**: Place JS/TS apps in `apps/` and packages in `packages/`. Non-JS/TS apps and shared feature libraries should be located in `apps/<name>` or `packages/features/<name>` respectively.
2. **Dependency Management**: Non-JS/TS folders manage their dependencies using their native package managers (e.g., `cargo` for Rust, `go mod` for Go, `uv` or `poetry` for Python). Do not try to force them into a single `package.json` catalog.
3. **Build Orchestration**: The root `turbo.json` configures Turborepo to orchestrate tasks across all languages. Wrap native commands inside root `package.json` scripts that Turborepo can target:
   - Example: A test task for a Python app runs `pytest`, which is invoked via a script in `apps/python-api/package.json` (`"test": "uv run pytest"`).
4. **API Contracts**: Use language-agnostic contract specifications (e.g., OpenAPI JSON, Protocol Buffers, or JSON Schema) to share types between frontend and backend.

---

## Feature Internal Structure

Each feature slice contains sub-directories grouping components by role. Empty directories are omitted.

- `contracts/`: Typed interfaces and I/O validation schemas (e.g. Zod schemas or OpenAPI specs).
- `services/`: Core business logic, database queries, and handlers (avoid putting raw DB queries directly in controllers/apps).
- `components/`: UI components used internally by the feature.
- `layouts/`: UI layouts used by the feature.
- `schemas/`: Domain-specific internal validation schemas.
