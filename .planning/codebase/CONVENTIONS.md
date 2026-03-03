# Coding Conventions

**Analysis Date:** 2026-03-02

## Naming Patterns

**Files:**
- PascalCase for React components: `Hero.tsx`, `Field.tsx`
- camelCase for utilities and helpers: `validation.ts`, `format.ts`
- PascalCase for contract files (schemas): `authSchemas.ts`, `usersContract.ts`
- Underscore-suffix for private/implementation files: `usersORPCRouter.ts`
- Use `.test.ts` or `.test.tsx` suffix for test files

**Directories:**
- camelCase for feature packages: `@features/auth`, `@features/users`
- camelCase for infrastructure packages: `@infrastructure/ui`, `@infrastructure/supabase`
- PascalCase for component directories: `Hero`, `Field`
- Use `__tests__` directories alongside source code (sibling pattern)

**Functions:**
- camelCase for all function names: `createBrowserClient()`, `useAuth()`, `formatDate()`
- Hook names must start with `use`: `useAuth()`, `useNavigation()`, `useUser()`
- Factory functions prefix with `create`: `createBrowserClient()`, `createStorageClient()`
- Guard/assertion functions prefix with `is` or `assert`: `isDefined()`, `assertDefined()`, `isValidEmail()`

**Variables:**
- camelCase for all variables and parameters
- UPPER_SNAKE_CASE for constants, especially style objects: `DOT_GRID_STYLE`, `CORS_ALLOWED_ORIGINS`
- Use `const` by default; never use `var`

**Types:**
- PascalCase for interface/type names: `AuthContextValue`, `StorageClient`, `Router`, `LinkProps`
- Type files use PascalCase prefixes: `authSchemas.ts` exports `SignInSchema`, `SignUpSchema`
- Zod schemas are PascalCase and suffixed with `Schema`: `SignInSchema`, `SignUpSchema`, `UserSchema`
- Type inference via `z.infer<typeof Schema>` with PascalCase: `SignInValues`, `UserType`

## Code Style

**Formatting:**
- Tool: Biome 2.4.4
- Line width: 100 characters
- Indentation: 2 spaces
- Quotes: Double quotes
- Semicolons: Always required
- Trailing commas: ES5 style (for objects, arrays; not function parameters)

**Linting:**
- Tool: Biome 2.4.4
- `noExplicitAny`: error — No `any` types allowed; use explicit narrowed types
- `noUnusedImports`: warn
- `noUnusedVariables`: warn
- `noNonNullAssertion`: off (non-null assertions allowed)
- `noUselessFragments`: warn

**Strict TypeScript:**
- `strict: true` (all strict flags enabled)
- `strictNullChecks: true` (explicit null/undefined handling required)
- `noEmit: true` (TS used for type checking only)
- `target: ES2022` (modern JavaScript features)
- No `// @ts-ignore` or `// @ts-nocheck` without justification

## Import Organization

**Order (enforced by Biome):**
1. External packages (`react`, `zod`, `@supabase/supabase-js`)
2. Workspace/monorepo imports (`@infrastructure/*`, `@features/*`)
3. Relative imports (`./types`, `../utils`)
4. Type imports (all `import type` grouped together)

**Format:**
```typescript
import { createContext } from "react";
import type { AuthContextValue } from "./types";

import { createClient } from "@supabase/supabase-js";

import { assertDefined } from "@infrastructure/utils";

import { useAuth } from "./useAuth";
```

**Path Aliases:**
- Web apps: `@` resolves to project root (e.g., `@/components/hero`)
- No aliases needed for workspace packages (use direct import paths)

**Barrel Files (Index Exports):**
- Infrastructure packages use barrel files for public API: `packages/infrastructure/navigation/src/index.ts` exports `Link`, `NavigationProvider`, `useNavigation`, and types
- Feature packages use default/named exports from index without complex re-exports
- Always export types alongside implementations

## Error Handling

**Pattern:**
- Throw errors for exceptional conditions that should stop execution
- Return `null` or `undefined` for expected missing data (queries with no results)
- Use Zod `.safeParse()` for validation — never throw on invalid input
- Async operations throw on actual errors; let caller decide handling

**Example:**
```typescript
// Invalid input → return failure, don't throw
const result = SignInSchema.safeParse(data);
if (!result.success) {
  setErrors(result.error.errors);
  return;
}

// Missing data → return null
const user = await client.get({ id: "999" });
if (!user) return null;

// Exceptional error → throw
if (error) throw error;

// Helper for required values
assertDefined(value, "Config is required");
```

**Context-Aware Hooks:**
- Hooks throw with clear message when used outside required provider
- Example: `useAuth` throws "useAuth must be used within an AuthProvider"

## Logging

**Framework:** Console only (no structured logging library installed)

**Patterns:**
- Use `console.log()` for normal logging (e.g., server startup)
- Hono middleware: `logger()` middleware handles HTTP request/response logging
- Errors: let exceptions bubble up or log via middleware
- Environment details: log on server startup only

**Example:**
```typescript
import { logger } from "hono/logger";
app.use("*", logger());

console.log(`Server is running on http://localhost:${port}`);
```

## Comments

**JSDoc/TSDoc: Mandatory**

**When to Comment:**
- All exported functions and types require a one-line JSDoc comment
- All user-facing components and procedures require JSDoc comments
- Complex algorithms or non-obvious logic get inline comments
- Type definitions get brief descriptions: `/** Schema for sign-in form: email + password (any length). */`

**Format:**
```typescript
/**
 * Returns the current auth state and actions (signIn, signOut, signUp, signInWithOAuth).
 * Must be used within an AuthProvider.
 */
export function useAuth(): AuthContextValue { /* ... */ }

/** Creates a Supabase browser client for use in client-side React code. */
export function createBrowserClient(supabaseUrl: string, /* ... */) { /* ... */ }

/** Schema for sign-in form: email + password (any length). */
export const SignInSchema = z.object({ /* ... */ });
```

**Inline Comments:**
```typescript
// Use regex for email validation to avoid dependency
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
```

## Function Design

**Size:**
- Max 500 lines per source file (enforced policy)
- Prefer functions under 40 lines
- Extract helpers for repeated patterns

**Parameters:**
- Prefer explicit parameters over objects for 1–2 args
- Use destructuring for objects with 3+ properties
- Use `async`/`await` not `.then()` for promises

**Return Values:**
- Functions should return early on error conditions
- Avoid nested ternaries; use guard clauses
- Consistent return types (don't mix `null` and `undefined` casually)

**Example:**
```typescript
// Good: Guard clause
export function truncate(str: string, maxLength: number): string {
  if (str.length <= maxLength) return str;
  return `${str.slice(0, maxLength - 3)}...`;
}

// Good: Explicit error handling
async function download(bucket: string, path: string): Promise<Blob> {
  const { data, error } = await supabase.storage.from(bucket).download(path);
  if (error) throw error;
  return data;
}
```

## Module Design

**Exports:**
- **Infrastructure packages** (`@infrastructure/*`): Named exports only, no default exports. Always export types.
- **Feature packages** (`@features/*`): Can use default exports for primary module (e.g., contracts default to main schema)
- **Apps**: No constraint; use defaults for pages, named for utilities

**Example:**
```typescript
// infrastructure/ui-web/src/index.ts — named exports
export { Link } from "./Link";
export { NavigationProvider } from "./NavigationProvider";
export type { LinkProps, NavigationContextValue } from "./types";
export { useNavigation } from "./useNavigation";

// features/auth/src/index.ts — contracts exported with names for clarity
export { SignInSchema, SignUpSchema, /* ... */ } from "./contracts/authSchemas";
export type { SignInValues, SignUpValues } from "./contracts/authSchemas";
```

**Public API Surface:**
- Keep exports minimal and intentional
- Re-export from subpaths as needed (`@infrastructure/supabase/auth`, `@infrastructure/supabase/storage`)
- Avoid exposing internal implementation details

---

*Convention analysis: 2026-03-02*
