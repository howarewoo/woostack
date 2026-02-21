# Project Constitution

## Core Principles

### I. Monorepo Structure
Three package types with strict import boundaries: Infrastructure (`packages/infrastructure/*`, can be used anywhere), Features (`packages/features/*`, only in apps), Apps (`apps/*`, compose infrastructure and features); Use pnpm for package management; Maintain clear separation of concerns. Apps must never depend on other apps; type sharing between apps flows through infrastructure packages via code generation (`pnpm gencode`).

### II. Feature-Based Architecture
Every feature is implemented as a standalone package with clear boundaries; Features can only import from infrastructure packages; Clear separation between features, infrastructure, and apps ensures maintainability and scalability.

### III. Naming and Code Style Conventions
All code in feature packages must follow standardized naming conventions and directory structure (excluding infrastructure packages and apps); Components must use PascalCase (UpperCamelCase) with one default export per file; Helper functions must use camelCase; Custom hooks must use camelCase with "use" prefix (e.g., `useHookName`); Constants must use UPPER_SNAKE_CASE; TypeScript types and interfaces must use PascalCase; Schemas must use PascalCase; Procedure files must use camelCase names describing the operation (e.g., `createUser`, `fetchUsers`) and be located in the `procedures/` folder; oRPC contracts must use `{feature}Contract.ts` naming (e.g., `usersContract.ts`) in the `contracts/` folder; oRPC routers must use `{feature}ORPCRouter.ts` naming (e.g., `usersORPCRouter.ts`) in the `routers/` folder; oRPC procedure names must use camelCase (e.g., `listUsers`, `createUser`); File organization must use dedicated folders: `procedures/`, `contracts/`, `routers/`, `components/`, `surfaces/`, `schemas/`, and `layouts/`; Use `.ts` file extension by default and only use `.tsx` when the file contains JSX; Prioritize using default exports over named exports for feature packages (infrastructure packages should use named exports for better discoverability and tree-shaking); Consistent naming, code organization, and file structure across all feature packages ensures maintainability, readability, and scalability.

### IV. Infrastructure Package Priority
Infrastructure packages provide shared utilities, UI components, and cross-cutting concerns; Prioritize using components from `@infrastructure/ui` for shared styles and utilities; Use `@infrastructure/api-client` for oRPC client utilities (`createApiClient`, `createOrpcUtils`) and shared base schemas; Use `@infrastructure/supabase` for all Supabase access (clients, auth hooks, storage, middleware, generated DB types); Use `@infrastructure/utils` for cross-platform utilities; Use `@infrastructure/typescript-config` for shared TypeScript configuration.

### V. pnpm Catalog Protocol
All dependencies must be managed through pnpm catalog to prevent version conflicts; Catalog definitions in `pnpm-workspace.yaml` ensure consistent dependency versions across the monorepo; No direct dependency declarations in individual `package.json` files; All versions in the catalog must be pinned to exact versions (no `^` or `~` prefixes) to ensure deterministic installs.

### VI. TypeScript Standardization
All packages must use standardized TypeScript configuration from `@infrastructure/typescript-config`; Consistent typing, path mapping, and compiler options across all packages; Do not use `any` or `unknown`—prefer explicit, safely narrowed types, generics, and schema-driven types instead; Introduce shared helper types when needed to avoid unsafe fallbacks.

### VII. Cross-Platform UI Components
Web uses shadcn/ui components; Mobile uses react-native-reusables components. Both share Tailwind CSS for styling (via `tailwindcss` on web and `uniwind` on mobile) and a unified theme defined in `@infrastructure/ui`. Shared design tokens (colors, spacing, typography) and CSS utilities live in `@infrastructure/ui` so both platforms stay visually consistent. Shadcn components are mandatory on web for common UI patterns (buttons, forms, dialogs, navigation); react-native-reusables equivalents are mandatory on mobile. Custom components are only permitted when neither library covers the required functionality. All theme changes must be made in `@infrastructure/ui` and consumed by both platforms.

### VIII. Test-Driven Development
All features must be developed using test-driven development (TDD) methodology following the Red-Green-Refactor cycle.

**Tests-First Requirement:**
Tests MUST be written before any implementation code. This is non-negotiable. The workflow is:
1. **Red**: Write a failing test that defines the expected behavior
2. **Green**: Write the minimum implementation code to make the test pass
3. **Refactor**: Improve the code while keeping tests green

**Clarification Before Implementation:**
When test case requirements are unclear or ambiguous, clarifying questions MUST be asked before writing tests. Do not assume or guess requirements. Questions should cover:
- Expected inputs and outputs for each scenario
- Edge cases and boundary conditions
- Error handling expectations
- Integration points with other components

**Test Coverage Requirements:**
- All user scenarios must have corresponding tests
- All edge cases and boundary conditions must be tested
- All error conditions must have explicit test coverage
- Both success and failure scenarios must be tested

**Testing Framework:**
All tests must use Vitest, except React Native apps which use Jest (via `jest-expo` preset) due to Metro bundler incompatibility with Vitest; Test files must use ".test" or ".spec" suffixes and be placed in a sibling `__tests__/` directory adjacent to the code they test (e.g., `src/auth/__tests__/useAuth.test.ts` tests `src/auth/useAuth.ts`); Vitest configuration in `package.json` or `vitest.config.ts`; Test discovery via Vitest's default or explicit configuration; E2E tests use Playwright.

**Completion Criteria:**
A feature is NOT considered complete until all tests pass. Implementation without passing tests is incomplete work.

### IX. oRPC API
oRPC provides type-safe end-to-end API communication between apps (web, mobile) and the API server (Hono). Feature packages own their contracts and routers; `@infrastructure/api-client` provides generic client utilities (`createApiClient`, `createOrpcUtils`) and shared base schemas.

**Structure:**
- Feature contracts: `packages/features/<feature>/src/contracts/{feature}Contract.ts` — Zod schemas defining inputs and outputs
- Feature routers: `packages/features/<feature>/src/routers/{feature}ORPCRouter.ts` — oRPC router with handlers
- Feature procedures: `packages/features/<feature>/src/procedures/` — business logic called by router handlers
- API composition: `apps/api/src/router.ts` — imports feature routers, composes the master router, exports `Router` type
- Client utilities: `@infrastructure/api-client` — `createApiClient`, `createOrpcUtils`, shared base schemas

**Router Pattern:**
```typescript
// packages/features/users/src/contracts/usersContract.ts
import { z } from "zod";

export const UserSchema = z.object({ id: z.string(), name: z.string() });
export const CreateUserSchema = z.object({ name: z.string().min(1) });

// packages/features/users/src/routers/usersORPCRouter.ts
import { os } from "@orpc/server";
import { UserSchema, CreateUserSchema } from "../contracts/usersContract";

const pub = os.$context<{
  requestId?: string;
  user?: import("@supabase/supabase-js").User;
  supabase: import("@supabase/supabase-js").SupabaseClient;
}>();

export const usersRouter = {
  list: pub.output(UserSchema.array()).handler(() => {
    // return users
  }),
  create: pub
    .input(CreateUserSchema)
    .output(UserSchema)
    .handler(({ input }) => {
      // create and return user
    }),
};

// apps/api/src/router.ts
import { usersRouter } from "@features/users/src/routers/usersORPCRouter";

export const router = {
  users: usersRouter,
};

export type Router = typeof router;
```

**Client Usage Pattern:**
```typescript
// In consuming apps (web, mobile)
import { createTypedApiClient, createTypedOrpcUtils } from "@infrastructure/api-client";

const client = createTypedApiClient("http://localhost:3001/api");
const orpc = createTypedOrpcUtils(client);
const users = await client.users.list();
```

Apps import pre-typed client utilities from `@infrastructure/api-client` — they never import types from `apps/api` directly. The `Router` type is generated into `@infrastructure/api-client` via `pnpm gencode` (see `apps/api/scripts/generate-router-types.ts`). After changing any router or contract, run `pnpm gencode` and commit the generated file.

### X. TanStack Query Data Fetching and Mutations
All client-side data fetching and mutations must use TanStack Query (React Query) with oRPC; Query and mutation options are accessed directly via `createOrpcUtils()` — no separate `queries/` or `mutations/` folders are needed.

Client components must never use `useEffect` to load data; all client-side data fetching and revalidation must go through TanStack Query hooks (e.g., `useQuery`, `useInfiniteQuery`, `useMutation`).

**Query Example:**
```typescript
const orpc = createOrpcUtils(client);
const { data } = useQuery(orpc.users.list.queryOptions());
```

**Mutation Example:**
```typescript
const createUser = useMutation(orpc.users.create.mutationOptions());
createUser.mutate({ name: "John", email: "john@example.com" });
```

### XI. Next.js Server Components
All pages in Next.js applications must be implemented as server components; Server components must handle all initial rendering and data fetching; Client components are only permitted for interactive elements that require browser APIs or event handlers; Server components ensure better performance, SEO, and security by keeping sensitive logic on the server.

### XII. Feature Exposure Patterns
Features must expose their public API through strictly defined patterns; Feature UI components accessed through "Surface" components in the `surfaces/` folder with "Surface" suffix; Feature Layout UI accessed through components in the `layouts/` folder with "Layout" suffix; No other files or folders from the feature package may be imported or accessed by consuming applications.

**Exemptions**: Infrastructure packages (`packages/infrastructure/**`) are designed to be consumed directly; exports are intentionally public and reusable across all packages. `apps/api` may import feature internal paths (contracts, routers) for router composition — this is the only app-level exemption to the Surfaces/Layouts export rule.

### XIII. API Stability
All HTTP API endpoints must maintain backward compatibility within a major version.

**Stability Requirements:**
- Endpoint URLs must not change once deployed to production
- Input schemas may add optional fields but must not remove or rename existing fields
- Output schemas may add fields but must not remove or change the type of existing fields
- Error codes must remain consistent; new codes may be added but existing codes must retain their meaning
- Breaking changes require versioned endpoints or major version bump

### XIV. Platform-Agnostic Navigation
Feature packages must never import platform-specific routing (`next/navigation`, `expo-router`). All navigation in feature packages must use `@infrastructure/navigation` — `useNavigation()` for imperative navigation and `<Link>` for declarative navigation. Each app provides its own implementation via `NavigationProvider`.

### XV. Supabase Backend Services
Supabase is the canonical backend for authentication, database (PostgreSQL + Row Level Security), and file storage. `apps/supabase` holds the Supabase CLI project (config, migrations, seed data); `@infrastructure/supabase` provides typed clients, auth context, storage utilities, and middleware for all apps.

**Access Rules:**
- Feature packages and apps must never import `@supabase/supabase-js` directly — all Supabase access flows through `@infrastructure/supabase`
- Auth state in client apps is provided via `AuthProvider` / `useAuth()` / `useUser()` (React context pattern, same as `NavigationProvider`)
- Feature procedures access the authenticated user and an RLS-scoped Supabase client via oRPC context (`context.user`, `context.supabase`)
- Unauthenticated API requests receive an anon-key client that respects RLS — never the service role key

**Type Generation:**
After changing migrations, run `pnpm --filter supabase-db reset` then `pnpm gencode` to regenerate the `Database` type in `@infrastructure/supabase`. The generated types must be committed.

## Development Workflow

### Package Management
Use pnpm workspaces for all package operations (install, add, remove, run); Dependencies must use pnpm catalog protocol defined in `pnpm-workspace.yaml`; No direct dependency declarations in individual `package.json` files to prevent conflicts; All catalog versions must be exact (e.g., `"4.11.9"`, not `"^4.11.9"`).

### Code Quality
Biome configuration for linting and formatting through shared infrastructure packages; Consistent code style, import organization, and formatting rules across all packages; Automated checks in CI/CD pipeline replace ESLint and Prettier; Individual non-test source files must be 500 lines or fewer; Test files are exempt from this limit: files with `.test.ts`, `.test.tsx`, `.spec.ts`, `.spec.tsx` suffixes, and any files within `__tests__/` directories.
All user-facing components must include concise JSDoc comments that describe their purpose, inputs, and outputs to keep intent clear across the monorepo.
Avoid magic numbers and unexplained literals—extract numeric values, string literals, and configuration values to named constants with descriptive names that convey intent (e.g., `const MAX_RETRY_ATTEMPTS = 3` instead of using `3` directly).

## Governance

This constitution establishes the foundational principles for project development. All contributors must verify compliance with these principles in pull requests and code reviews. Complexity introduced must be justified against these core principles.

**Version**: 1.0.0 | **Ratified**: 2026-02-13
