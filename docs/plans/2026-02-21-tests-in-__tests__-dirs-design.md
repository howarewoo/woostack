# Design: Require `__tests__/` Directories for All Test Files

**Date:** 2026-02-21
**Status:** Approved

## Problem

The eng-constitution says test files should be "colocated with the code they test" which is ambiguous — it allows both sibling `__tests__/` directories and flat colocated files (e.g., `foo.test.ts` next to `foo.ts`). The codebase has converged on `__tests__/` directories for ~80% of tests, but 5 files remain flat-colocated. Standardizing on one convention reduces ambiguity for contributors.

## Decision

All test files must be placed in a sibling `__tests__/` directory adjacent to the code they test.

**Example:** `src/auth/__tests__/useAuth.test.ts` tests `src/auth/useAuth.ts`.

## Scope

Universal — applies to all package types (apps, features, infrastructure). No exemptions.

## Changes

### 1. eng-constitution.md (Section VIII, Testing Framework)

Replace:
> Test files must use ".test" or ".spec" suffixes and be colocated with the code they test

With:
> Test files must use ".test" or ".spec" suffixes and be placed in a sibling `__tests__/` directory adjacent to the code they test (e.g., `src/auth/__tests__/useAuth.test.ts` tests `src/auth/useAuth.ts`)

### 2. CLAUDE.md (Testing section)

Update test location description to reference only `__tests__/` directories.

### 3. Move 5 colocated test files

| From | To |
|------|----|
| `packages/infrastructure/utils/src/validation.test.ts` | `packages/infrastructure/utils/src/__tests__/validation.test.ts` |
| `packages/infrastructure/utils/src/format.test.ts` | `packages/infrastructure/utils/src/__tests__/format.test.ts` |
| `packages/infrastructure/supabase/src/auth/useAuth.test.tsx` | `packages/infrastructure/supabase/src/auth/__tests__/useAuth.test.tsx` |
| `packages/infrastructure/supabase/src/auth/useUser.test.tsx` | `packages/infrastructure/supabase/src/auth/__tests__/useUser.test.tsx` |
| `packages/infrastructure/supabase/src/auth/AuthProvider.test.tsx` | `packages/infrastructure/supabase/src/auth/__tests__/AuthProvider.test.tsx` |

### 4. Verification

Run `pnpm test` to confirm all tests still pass after the move.
