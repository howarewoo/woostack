# Bootstrap Procedure

How an AI agent (or human) uses this spec to spin up a new project. The agent dynamically gathers requirements, researches the stack, and fills in the latest framework versions.

## Inputs the agent needs

The skill is invoked as `/woostack-bootstrap <goal>` — a plain-language description of what to build. Derive the project name and potential surfaces from the goal, then run the requirements questionnaire (defined in [decisions.md](decisions.md)) to finalize:

1. **Project name** (used for repo, root config, default app names).
2. **Surfaces required** — e.g. frontend web, backend API, mobile app, background processing worker.
3. **Selected Stack Option** — the chosen frameworks, databases, auth, and hosting providers.
4. **Initial features** — list of feature names to scaffold (e.g. `recipes`, `users`). Can be empty.

---

## Steps

### 0. Interpret the goal, then confirm decisions with the user
Follow the protocol in [decisions.md](decisions.md) to gather requirements, perform live lookup, present options, and get explicit user approval. **Do not scaffold any decision the user has not confirmed.**

### 1. Read the reference files
Load these files into context first:
- [architecture.md](architecture.md)
- [frameworks.md](frameworks.md)
- [infrastructure.md](infrastructure.md)
- [patterns.md](patterns.md)
- [development.md](development.md)

### 2. Resolve framework versions
**Always query the registry live — never use a version from memory.** 
For every dependency needed for the selected stack:
1. Query the latest version from the registry (e.g., `npm view <pkg> version` for Node, or equivalent commands for other runtimes).
2. Write the exact resolved versions into the monorepo's shared catalog/workspace configuration.

### 3. Create repo skeleton
Create a standard monorepo folder layout matching [architecture.md](architecture.md), omitting folders for surfaces not requested:
```
<project>/
├── apps/                     # only the surfaces requested
├── packages/
│   ├── features/             # one dir per requested feature
│   └── infrastructure/       # wrapper packages for DB, auth, logging, client, etc.
├── .github/workflows/ci.yml
├── .gitignore
├── package.json              # root scripts only
├── pnpm-workspace.yaml       # workspaces + catalog (or language equivalent)
└── turbo.json
```

### 4. Configure root tooling
Set up workspace configuration files based on the chosen technologies:
- **Build Orchestrator**: Configure `turbo.json` with pipeline tasks (`build`, `test`, `lint`, etc.).
- **Formatting/Linting**: Install and configure Biome (or equivalent for other language ecosystems) at the root level.
- **Gitignore**: Add a `.gitignore` that covers dependencies, caches, builds, and local `.env` files.

### 5. Scaffold infrastructure packages
For each required capability (Database client, Auth client, API client, Observability logger, Feature flags), create a wrapper package under `packages/infrastructure/` (e.g., `@infrastructure/db-client`, `@infrastructure/auth`). This encapsulates the vendor-specific SDK so features do not import them directly.
Each package should contain:
1. Native package manifest with `name`, exports, and entry point.
2. Code wrapping the chosen SDK, exposing clean interfaces to features.

### 6. Scaffold apps
Determine the exact CLI bootstrap commands for the chosen stack (e.g., `npx create-next-app` for Next.js, `cargo new --bin` for Rust, `django-admin startproject` for Django, `uv init` for Python). 
- Run the CLI tools in non-interactive mode inside the `apps/` subdirectories.
- Strip away generated visual boilerplates, replacing them with minimal landing/health-check entry points.
- Map the apps to the root workspace config.

### 7. Scaffold features (if any)
For each initial feature in the inputs, create a directory under `packages/features/<feature>/`. 
Organize code into clean sub-layers representing contracts, procedures/services, schemas, layouts, and components. Wire feature entry points into the main routing/API app.

### 8. Configure CI/CD
Write a generalized GitHub Actions configuration `.github/workflows/ci.yml` that triggers on pull requests targeting the integration branches. The workflow should checkout the code, install dependencies, run lints/formatters, run tests, and verify the build pipeline.

### 9. Verify
Run the validation scripts to confirm the workspace is operational:
- Install all dependencies.
- Run typecheckers, formatters, and linters.
- Build the entire monorepo.
- Run tests.
- Boot the applications in development mode and verify health checks/ports.

### 10. Initialize workspace
Initialize git, run `/woostack-init` to set up the `.woostack/` workspace (memory store, specs, plans, config) so that subsequent agent sessions can run status, execute, and review tasks seamlessly. Commit the initial skeleton and push to the remote host.

### 11. Hand off
Write a project-local `README.md` recording:
- Scaffolded apps and packages.
- Final stack decisions and why they were chosen.
- Verification commands and dev instructions.
