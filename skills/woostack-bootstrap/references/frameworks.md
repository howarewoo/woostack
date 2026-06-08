# Frameworks & Dependency Versioning

This document outlines the protocol for selecting framework versions dynamically and maintaining dependency catalogs in monorepos.

## Registry-based version lookup

AI agents must **never** resolve dependency versions from training memory. All versions must be resolved live at bootstrap time using standard registry query commands.

1. **JavaScript/TypeScript (npm)**: Use `npm view <pkg> version` to query the latest stable version, or `npm view <pkg> dist-tags` to view tags (like `latest`, `next`, `beta`).
2. **Python (pypi)**: Use `curl -s https://pypi.org/pypi/<pkg>/json | jq -r .info.version` or pip tools.
3. **Rust (crates.io)**: Use `cargo search <pkg>` or query the crates.io API.
4. **Go**: Use `go list -m -versions <module>` or query proxy.golang.org.

---

## Dependency Cataloging Protocol

To prevent dependency drift across multiple apps and packages in the monorepo, utilize a unified dependency catalog (such as pnpm catalogs).

1. **Exact Matching**: Write resolved versions as exact strings (e.g., `1.2.3`), rather than ranges (e.g., `^1.2.3`), to ensure deterministic builds.
2. **Unified Catalog**: Define all shared dependencies in a single global catalog location (e.g., `pnpm-workspace.yaml` `catalog:` block). Individual packages reference these catalog dependencies using a placeholder (e.g., `"catalog:"`).
3. **Lifecycle Script Permissions**: For package managers like pnpm 10 that disable lifecycle scripts by default, explicitly enable execution for required native modules (e.g. via `pnpm.onlyBuiltDependencies` in `package.json`).

---

## Universal Gotchas & Safeguards

When composing a dependency stack dynamically:

- **Peer Dependency Alignment**: Check for peer dependency warnings during install. If framework A depends on React v18, do not install React v19 at the root catalog. Run registry checks on A's peer constraints before locking in React's version.
- **Monorepo Workspace Mappings**: Verify that local monorepo packages (e.g., `@infrastructure/db-client`) are resolved from the workspace rather than trying to fetch them from external registries.
- **Native Module Constraints**: Mobile, desktop, or edge-compute platforms may restrict native binary dependencies. Ensure any chosen packages do not violate target runtime limitations.
