# Testing Patterns

**Analysis Date:** 2026-03-02

## Test Framework

**Runner:**
- Vitest (latest in catalog)
- Config: Root `vitest.config.ts` defines globals + environment baseline
- Per-package overrides in `packages/*/vitest.config.ts` and `apps/*/vitest.config.ts`

**Assertion Library:**
- Vitest built-in expect API (compatible with Jest)

**Run Commands:**
```bash
pnpm test                # Run all tests across monorepo
pnpm test:changed        # Run tests for packages changed since HEAD^1
pnpm --filter <pkg> test # Run tests for specific package (e.g., pnpm --filter web test)
```

**Watch Mode:**
- Use `pnpm --filter <pkg> test -- --watch` for single-package development

**Coverage:**
- Not enforced by default
- View coverage per-package by running Vitest with `--coverage` flag

## Test File Organization

**Location:**
- Co-located in `__tests__/` directories alongside source code
- Test file path mirrors source file path: `src/auth/useAuth.ts` → `src/auth/__tests__/useAuth.test.tsx`

**Naming:**
- `.test.ts` for non-React files (schemas, utilities, hooks in non-JSX context)
- `.test.tsx` for React components and hooks
- No `.spec.ts` — use `.test.ts` consistently

**Structure:**
```
packages/infrastructure/supabase/
├── src/
│   ├── auth/
│   │   ├── useAuth.ts
│   │   └── __tests__/
│   │       └── useAuth.test.tsx
│   ├── clients/
│   │   ├── browser.ts
│   │   └── __tests__/
│   │       └── browser.test.ts
│   └── middleware/
│       └── __tests__/
│           └── hono.test.ts
```

## Test Structure

**Suite Organization:**
```typescript
import { describe, expect, it, vi } from "vitest";
import { SignInSchema } from "../authSchemas";

describe("SignInSchema", () => {
  it("accepts valid email and password", () => {
    const result = SignInSchema.safeParse({ email: "user@example.com", password: "pass123" });
    expect(result.success).toBe(true);
  });

  it("rejects invalid email", () => {
    const result = SignInSchema.safeParse({ email: "not-an-email", password: "pass123" });
    expect(result.success).toBe(false);
  });
});
```

**Patterns:**
- Top-level `describe()` for each unit (function, component, class)
- Nested `describe()` for grouping related cases (e.g., "valid input", "edge cases")
- One assertion per `it()` block, sometimes two related ones
- Use descriptive test names: "renders headline text" not "renders"

**Setup/Teardown:**
- Vitest hooks: `beforeEach()`, `afterEach()`, `beforeAll()`, `afterAll()`
- Prefer per-test setup (local variables) over `beforeEach()` unless teardown is needed

**Assertion Patterns:**
```typescript
// Existence checks
expect(result).toBeDefined();
expect(result).toBeTruthy();

// Value checks
expect(result.success).toBe(true);
expect(result.id).toBe("1");

// Array/Object checks
expect(Array.isArray(result)).toBe(true);
expect(result).toHaveProperty("id");
expect(result).toHaveLength(1);

// Error checks
expect(() => renderHook(() => useAuth())).toThrow("useAuth must be used within an AuthProvider");

// Null/undefined checks
expect(result).toBeNull();
expect(result).not.toBeNull();
```

## Mocking

**Framework:** Vitest `vi` module (no external mocking library needed)

**Pattern:**
- Mock at top of file before import: `vi.mock("@supabase/supabase-js", () => ({ /* ... */ }))`
- Mocks are file-scoped; apply to all tests in that file
- Mocks must be defined before importing the module under test

**Example:**
```typescript
import { describe, expect, it, vi } from "vitest";

vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

import { createClient } from "@supabase/supabase-js";
import { createBrowserClient } from "../browser";

describe("createBrowserClient", () => {
  it("creates a Supabase client with the provided URL and publishable key", () => {
    const client = createBrowserClient("http://localhost:54321", "test-publishable-key");
    expect(createClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-publishable-key",
      undefined
    );
    expect(client).toBeDefined();
  });
});
```

**Advanced Mocking:**
```typescript
// Override per-test with mocked return value
vi.mocked(createClient).mockReturnValueOnce({
  auth: {
    getUser: vi.fn(() =>
      Promise.resolve({
        data: { user: null },
        error: { message: "Invalid token", status: 401 },
      })
    ),
  },
  from: vi.fn(),
} as unknown as ReturnType<typeof createClient>);
```

**What to Mock:**
- External APIs (`@supabase/supabase-js`, `@hono/node-server`)
- Internal dependencies only when testing isolation is critical
- Do NOT mock utilities or helpers — test them through their real behavior

**What NOT to Mock:**
- Zod schemas (test validation behavior directly)
- Helper functions (test via integration)
- Third-party utilities unless they have side effects

## Fixtures and Factories

**Test Data:**
```typescript
// Use constants or inline objects
const mockValue: AuthContextValue = {
  session: null,
  user: null,
  isLoading: false,
  signIn: async () => {},
  signUp: async () => {},
  signOut: async () => {},
  signInWithOAuth: async () => {},
};

// Wrap in describe for reusability across suites
describe("useAuth", () => {
  it("returns context value when used within provider", () => {
    const { result } = renderHook(() => useAuth(), {
      wrapper: ({ children }) => (
        <AuthContext.Provider value={mockValue}>{children}</AuthContext.Provider>
      )
    });
    expect(result.current.isLoading).toBe(false);
  });
});
```

**Location:**
- Keep fixtures inline in test files unless shared across multiple test files
- No separate fixture files yet — add if pattern emerges

## Environment Configuration

**Vitest Config by App Type:**

**Root (node environment):**
```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    globals: true,
    environment: "node",
  },
});
```

**Infrastructure/Feature Packages (jsdom for React):**
```typescript
// packages/infrastructure/supabase/vitest.config.ts
export default defineConfig({
  test: {
    environment: "jsdom",
  },
});
```

**Web Apps (jsdom + React plugin):**
```typescript
// apps/web/vitest.config.ts
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: "jsdom",
    exclude: ["node_modules", "e2e"],
    passWithNoTests: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./"),
    },
  },
});
```

**API Apps (node environment, no tests needed often):**
```typescript
// apps/api/vitest.config.ts
export default defineConfig({
  test: {
    environment: "node",
    passWithNoTests: true,
    exclude: ["node_modules", "dist"],
  },
});
```

## Test Types

**Unit Tests:**
- Scope: Single function, hook, or component
- Approach: Test behavior with mocked dependencies
- Files: `src/contracts/__tests__/authSchemas.test.ts`, `src/utils/__tests__/validation.test.ts`
- Example: Validate Zod schema accepts/rejects inputs

**Integration Tests:**
- Scope: Multiple functions/modules working together (React components + context, routers + clients)
- Approach: Test through realistic scenarios with limited mocking
- Files: `src/auth/__tests__/useAuth.test.tsx` (hook + context), `src/middleware/__tests__/hono.test.ts` (middleware + app)
- Example: Hook throws when used outside provider, middleware attaches user to context

**E2E Tests:**
- Framework: Not currently in use (not in codebase)
- Placeholder: `pnpm test:e2e` exists but no Playwright config found
- Future: Expected to be added for critical user flows

## Common Patterns

**Async Testing:**
```typescript
// Async functions return promises — vitest auto-waits
it("creates a user with provided name and email", async () => {
  const result = await client.create({
    name: "New User",
    email: "new@example.com",
  });
  expect(result.name).toBe("New User");
  expect(result.id).toBeDefined();
});

// Promises in handlers
it("attaches user to context when valid token is provided", async () => {
  const app = new Hono();
  const middleware = supabaseMiddleware({
    supabaseUrl: "http://localhost:54321",
    supabasePublishableKey: "test-publishable-key",
  });

  app.use("*", middleware);
  const res = await app.request("/test", {
    headers: { Authorization: "Bearer valid-token" },
  });

  expect(res.status).toBe(200);
});
```

**React Component Testing:**
```typescript
import { render, screen } from "@testing-library/react";

it("renders headline text", () => {
  render(<Hero />);
  expect(screen.getByText("The modern monorepo")).toBeTruthy();
});

it("renders CTA buttons", () => {
  render(<Hero />);
  expect(screen.getAllByText("Get Started")).toHaveLength(1);
});

it("has role=alert for accessibility", () => {
  render(<FieldError errors={[{ message: "Error" }]} />);
  expect(screen.getByRole("alert")).toBeDefined();
});
```

**Hook Testing (React Testing Library):**
```typescript
import { renderHook } from "@testing-library/react";

it("returns context value when used within provider", () => {
  function wrapper({ children }) {
    return <AuthContext.Provider value={mockValue}>{children}</AuthContext.Provider>;
  }
  const { result } = renderHook(() => useAuth(), { wrapper });
  expect(result.current.isLoading).toBe(false);
});

it("throws when used outside provider", () => {
  expect(() => {
    renderHook(() => useAuth());
  }).toThrow("useAuth must be used within an AuthProvider");
});
```

**Error Testing:**
```typescript
// Validation failure
it("rejects invalid email", () => {
  const result = SignInSchema.safeParse({ email: "not-an-email", password: "pass123" });
  expect(result.success).toBe(false);
});

// Hook error boundary
it("throws when used outside provider", () => {
  expect(() => {
    renderHook(() => useAuth());
  }).toThrow("useAuth must be used within an AuthProvider");
});

// Async error handling
const { error } = await supabase.storage.from(bucket).download(path);
if (error) throw error;
```

**Mocking Patterns:**
```typescript
// Mock function call tracking
expect(createClient).toHaveBeenCalledWith(
  "http://localhost:54321",
  "test-publishable-key",
  undefined
);

// Mock with custom return value per call
vi.mocked(createClient).mockReturnValueOnce({
  auth: { getUser: vi.fn(() => Promise.resolve({ data: { user: null } })) },
  from: vi.fn(),
});

// Test state after mock interaction
const res = await app.request("/test", {
  headers: { Authorization: "Bearer valid-token" },
});
expect(res.status).toBe(200);
```

## Coverage

**Requirements:** None enforced (target not specified)

**View Coverage:**
```bash
pnpm --filter <pkg> test -- --coverage
```

**Current State:** Coverage checks not configured; focus is on meaningful tests rather than coverage percentage targets.

---

*Testing analysis: 2026-03-02*
