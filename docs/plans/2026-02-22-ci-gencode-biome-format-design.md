# Fix CI gencode formatting mismatch

## Problem

Commit `298592d` applied biome 2.4.4 formatting to the generated `router-types.d.ts`. The gencode script's `formatTypeString` function produces a compact format, but biome reformats it with line breaks at the 100-char width. CI runs `pnpm gencode` (which produces the compact format), then `git diff --exit-code` finds a mismatch against the biome-formatted committed version, failing the build.

## Root cause

The CI "verify generated code" step does not account for biome formatting. The gencode script and biome produce semantically identical but whitespace-different output.

## Solution

Add `pnpx biome check --write` on the generated directory after `pnpm gencode` in the CI workflow. This normalizes the output to biome's canonical format before the diff check.

### Changes

1. **`.github/workflows/ci.yml`**: Insert `pnpx biome check --write packages/infrastructure/api-client/src/generated/` between `pnpm gencode` and `git diff --exit-code`.

2. **`packages/infrastructure/api-client/src/generated/router-types.d.ts`**: Regenerate locally with `pnpm gencode && pnpx biome check --write` and commit the result so the file matches what CI produces.

## Alternatives considered

- **Format inside gencode script**: Couples the script to biome, adds a dependency to the api package.
- **Exclude generated files from biome**: Would leave generated files with inconsistent formatting.
