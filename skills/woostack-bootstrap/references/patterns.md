# Development Patterns

Recommended patterns for projects bootstrapped from this spec. Each pattern is **mandatory** unless explicitly overridden in the project's own docs.

## 1. Type-safe API via oRPC

**Why:** end-to-end types from DB → API → client. Mismatches caught at compile time.

**Structure:**
- Contracts: `apps/api/src/contracts/{capability}Contract.ts` — Zod schemas
- Services: `apps/api/src/services/` — business logic and API handlers
- Composition: `apps/api/src/router.ts` — imports app-local services/handlers, exports `Router` type
- Client utils: app-local by default; extract `packages/api-client` only when multiple apps share
  the same client implementation

**Example:**

```typescript
// src/contracts/usersContract.ts
import { z } from "zod";
export const UserSchema = z.object({ id: z.string(), name: z.string() });
export const CreateUserSchema = z.object({ name: z.string().min(1) });

// src/services/usersRouter.ts
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
import { usersRouter } from "./services/usersRouter";
export const router = { users: usersRouter };
export type Router = typeof router;
```

**Client side (web/mobile):**

```typescript
import type { Router } from "api/router";
import { createApiClient, createOrpcUtils } from "./lib/api-client";

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

## 4. Cross-platform UI

| Platform | Component library | Styling |
|---|---|---|
| Web | shadcn/ui (Base UI primitives) | Tailwind CSS |
| Mobile | react-native-reusables | Tailwind via UniWind |

Keep each app's theme and UI helpers local by default.

**Adding components:** `pnpx shadcn@latest add <component>` from a web app directory. Move a
component to `packages/ui-web/src/components/` and re-export it only when multiple web apps need the
same implementation.

**Theme changes:** keep tokens in the app that uses them. Extract shared tokens to `packages/ui`
only when multiple apps must consume the same theme; keep any platform-specific mirrors in sync.

## 5. App-local code and shared extraction

New components, layouts, services, schemas, contracts, utilities, and vendor integrations live in
the app that owns them.

- Follow the app framework's native module and export conventions.
- When multiple apps need the same implementation or contract, extract the smallest coherent shared
  surface to `packages/<shared-capability>`.
- After extraction, remove app-local duplicates and import the shared package from each consumer.

## 6. Application-boundary adapters

When data crosses between applications, use explicit adapters at the receiving and sending boundaries so transport, client, and vendor formats never leak into application or domain logic.

- **Scope:** Applies in both directions across HTTP/RPC server-client, service-service, webhooks, queues/events, and third-party APIs. Excludes database persistence mapping and ordinary in-process module calls.
- **Responsibilities:** Adapters validate or narrow untrusted wire input; map wire or vendor representations to application/domain models and map domain models back to wire shapes; and translate transport-specific errors so business logic remains independent of transport, client, and vendor details.
- **Form:** Functions or modules satisfy the pattern; classes are not required.
- **Placement:** Keep adapters in the application that owns the boundary, optionally in an app-local `adapters/` directory. Extract to a shared package (`packages/<shared-capability>`) only when multiple applications consume the exact same contract or implementation, then remove app-local duplicates.
- **Compatibility and safety:** Preserve existing wire and API contracts unless an approved change explicitly versions or breaks them. Preserve input validation, error handling, security, accessibility, and data-loss protections.
- **Touched-flow policy:** Apply to new boundary flows and existing flows materially changed by a task. Do not migrate untouched legacy boundary flows.
- **Identity-shape exception:** When a deliberately shared contract is already the application/domain shape, do not add an identity-only or no-op wrapper. Boundary validation and transport/error handling still apply, but a separate adapter module is required only where translation or transport/vendor isolation performs real work.
- **Review criteria:** Architecture review blocks concrete changed-code transport/client/vendor leaks or missing required boundary validation and error translation. Review does not block folder/file naming, class-vs-function style, or the omission of identity/no-op wrappers.

## 7. Test-Driven Development

Red → Green → Refactor, test-first, non-negotiable. The canonical TDD kernel — the workflow,
coverage classes, and no-runner substitution — lives once in
[woostack-tdd](../../woostack-tdd/SKILL.md); follow it. This section records only the
**project-specific** standard layered on top:

**Frameworks:** Vitest everywhere except React Native (uses Jest via `jest-expo`). Playwright for E2E. Tests for a source file live in a sibling `__tests__/` directory.

A change is **not complete** until all tests pass.

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
- Keep helper types app-local; extract one to a shared package only when multiple apps need it.

## 10. Least code & comments

Write as little code as necessary — but never at the cost of correctness or safety. Understand the
problem first, then take the first rung that holds.

- **The ladder.** Before adding code, walk the rungs and stop at the first that works: (1) YAGNI —
  is it needed at all? (2) in-tree reuse — a helper/util/pattern that already exists here; (3)
  stdlib; (4) a native platform feature; (5) an already-installed dependency; (6) one line; (7)
  only then the minimum new code that works. The review
  [`simplify` angle](../../woostack-review/prompts/angles/simplify.md) enforces this ladder.
- **Read first (delta A).** The ladder runs *after* you understand the problem: read the code the
  change touches and trace the real flow end to end before picking a rung. Lazy about the
  solution, never about reading — the smallest change in the wrong place is a second bug.
- **Equal-size tie-breaker (delta B).** When two approaches are the same size, pick the
  edge-case-correct one. Lazy means less code, not the flimsier algorithm.
- **Never-cut list (delta C).** Never shrink code by dropping validation, error handling,
  security, accessibility, or data-loss handling. Keep deliberate multi-layer safety redundancy
  (it is not DRY-removable); prefer scoped parsing over a greedy regex; a behavior-changing
  simplification keeps its regression test.
- **Boring over clever (delta D).** Deletion over addition; boring over clever. Code is small
  because it's necessary, not because it's golfed.
- **Deliberate-corner marker (delta E).** A knowingly-cut corner with a known ceiling (global
  lock, O(n²) scan, naive heuristic) leaves a `why` comment naming the ceiling and the upgrade
  path. If broadly reusable, surface it as a session-end instruction suggestion.
- Non-test source files: ≤ 500 lines.
- User-facing components + procedures: JSDoc with purpose, inputs, outputs.
- Comments explain **why** when non-obvious (hidden constraint, workaround, surprising invariant). Skip the **what** — code names that.
- No magic literals. Extract to `UPPER_SNAKE_CASE` constants with descriptive names.

## 11. App-scoped dependency protocol

- Each app declares the dependencies and versions its runtime needs in its own manifest.
- Shared packages declare their own runtime, peer, and development dependencies.
- Keep only genuine repository-wide tooling at the root.
