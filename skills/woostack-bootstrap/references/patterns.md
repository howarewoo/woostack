# Development Patterns

Recommended patterns for projects bootstrapped from this spec. Each pattern is **mandatory** unless explicitly overridden in the project's own docs.

## 1. Type-safe API via oRPC

**Why:** end-to-end types from DB → API → client. Mismatches caught at compile time.

**Structure:**
- Contracts: `packages/features/<feature>/src/contracts/{feature}Contract.ts` — Zod schemas
- Routers: `packages/features/<feature>/src/routers/{feature}ORPCRouter.ts` — oRPC router
- Procedures: `packages/features/<feature>/src/procedures/` — business logic
- Composition: `apps/api/src/router.ts` — imports feature routers, exports `Router` type
- Client utils: `@infrastructure/api-client` — `createApiClient`, `createOrpcUtils`

**Example:**

```typescript
// contracts/usersContract.ts
import { z } from "zod";
export const UserSchema = z.object({ id: z.string(), name: z.string() });
export const CreateUserSchema = z.object({ name: z.string().min(1) });

// routers/usersORPCRouter.ts
import { os } from "@orpc/server";
import { UserSchema, CreateUserSchema } from "../contracts/usersContract";

const pub = os.$context<{ requestId?: string }>();

export const usersRouter = {
  list: pub.output(UserSchema.array()).handler(() => /* ... */),
  create: pub
    .input(CreateUserSchema)
    .output(UserSchema)
    .handler(({ input }) => /* ... */),
};

// apps/api/src/router.ts
import { usersRouter } from "@features/users/src/routers/usersORPCRouter";
export const router = { users: usersRouter };
export type Router = typeof router;
```

**Client side (web/mobile):**

```typescript
import type { Router } from "api/router";
import { createApiClient, createOrpcUtils } from "@infrastructure/api-client";

const client = createApiClient<Router>("http://localhost:3001/api");
const orpc = createOrpcUtils(client);

const { data } = useQuery(orpc.users.list.queryOptions());
```

## 2. Data fetching via TanStack Query

All client-side data fetching and mutations go through TanStack Query + `@orpc/tanstack-query`. **Never** `useEffect` for data loads.

```typescript
// Query
const { data } = useQuery(orpc.users.list.queryOptions());

// Mutation
const createUser = useMutation(orpc.users.create.mutationOptions());
createUser.mutate({ name: "John" });
```

No separate `queries/` or `mutations/` folders — options come from `createOrpcUtils(client)`.

## 3. Server Components by default (Next.js)

All pages in `apps/web` and `apps/landing` are server components. Server-side render and fetch by default. Client components only when:

- DOM event handlers required (`onClick`, `onChange`)
- Browser-only APIs (`window`, `document`, `localStorage`)
- Stateful UI requiring `useState` / `useReducer`

Mark with `"use client"` at the top of the file; keep client boundaries as small as possible.

## 4. Platform-agnostic navigation

Feature packages **never** import `next/navigation` or `expo-router` directly. Always go through `@infrastructure/navigation`:

```typescript
import { Link, useNavigation } from "@infrastructure/navigation";

<Link href="/users">Users</Link>;

const nav = useNavigation();
nav.push("/users");
```

Each app provides its adapter via `<NavigationProvider>` at the root (one per app: web uses `next/navigation`, mobile uses `expo-router`).

## 5. Cross-platform UI

| Platform | Component library | Styling |
|---|---|---|
| Web | shadcn/ui (Base UI primitives) | Tailwind CSS |
| Mobile | react-native-reusables | Tailwind via UniWind |

Both consume the same theme from `@infrastructure/ui` (design tokens, `cn()` helper, CSS variables).

**Adding components:** `pnpx shadcn@latest add <component>` from a web app dir. To share across web apps, move from `apps/<app>/components/ui/` to `packages/infrastructure/ui-web/src/components/` and re-export.

**Theme changes:** edit `@infrastructure/ui` (web tokens) and `apps/mobile/global.css` (mobile mirror). Keep both in sync — UniWind can't resolve `var()` indirection in `@theme`.

## 6. Surface + Layout export pattern

Features expose a public API through two folders only:

- `surfaces/` — `*Surface.tsx` components (UI entry points)
- `layouts/` — `*Layout.tsx` components (layout shells)

Apps consume only these. Other folders (`components/`, `procedures/`, `schemas/`) are package-internal.

**Exemption:** `apps/api` may import a feature's `contracts/` and `routers/` for router composition.

```typescript
// apps/web/app/users/page.tsx
import { UserListSurface } from "@features/users/src/surfaces/UserListSurface";
// ✓ allowed

import { findUserById } from "@features/users/src/procedures/findUserById";
// ✗ forbidden — procedures are internal
```

## 7. Test-Driven Development

Red → Green → Refactor, test-first, non-negotiable. The canonical TDD kernel — the workflow,
coverage classes, and no-runner substitution — lives once in
[woostack-tdd](../../woostack-tdd/SKILL.md); follow it. This section records only the
**project-specific** standard layered on top:

**Frameworks:** Vitest everywhere except React Native (uses Jest via `jest-expo`). Playwright for E2E. Test files colocated with source as `*.test.ts(x)` or in `__tests__/`.

A feature is **not complete** until all tests pass.

## 8. API stability

HTTP endpoints maintain backward compatibility within a major version.

- URLs immutable once shipped.
- Input schemas: may add **optional** fields, never remove or rename.
- Output schemas: may add fields, never remove or change types.
- Error codes: existing codes keep meaning forever; add new codes for new conditions.
- Breaking changes → versioned endpoint or major-version bump.

oRPC contracts encode this: changing a `z.object` field is a code-level signal of an API break.

## 9. Type discipline

- No `any`. No `unknown` (except at trust boundaries where you narrow immediately).
- Prefer schema-driven types (`z.infer<typeof Schema>`) over hand-rolled interfaces for API shapes.
- Generics over duplication.
- Introduce shared helper types in `@infrastructure/utils` when you need them in more than one place.

## 10. Code size & comments

- Non-test source files: ≤ 500 lines.
- User-facing components + procedures: JSDoc with purpose, inputs, outputs.
- Comments explain **why** when non-obvious (hidden constraint, workaround, surprising invariant). Skip the **what** — code names that.
- No magic literals. Extract to `UPPER_SNAKE_CASE` constants with descriptive names.

## 11. Dependency catalog protocol

- All shared versions in `pnpm-workspace.yaml` `catalog:`.
- `package.json` references `"catalog:"`, never literal versions.
- Catalog versions exact (no `^`, no `~`).
- One PR to bump shared deps; never bump in individual `package.json` files.
