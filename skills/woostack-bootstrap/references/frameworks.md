# Technology Selection & Dependency Versioning

The approved stack determines the ecosystem and tools. Bootstrap resolves its dependency versions
live and keeps ownership with the application or shared code that consumes them.

## Registry-based version lookup

Never resolve dependency versions from model memory. Query the authoritative registry for the
approved ecosystem at bootstrap time. Examples include:

- JavaScript or TypeScript: `npm view <pkg> version` for the latest stable release and
  `npm view <pkg> dist-tags` when the approved design requires a prerelease channel.
- Python: query package metadata from PyPI through the selected tooling.
- Rust: query crates.io through Cargo or its API.
- Go: query the selected module through the public module proxy.

Use stable releases unless the approved design explicitly requires a prerelease.

## Dependency ownership

1. **Application ownership:** Declare each application's dependencies in its own manifest.
2. **Shared-code ownership:** Shared code declares its own runtime, peer, and development dependencies
   when the selected ecosystem distinguishes them.
3. **Root restraint:** Keep only genuine repository-wide tooling at the root.
4. **Lifecycle permissions:** If the selected package manager restricts lifecycle scripts, enable
   only the dependencies whose required native installation has been verified.

## Compatibility and integrity

- Resolve peer or compatibility warnings within each consuming application or shared unit.
- Verify that intentionally shared local code resolves from the repository rather than an external
  registry.
- Confirm every selected dependency supports its target runtime and deployment environment.
- Preserve lockfile and integrity metadata produced by the approved package manager.
