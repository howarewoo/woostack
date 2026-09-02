# Frameworks & Dependency Versioning

This document defines dynamic framework-version selection and app-scoped dependency ownership.

## Registry-based version lookup

AI agents must **never** resolve dependency versions from training memory. Resolve every version
live at bootstrap time with the authoritative registry.

1. **JavaScript/TypeScript (npm)**: Use `npm view <pkg> version` for the latest stable version or
   `npm view <pkg> dist-tags` to inspect tags such as `latest`, `next`, or `beta`.
2. **Python (PyPI)**: Query the PyPI package metadata or use the selected Python package manager.
3. **Rust (crates.io)**: Use `cargo search <pkg>` or query the crates.io API.
4. **Go**: Use `go list -m -versions <module>` or query proxy.golang.org.

---

## App-scoped dependencies

1. **App ownership**: Declare each app's dependencies in that app's manifest.
2. **Shared-package ownership**: A shared package declares its own runtime, peer, and development
   dependencies.
3. **Root restraint**: Keep only genuine repository-wide tooling at the root.
4. **Lifecycle script permissions**: When a package manager disables lifecycle scripts by default,
   explicitly enable only the native modules that require them.

---

## Universal gotchas & safeguards

- **Peer dependency alignment**: Check peer warnings within each consuming app or package before
  resolving its versions.
- **Workspace resolution**: Verify that an intentionally shared local package resolves from the
  workspace rather than an external registry.
- **Native module constraints**: Ensure selected packages support the target mobile, desktop,
  serverless, or edge runtime.
