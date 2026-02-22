# Require `__tests__/` Directories Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Standardize all test files to use sibling `__tests__/` directories and update governing docs.

**Architecture:** Edit two doc files (eng-constitution.md, CLAUDE.md), move 5 test files into new `__tests__/` directories, update their relative import paths from `./` to `../`.

**Tech Stack:** Git (file moves), TypeScript (import path updates), Vitest (test runner)

---

### Task 1: Update eng-constitution.md

**Files:**
- Modify: `eng-constitution.md:49`

**Step 1: Edit the Testing Framework sentence**

In `eng-constitution.md` line 49, replace:
```
Test files must use ".test" or ".spec" suffixes and be colocated with the code they test
```
With:
```
Test files must use ".test" or ".spec" suffixes and be placed in a sibling `__tests__/` directory adjacent to the code they test (e.g., `src/auth/__tests__/useAuth.test.ts` tests `src/auth/useAuth.ts`)
```

This is a substring replacement within the larger sentence on line 49. The rest of the line stays unchanged.

**Step 2: Commit**

```bash
git add eng-constitution.md
git commit -m "docs(constitution): require __tests__/ directories for test files"
```

---

### Task 2: Update CLAUDE.md

**Files:**
- Modify: `.claude/CLAUDE.md:186`

**Step 1: Edit the Testing section**

On line 186, replace:
```
- **Test locations**: colocated as `{filename}.test.ts` or in `__tests__/` directories
```
With:
```
- **Test locations**: in sibling `__tests__/` directories (e.g., `src/auth/__tests__/useAuth.test.ts`)
```

**Step 2: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "docs(claude-md): update test location convention to __tests__/ only"
```

---

### Task 3: Move utils test files

**Files:**
- Move: `packages/infrastructure/utils/src/validation.test.ts` → `packages/infrastructure/utils/src/__tests__/validation.test.ts`
- Move: `packages/infrastructure/utils/src/format.test.ts` → `packages/infrastructure/utils/src/__tests__/format.test.ts`

**Step 1: Create `__tests__/` directory and move files**

```bash
mkdir -p packages/infrastructure/utils/src/__tests__
git mv packages/infrastructure/utils/src/validation.test.ts packages/infrastructure/utils/src/__tests__/validation.test.ts
git mv packages/infrastructure/utils/src/format.test.ts packages/infrastructure/utils/src/__tests__/format.test.ts
```

**Step 2: Update import paths in `validation.test.ts`**

Change:
```typescript
import { assertDefined, isDefined, isValidEmail } from "./validation";
```
To:
```typescript
import { assertDefined, isDefined, isValidEmail } from "../validation";
```

**Step 3: Update import paths in `format.test.ts`**

Change:
```typescript
import { formatCurrency, truncate } from "./format";
```
To:
```typescript
import { formatCurrency, truncate } from "../format";
```

**Step 4: Run tests to verify**

```bash
pnpm --filter @infrastructure/utils test
```
Expected: All tests pass.

**Step 5: Commit**

```bash
git add packages/infrastructure/utils/
git commit -m "refactor(utils): move test files to __tests__/ directories"
```

---

### Task 4: Move supabase auth test files

**Files:**
- Move: `packages/infrastructure/supabase/src/auth/useAuth.test.tsx` → `packages/infrastructure/supabase/src/auth/__tests__/useAuth.test.tsx`
- Move: `packages/infrastructure/supabase/src/auth/useUser.test.tsx` → `packages/infrastructure/supabase/src/auth/__tests__/useUser.test.tsx`
- Move: `packages/infrastructure/supabase/src/auth/AuthProvider.test.tsx` → `packages/infrastructure/supabase/src/auth/__tests__/AuthProvider.test.tsx`

**Step 1: Create `__tests__/` directory and move files**

```bash
mkdir -p packages/infrastructure/supabase/src/auth/__tests__
git mv packages/infrastructure/supabase/src/auth/useAuth.test.tsx packages/infrastructure/supabase/src/auth/__tests__/useAuth.test.tsx
git mv packages/infrastructure/supabase/src/auth/useUser.test.tsx packages/infrastructure/supabase/src/auth/__tests__/useUser.test.tsx
git mv packages/infrastructure/supabase/src/auth/AuthProvider.test.tsx packages/infrastructure/supabase/src/auth/__tests__/AuthProvider.test.tsx
```

**Step 2: Update import paths in `useAuth.test.tsx`**

Change all `./` imports to `../`:
```typescript
import { AuthContext } from "../context";
import type { AuthContextValue } from "../types";
import { useAuth } from "../useAuth";
```

**Step 3: Update import paths in `useUser.test.tsx`**

Change all `./` imports to `../`:
```typescript
import { AuthContext } from "../context";
import type { AuthContextValue } from "../types";
import { useUser } from "../useUser";
```

**Step 4: Update import paths in `AuthProvider.test.tsx`**

Change all `./` imports to `../`:
```typescript
import { AuthProvider } from "../AuthProvider";
import { useAuth } from "../useAuth";
```

**Step 5: Run tests to verify**

```bash
pnpm --filter @infrastructure/supabase test
```
Expected: All tests pass.

**Step 6: Commit**

```bash
git add packages/infrastructure/supabase/
git commit -m "refactor(supabase): move auth test files to __tests__/ directory"
```

---

### Task 5: Final verification

**Step 1: Run full test suite**

```bash
pnpm test
```
Expected: All tests pass across all packages.

**Step 2: Run typecheck**

```bash
pnpm typecheck
```
Expected: No type errors.
