# Supabase UI Updates Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add full auth UI to `apps/web` (sign-in, sign-up, forgot/reset password, dashboard, settings) and update `apps/landing` to showcase Supabase as a core feature.

**Architecture:** Custom auth forms built with shadcn/ui components (Input, Label, Separator) on top of the existing `useAuth()` / `useUser()` hooks from `@infrastructure/supabase`. Route protection via existing Next.js middleware + a server-side layout guard. Landing page gains a new "Backend" feature section (4.0) and updated hero/value props/tech stack.

**Tech Stack:** Next.js 16 (App Router), shadcn/ui (base-vega style), `@infrastructure/supabase` (auth hooks, SSR clients, middleware), Tailwind CSS v4, Vitest + React Testing Library

---

## Important Context

### Existing infrastructure you MUST use (do NOT recreate):
- **Auth hooks**: `useAuth()` from `@infrastructure/supabase/auth` — provides `signIn`, `signUp`, `signOut`, `signInWithOAuth`, `session`, `user`, `isLoading`
- **User hook**: `useUser()` from `@infrastructure/supabase/auth` — convenience wrapper returning `User | null`
- **AuthProvider**: Already wired in `apps/web/app/providers.tsx` — no changes needed there
- **SSR clients**: `createServerSupabase()` from `apps/web/lib/supabase` — for server components
- **Middleware**: Already exists at `apps/web/middleware.ts` — needs `loginPath` updated from `/login` to `/sign-in`
- **API client**: `apps/web/lib/api.ts` — needs `getToken` added for authenticated requests

### Testing conventions:
- Vitest + React Testing Library
- Tests in `__tests__/` sibling directories
- Mock child components with `vi.mock()` returning `data-testid` divs
- Mock `@infrastructure/ui-web` as simple HTML elements
- Use `screen.getByText()` / `screen.getByTestId()` with `.toBeDefined()` or `.toBeTruthy()`
- Mock `@infrastructure/supabase/auth` for auth hooks

### shadcn/ui conventions:
- Install from `apps/web/` with `pnpx shadcn@latest add <component>`
- Components land in `apps/web/components/ui/`
- Move to `packages/infrastructure/ui-web/src/components/` for sharing
- Re-export from `packages/infrastructure/ui-web/src/index.ts`
- Style: `base-vega`, utils alias: `@infrastructure/ui`

### File naming:
- `.tsx` only when file contains JSX
- Named exports for infrastructure packages
- `"use client"` directive required for components using hooks

---

## Task 1: Install and Share shadcn/ui Components (Input, Label, Separator)

**Files:**
- Create: `packages/infrastructure/ui-web/src/components/input.tsx`
- Create: `packages/infrastructure/ui-web/src/components/label.tsx`
- Create: `packages/infrastructure/ui-web/src/components/separator.tsx`
- Modify: `packages/infrastructure/ui-web/src/index.ts`

**Step 1: Install Input, Label, and Separator into apps/web**

Run from repo root:
```bash
cd apps/web && pnpx shadcn@latest add input label separator -y
```

This creates files in `apps/web/components/ui/`. Note: shadcn may generate `.tsx` files.

**Step 2: Move components to shared ui-web package**

Move each generated component from `apps/web/components/ui/` to `packages/infrastructure/ui-web/src/components/`:

```bash
mv apps/web/components/ui/input.tsx packages/infrastructure/ui-web/src/components/input.tsx
mv apps/web/components/ui/label.tsx packages/infrastructure/ui-web/src/components/label.tsx
mv apps/web/components/ui/separator.tsx packages/infrastructure/ui-web/src/components/separator.tsx
```

**Step 3: Fix imports in moved files**

Each moved component may import `cn` from `@/lib/utils` — update to `@infrastructure/ui`:

In each file, replace:
```typescript
import { cn } from "@/lib/utils"
```
with:
```typescript
import { cn } from "@infrastructure/ui";
```

Also add JSDoc comments to each component's main export (convention from existing Button/Card components). Add `"use client"` directive if the component uses React hooks or client APIs.

**Step 4: Re-export from barrel**

Modify `packages/infrastructure/ui-web/src/index.ts` — add these exports after the existing Card exports:

```typescript
export { Input } from "./components/input";
export { Label } from "./components/label";
export { Separator } from "./components/separator";
```

**Step 5: Verify build**

```bash
pnpm typecheck
```

Expected: No type errors. The new components should be importable as `import { Input, Label, Separator } from "@infrastructure/ui-web"`.

**Step 6: Clean up apps/web/components/ui/ if empty**

If the `apps/web/components/ui/` directory was created by shadcn and is now empty, remove it:

```bash
rmdir apps/web/components/ui 2>/dev/null || true
```

**Step 7: Commit**

```bash
gt create -m "feat(ui-web): add Input, Label, and Separator components"
```

---

## Task 2: Update Middleware loginPath and Wire Authenticated API Client

**Files:**
- Modify: `apps/web/middleware.ts`
- Modify: `apps/web/lib/api.ts`

**Step 1: Write test for middleware config change**

The middleware is a thin config wrapper — we verify the configuration. Create:

`apps/web/__tests__/middleware.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";

const mockCreateSupabaseMiddleware = vi.fn(() => vi.fn());

vi.mock("@infrastructure/supabase/middleware/nextjs", () => ({
  createSupabaseMiddleware: mockCreateSupabaseMiddleware,
}));

// Import after mock setup
await import("@/middleware");

describe("middleware", () => {
  it("configures loginPath as /sign-in", () => {
    expect(mockCreateSupabaseMiddleware).toHaveBeenCalledWith(
      expect.objectContaining({
        loginPath: "/sign-in",
        protectedRoutes: ["/dashboard", "/settings"],
      })
    );
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- middleware.test
```

Expected: FAIL — current middleware uses `loginPath: "/login"`.

**Step 3: Update middleware.ts**

In `apps/web/middleware.ts`, change `loginPath: "/login"` to `loginPath: "/sign-in"`:

```typescript
import { createSupabaseMiddleware } from "@infrastructure/supabase/middleware/nextjs";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export default createSupabaseMiddleware({
  supabaseUrl,
  supabaseAnonKey,
  protectedRoutes: ["/dashboard", "/settings"],
  loginPath: "/sign-in",
});

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- middleware.test
```

Expected: PASS

**Step 5: Update API client with getToken**

Modify `apps/web/lib/api.ts` to inject auth tokens:

```typescript
import { createTypedApiClient, createTypedOrpcUtils } from "@infrastructure/api-client";
import { createBrowserSupabase } from "./supabase";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001/api";

export const apiClient = createTypedApiClient(API_URL, {
  getToken: async () => {
    const supabase = createBrowserSupabase();
    const { data } = await supabase.auth.getSession();
    return data.session?.access_token;
  },
});
export const orpc = createTypedOrpcUtils(apiClient);
```

**Step 6: Run typecheck**

```bash
pnpm typecheck
```

Expected: No errors.

**Step 7: Commit**

```bash
gt modify -m "feat(web): update middleware loginPath to /sign-in and wire authenticated API client"
```

---

## Task 3: Auth Form Component

**Files:**
- Create: `apps/web/components/auth-form.tsx`
- Create: `apps/web/components/__tests__/auth-form.test.tsx`

**Step 1: Write the test**

`apps/web/components/__tests__/auth-form.test.tsx`:

```tsx
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/ui-web", () => ({
  Button: ({ children, ...props }: React.ComponentProps<"button">) => (
    <button type="button" {...props}>{children}</button>
  ),
  Card: ({ children }: { children: React.ReactNode }) => <div data-testid="card">{children}</div>,
  CardContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardDescription: ({ children }: { children: React.ReactNode }) => <p>{children}</p>,
  CardHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardTitle: ({ children }: { children: React.ReactNode }) => <h2>{children}</h2>,
  Input: (props: React.ComponentProps<"input">) => <input {...props} />,
  Label: ({ children, ...props }: React.ComponentProps<"label">) => (
    <label {...props}>{children}</label>
  ),
  Separator: () => <hr />,
}));

import { AuthForm } from "../auth-form";

describe("AuthForm", () => {
  const defaultProps = {
    title: "Sign In",
    description: "Enter your credentials",
    submitLabel: "Sign In",
    onSubmit: vi.fn(),
  };

  it("renders title and description", () => {
    render(<AuthForm {...defaultProps} />);
    expect(screen.getByText("Sign In")).toBeDefined();
    expect(screen.getByText("Enter your credentials")).toBeDefined();
  });

  it("renders email and password fields", () => {
    render(<AuthForm {...defaultProps} />);
    expect(screen.getByLabelText("Email")).toBeDefined();
    expect(screen.getByLabelText("Password")).toBeDefined();
  });

  it("renders submit button with custom label", () => {
    render(<AuthForm {...defaultProps} />);
    expect(screen.getByRole("button", { name: "Sign In" })).toBeDefined();
  });

  it("renders OAuth buttons when showOAuth is true", () => {
    render(<AuthForm {...defaultProps} showOAuth onOAuthClick={vi.fn()} />);
    expect(screen.getByRole("button", { name: /google/i })).toBeDefined();
    expect(screen.getByRole("button", { name: /apple/i })).toBeDefined();
    expect(screen.getByRole("button", { name: /github/i })).toBeDefined();
  });

  it("does not render OAuth buttons when showOAuth is false", () => {
    render(<AuthForm {...defaultProps} />);
    expect(screen.queryByRole("button", { name: /google/i })).toBeNull();
  });

  it("renders footer content when provided", () => {
    render(
      <AuthForm {...defaultProps} footer={<span>footer content</span>} />
    );
    expect(screen.getByText("footer content")).toBeDefined();
  });

  it("calls onSubmit with email and password", () => {
    render(<AuthForm {...defaultProps} />);
    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "test@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "password123" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign In" }));
    expect(defaultProps.onSubmit).toHaveBeenCalledWith("test@example.com", "password123");
  });

  it("displays error message when provided", () => {
    render(<AuthForm {...defaultProps} error="Invalid credentials" />);
    expect(screen.getByText("Invalid credentials")).toBeDefined();
  });

  it("disables submit button when loading", () => {
    render(<AuthForm {...defaultProps} isLoading />);
    expect(screen.getByRole("button", { name: "Sign In" })).toHaveProperty("disabled", true);
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- auth-form.test
```

Expected: FAIL — `auth-form.tsx` doesn't exist yet.

**Step 3: Write the AuthForm component**

`apps/web/components/auth-form.tsx`:

```tsx
"use client";

import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Input,
  Label,
  Separator,
} from "@infrastructure/ui-web";
import type { ReactNode } from "react";
import { useState } from "react";

interface AuthFormProps {
  title: string;
  description: string;
  submitLabel: string;
  onSubmit: (email: string, password: string) => void;
  showOAuth?: boolean;
  onOAuthClick?: (provider: "google" | "apple" | "github") => void;
  footer?: ReactNode;
  error?: string;
  isLoading?: boolean;
  /** Hide the password field (e.g., for forgot-password form). */
  hidePassword?: boolean;
}

/** Reusable auth form with email/password fields and optional OAuth buttons. */
export function AuthForm({
  title,
  description,
  submitLabel,
  onSubmit,
  showOAuth = false,
  onOAuthClick,
  footer,
  error,
  isLoading = false,
  hidePassword = false,
}: AuthFormProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    onSubmit(email, password);
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <CardTitle className="text-2xl">{title}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEmail(e.target.value)}
                required
              />
            </div>

            {!hidePassword && (
              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  placeholder="Your password"
                  value={password}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setPassword(e.target.value)}
                  required
                />
              </div>
            )}

            {error && (
              <p className="text-sm text-destructive">{error}</p>
            )}

            <Button type="submit" className="w-full" disabled={isLoading}>
              {submitLabel}
            </Button>
          </form>

          {showOAuth && (
            <>
              <div className="my-6 flex items-center gap-4">
                <Separator className="flex-1" />
                <span className="text-xs text-muted-foreground">Or continue with</span>
                <Separator className="flex-1" />
              </div>
              <div className="grid grid-cols-3 gap-3">
                <Button
                  variant="outline"
                  onClick={() => onOAuthClick?.("google")}
                  aria-label="Sign in with Google"
                >
                  Google
                </Button>
                <Button
                  variant="outline"
                  onClick={() => onOAuthClick?.("apple")}
                  aria-label="Sign in with Apple"
                >
                  Apple
                </Button>
                <Button
                  variant="outline"
                  onClick={() => onOAuthClick?.("github")}
                  aria-label="Sign in with GitHub"
                >
                  GitHub
                </Button>
              </div>
            </>
          )}

          {footer && <div className="mt-6 text-center text-sm">{footer}</div>}
        </CardContent>
      </Card>
    </div>
  );
}
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- auth-form.test
```

Expected: PASS

**Step 5: Commit**

```bash
gt modify -m "feat(web): add shared AuthForm component with email/password and OAuth"
```

---

## Task 4: Sign-In Page

**Files:**
- Create: `apps/web/app/(auth)/sign-in/page.tsx`
- Create: `apps/web/app/(auth)/sign-in/__tests__/page.test.tsx`

**Step 1: Write the test**

`apps/web/app/(auth)/sign-in/__tests__/page.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

const mockSignIn = vi.fn();
const mockSignInWithOAuth = vi.fn();

vi.mock("@infrastructure/supabase/auth", () => ({
  useAuth: () => ({
    signIn: mockSignIn,
    signInWithOAuth: mockSignInWithOAuth,
    isLoading: false,
    session: null,
    user: null,
    signUp: vi.fn(),
    signOut: vi.fn(),
  }),
}));

vi.mock("@infrastructure/navigation", () => ({
  useNavigation: () => ({
    navigate: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  }),
}));

vi.mock("@/components/auth-form", () => ({
  AuthForm: ({ title, submitLabel, footer }: {
    title: string;
    submitLabel: string;
    footer?: React.ReactNode;
  }) => (
    <div data-testid="auth-form">
      <span>{title}</span>
      <span>{submitLabel}</span>
      {footer}
    </div>
  ),
}));

import SignInPage from "../page";

describe("SignInPage", () => {
  it("renders AuthForm with sign-in title", () => {
    render(<SignInPage />);
    expect(screen.getByText("Sign In")).toBeDefined();
  });

  it("renders sign-up link", () => {
    render(<SignInPage />);
    expect(screen.getByText(/Sign Up/)).toBeDefined();
  });

  it("renders forgot password link", () => {
    render(<SignInPage />);
    expect(screen.getByText(/Forgot password/i)).toBeDefined();
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- sign-in
```

Expected: FAIL — file doesn't exist.

**Step 3: Write the sign-in page**

Create directory first:
```bash
mkdir -p apps/web/app/\(auth\)/sign-in
mkdir -p apps/web/app/\(auth\)/sign-in/__tests__
```

`apps/web/app/(auth)/sign-in/page.tsx`:

```tsx
"use client";

import { AuthForm } from "@/components/auth-form";
import { useAuth } from "@infrastructure/supabase/auth";
import { useNavigation } from "@infrastructure/navigation";
import { useState } from "react";

export default function SignInPage() {
  const { signIn, signInWithOAuth } = useAuth();
  const { replace } = useNavigation();
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(email: string, password: string) {
    setError("");
    setIsLoading(true);
    try {
      await signIn({ email, password });
      replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed");
    } finally {
      setIsLoading(false);
    }
  }

  async function handleOAuth(provider: "google" | "apple" | "github") {
    try {
      await signInWithOAuth(provider);
    } catch (err) {
      setError(err instanceof Error ? err.message : "OAuth sign in failed");
    }
  }

  return (
    <AuthForm
      title="Sign In"
      description="Enter your credentials to access your account"
      submitLabel="Sign In"
      onSubmit={handleSubmit}
      showOAuth
      onOAuthClick={handleOAuth}
      error={error}
      isLoading={isLoading}
      footer={
        <>
          <a href="/forgot-password" className="text-muted-foreground hover:text-foreground">
            Forgot password?
          </a>
          <p className="mt-2 text-muted-foreground">
            Don&apos;t have an account?{" "}
            <a href="/sign-up" className="text-foreground underline">
              Sign Up
            </a>
          </p>
        </>
      }
    />
  );
}
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- sign-in
```

Expected: PASS

**Step 5: Commit**

```bash
gt modify -m "feat(web): add sign-in page with email/password and OAuth"
```

---

## Task 5: Sign-Up Page

**Files:**
- Create: `apps/web/app/(auth)/sign-up/page.tsx`
- Create: `apps/web/app/(auth)/sign-up/__tests__/page.test.tsx`

**Step 1: Write the test**

`apps/web/app/(auth)/sign-up/__tests__/page.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/supabase/auth", () => ({
  useAuth: () => ({
    signUp: vi.fn(),
    signInWithOAuth: vi.fn(),
    isLoading: false,
    session: null,
    user: null,
    signIn: vi.fn(),
    signOut: vi.fn(),
  }),
}));

vi.mock("@infrastructure/navigation", () => ({
  useNavigation: () => ({
    navigate: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  }),
}));

vi.mock("@/components/auth-form", () => ({
  AuthForm: ({ title, submitLabel, footer }: {
    title: string;
    submitLabel: string;
    footer?: React.ReactNode;
  }) => (
    <div data-testid="auth-form">
      <span>{title}</span>
      <span>{submitLabel}</span>
      {footer}
    </div>
  ),
}));

import SignUpPage from "../page";

describe("SignUpPage", () => {
  it("renders AuthForm with sign-up title", () => {
    render(<SignUpPage />);
    expect(screen.getByText("Sign Up")).toBeDefined();
  });

  it("renders Create Account submit label", () => {
    render(<SignUpPage />);
    expect(screen.getByText("Create Account")).toBeDefined();
  });

  it("renders sign-in link", () => {
    render(<SignUpPage />);
    expect(screen.getByText(/Sign In/)).toBeDefined();
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- sign-up
```

**Step 3: Write the sign-up page**

```bash
mkdir -p apps/web/app/\(auth\)/sign-up
mkdir -p apps/web/app/\(auth\)/sign-up/__tests__
```

`apps/web/app/(auth)/sign-up/page.tsx`:

```tsx
"use client";

import { AuthForm } from "@/components/auth-form";
import { useAuth } from "@infrastructure/supabase/auth";
import { useNavigation } from "@infrastructure/navigation";
import { useState } from "react";

export default function SignUpPage() {
  const { signUp, signInWithOAuth } = useAuth();
  const { replace } = useNavigation();
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(email: string, password: string) {
    setError("");
    setIsLoading(true);
    try {
      await signUp({ email, password });
      replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign up failed");
    } finally {
      setIsLoading(false);
    }
  }

  async function handleOAuth(provider: "google" | "apple" | "github") {
    try {
      await signInWithOAuth(provider);
    } catch (err) {
      setError(err instanceof Error ? err.message : "OAuth sign in failed");
    }
  }

  return (
    <AuthForm
      title="Sign Up"
      description="Create an account to get started"
      submitLabel="Create Account"
      onSubmit={handleSubmit}
      showOAuth
      onOAuthClick={handleOAuth}
      error={error}
      isLoading={isLoading}
      footer={
        <p className="text-muted-foreground">
          Already have an account?{" "}
          <a href="/sign-in" className="text-foreground underline">
            Sign In
          </a>
        </p>
      }
    />
  );
}
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- sign-up
```

**Step 5: Commit**

```bash
gt modify -m "feat(web): add sign-up page with email/password and OAuth"
```

---

## Task 6: Forgot Password and Reset Password Pages

**Files:**
- Create: `apps/web/app/(auth)/forgot-password/page.tsx`
- Create: `apps/web/app/(auth)/forgot-password/__tests__/page.test.tsx`
- Create: `apps/web/app/(auth)/reset-password/page.tsx`
- Create: `apps/web/app/(auth)/reset-password/__tests__/page.test.tsx`

**Step 1: Write the forgot-password test**

`apps/web/app/(auth)/forgot-password/__tests__/page.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/components/auth-form", () => ({
  AuthForm: ({ title, submitLabel, footer, hidePassword }: {
    title: string;
    submitLabel: string;
    footer?: React.ReactNode;
    hidePassword?: boolean;
  }) => (
    <div data-testid="auth-form">
      <span>{title}</span>
      <span>{submitLabel}</span>
      <span data-testid="hide-password">{String(hidePassword)}</span>
      {footer}
    </div>
  ),
}));

import ForgotPasswordPage from "../page";

describe("ForgotPasswordPage", () => {
  it("renders with correct title", () => {
    render(<ForgotPasswordPage />);
    expect(screen.getByText("Forgot Password")).toBeDefined();
  });

  it("hides password field", () => {
    render(<ForgotPasswordPage />);
    expect(screen.getByTestId("hide-password").textContent).toBe("true");
  });

  it("renders back to sign-in link", () => {
    render(<ForgotPasswordPage />);
    expect(screen.getByText(/Sign In/)).toBeDefined();
  });
});
```

**Step 2: Write the reset-password test**

`apps/web/app/(auth)/reset-password/__tests__/page.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/components/auth-form", () => ({
  AuthForm: ({ title, submitLabel }: { title: string; submitLabel: string }) => (
    <div data-testid="auth-form">
      <span>{title}</span>
      <span>{submitLabel}</span>
    </div>
  ),
}));

import ResetPasswordPage from "../page";

describe("ResetPasswordPage", () => {
  it("renders with correct title", () => {
    render(<ResetPasswordPage />);
    expect(screen.getByText("Reset Password")).toBeDefined();
  });

  it("renders Update Password submit label", () => {
    render(<ResetPasswordPage />);
    expect(screen.getByText("Update Password")).toBeDefined();
  });
});
```

**Step 3: Run tests to verify they fail**

```bash
pnpm --filter web test -- forgot-password reset-password
```

**Step 4: Write the forgot-password page**

```bash
mkdir -p apps/web/app/\(auth\)/forgot-password/__tests__
mkdir -p apps/web/app/\(auth\)/reset-password/__tests__
```

`apps/web/app/(auth)/forgot-password/page.tsx`:

```tsx
"use client";

import { AuthForm } from "@/components/auth-form";
import { useState } from "react";
import { createBrowserSupabase } from "@/lib/supabase";

export default function ForgotPasswordPage() {
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [sent, setSent] = useState(false);

  async function handleSubmit(email: string) {
    setError("");
    setIsLoading(true);
    try {
      const supabase = createBrowserSupabase();
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      });
      if (resetError) throw resetError;
      setSent(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to send reset email");
    } finally {
      setIsLoading(false);
    }
  }

  if (sent) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <div className="w-full max-w-md text-center space-y-4">
          <h2 className="text-2xl font-bold">Check your email</h2>
          <p className="text-muted-foreground">
            We sent a password reset link to your email address.
          </p>
          <a href="/sign-in" className="text-sm text-muted-foreground hover:text-foreground">
            Back to Sign In
          </a>
        </div>
      </div>
    );
  }

  return (
    <AuthForm
      title="Forgot Password"
      description="Enter your email to receive a password reset link"
      submitLabel="Send Reset Link"
      onSubmit={handleSubmit}
      error={error}
      isLoading={isLoading}
      hidePassword
      footer={
        <a href="/sign-in" className="text-muted-foreground hover:text-foreground">
          Back to Sign In
        </a>
      }
    />
  );
}
```

**Step 5: Write the reset-password page**

`apps/web/app/(auth)/reset-password/page.tsx`:

```tsx
"use client";

import { AuthForm } from "@/components/auth-form";
import { useNavigation } from "@infrastructure/navigation";
import { useState } from "react";
import { createBrowserSupabase } from "@/lib/supabase";

export default function ResetPasswordPage() {
  const { replace } = useNavigation();
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(_email: string, password: string) {
    setError("");
    setIsLoading(true);
    try {
      const supabase = createBrowserSupabase();
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to reset password");
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <AuthForm
      title="Reset Password"
      description="Enter your new password"
      submitLabel="Update Password"
      onSubmit={handleSubmit}
      error={error}
      isLoading={isLoading}
      footer={
        <a href="/sign-in" className="text-muted-foreground hover:text-foreground">
          Back to Sign In
        </a>
      }
    />
  );
}
```

**Step 6: Run tests to verify they pass**

```bash
pnpm --filter web test -- forgot-password reset-password
```

**Step 7: Commit**

```bash
gt modify -m "feat(web): add forgot-password and reset-password pages"
```

---

## Task 7: Protected Layout (Auth Guard)

**Files:**
- Create: `apps/web/app/(protected)/layout.tsx`
- Create: `apps/web/app/(protected)/__tests__/layout.test.tsx`

**Step 1: Write the test**

`apps/web/app/(protected)/__tests__/layout.test.tsx`:

```tsx
import { describe, expect, it, vi } from "vitest";

const mockRedirect = vi.fn();
const mockGetUser = vi.fn();

vi.mock("next/navigation", () => ({
  redirect: mockRedirect,
}));

vi.mock("@/lib/supabase", () => ({
  createServerSupabase: () =>
    Promise.resolve({
      auth: { getUser: mockGetUser },
    }),
}));

import ProtectedLayout from "../layout";

describe("ProtectedLayout", () => {
  it("redirects to /sign-in when no user", async () => {
    mockGetUser.mockResolvedValue({ data: { user: null }, error: null });
    await ProtectedLayout({ children: <div>child</div> });
    expect(mockRedirect).toHaveBeenCalledWith("/sign-in");
  });

  it("renders children when user exists", async () => {
    mockGetUser.mockResolvedValue({
      data: { user: { id: "123", email: "test@test.com" } },
      error: null,
    });
    const result = await ProtectedLayout({ children: <div>child</div> });
    expect(result).toBeDefined();
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- layout.test
```

Note: There may be a naming conflict with the root layout test. If so, use the full path filter.

**Step 3: Write the protected layout**

```bash
mkdir -p apps/web/app/\(protected\)/__tests__
```

`apps/web/app/(protected)/layout.tsx`:

```tsx
import { redirect } from "next/navigation";
import { createServerSupabase } from "@/lib/supabase";

export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/sign-in");
  }

  return <>{children}</>;
}
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- "(protected)"
```

**Step 5: Commit**

```bash
gt modify -m "feat(web): add protected route layout with auth guard"
```

---

## Task 8: Dashboard Page

**Files:**
- Create: `apps/web/app/(protected)/dashboard/page.tsx`
- Create: `apps/web/app/(protected)/dashboard/__tests__/page.test.tsx`

**Step 1: Write the test**

`apps/web/app/(protected)/dashboard/__tests__/page.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/supabase/auth", () => ({
  useAuth: () => ({
    signOut: vi.fn(),
    user: { id: "123", email: "test@example.com" },
    isLoading: false,
    session: {},
    signIn: vi.fn(),
    signUp: vi.fn(),
    signInWithOAuth: vi.fn(),
  }),
}));

vi.mock("@infrastructure/navigation", () => ({
  useNavigation: () => ({
    navigate: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  }),
}));

vi.mock("@infrastructure/ui-web", () => ({
  Button: ({ children, ...props }: React.ComponentProps<"button">) => (
    <button type="button" {...props}>{children}</button>
  ),
  Card: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardDescription: ({ children }: { children: React.ReactNode }) => <p>{children}</p>,
  CardHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardTitle: ({ children }: { children: React.ReactNode }) => <h3>{children}</h3>,
}));

vi.mock("@/components/user-list", () => ({
  UserList: () => <div data-testid="user-list">Mocked UserList</div>,
}));

import DashboardPage from "../page";

describe("DashboardPage", () => {
  it("renders welcome message with user email", () => {
    render(<DashboardPage />);
    expect(screen.getByText(/Welcome back/)).toBeDefined();
    expect(screen.getByText(/test@example.com/)).toBeDefined();
  });

  it("renders user avatar with first letter of email", () => {
    render(<DashboardPage />);
    expect(screen.getByText("t")).toBeDefined();
  });

  it("renders sign out button", () => {
    render(<DashboardPage />);
    expect(screen.getByText("Sign Out")).toBeDefined();
  });

  it("renders settings link", () => {
    render(<DashboardPage />);
    expect(screen.getByText("Settings")).toBeDefined();
  });

  it("renders UserList component", () => {
    render(<DashboardPage />);
    expect(screen.getByTestId("user-list")).toBeDefined();
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- dashboard
```

**Step 3: Write the dashboard page**

```bash
mkdir -p apps/web/app/\(protected\)/dashboard/__tests__
```

`apps/web/app/(protected)/dashboard/page.tsx`:

```tsx
"use client";

import { UserList } from "@/components/user-list";
import { useAuth } from "@infrastructure/supabase/auth";
import { useNavigation } from "@infrastructure/navigation";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@infrastructure/ui-web";

export default function DashboardPage() {
  const { user, signOut } = useAuth();
  const { replace } = useNavigation();

  const email = user?.email ?? "User";

  async function handleSignOut() {
    await signOut();
    replace("/sign-in");
  }

  return (
    <main className="min-h-screen">
      {/* Header */}
      <header className="border-b border-border/40 bg-background">
        <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-8">
          <span className="font-semibold">Monorepo Template</span>
          <div className="flex items-center gap-4">
            <a
              href="/settings"
              className="text-sm text-muted-foreground hover:text-foreground"
            >
              Settings
            </a>
            <div className="flex items-center gap-3">
              <span className="flex size-8 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground">
                {email[0].toLowerCase()}
              </span>
              <span className="text-sm text-muted-foreground">{email}</span>
              <Button variant="ghost" size="sm" onClick={handleSignOut}>
                Sign Out
              </Button>
            </div>
          </div>
        </div>
      </header>

      {/* Content */}
      <div className="mx-auto max-w-5xl p-8 space-y-6">
        <div>
          <h1 className="text-2xl font-bold">Welcome back</h1>
          <p className="text-muted-foreground">{email}</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Users from API</CardTitle>
            <CardDescription>Data fetched from the Hono API</CardDescription>
          </CardHeader>
          <CardContent>
            <UserList />
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- dashboard
```

**Step 5: Commit**

```bash
gt modify -m "feat(web): add authenticated dashboard page"
```

---

## Task 9: Settings Page

**Files:**
- Create: `apps/web/app/(protected)/settings/page.tsx`
- Create: `apps/web/app/(protected)/settings/__tests__/page.test.tsx`

**Step 1: Write the test**

`apps/web/app/(protected)/settings/__tests__/page.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/supabase/auth", () => ({
  useAuth: () => ({
    signOut: vi.fn(),
    user: {
      id: "abc-123",
      email: "test@example.com",
      created_at: "2026-01-15T10:30:00Z",
    },
    isLoading: false,
    session: {},
    signIn: vi.fn(),
    signUp: vi.fn(),
    signInWithOAuth: vi.fn(),
  }),
}));

vi.mock("@infrastructure/navigation", () => ({
  useNavigation: () => ({
    navigate: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  }),
}));

vi.mock("@infrastructure/ui-web", () => ({
  Button: ({ children, ...props }: React.ComponentProps<"button">) => (
    <button type="button" {...props}>{children}</button>
  ),
  Card: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardDescription: ({ children }: { children: React.ReactNode }) => <p>{children}</p>,
  CardHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardTitle: ({ children }: { children: React.ReactNode }) => <h3>{children}</h3>,
}));

import SettingsPage from "../page";

describe("SettingsPage", () => {
  it("renders Settings heading", () => {
    render(<SettingsPage />);
    expect(screen.getByText("Settings")).toBeDefined();
  });

  it("renders user email", () => {
    render(<SettingsPage />);
    expect(screen.getByText("test@example.com")).toBeDefined();
  });

  it("renders user ID", () => {
    render(<SettingsPage />);
    expect(screen.getByText(/abc-123/)).toBeDefined();
  });

  it("renders sign out button", () => {
    render(<SettingsPage />);
    expect(screen.getByText("Sign Out")).toBeDefined();
  });

  it("renders back to dashboard link", () => {
    render(<SettingsPage />);
    expect(screen.getByText(/Dashboard/)).toBeDefined();
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- settings
```

**Step 3: Write the settings page**

```bash
mkdir -p apps/web/app/\(protected\)/settings/__tests__
```

`apps/web/app/(protected)/settings/page.tsx`:

```tsx
"use client";

import { useAuth } from "@infrastructure/supabase/auth";
import { useNavigation } from "@infrastructure/navigation";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@infrastructure/ui-web";

export default function SettingsPage() {
  const { user, signOut } = useAuth();
  const { replace } = useNavigation();

  async function handleSignOut() {
    await signOut();
    replace("/sign-in");
  }

  return (
    <main className="min-h-screen p-8">
      <div className="mx-auto max-w-2xl space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold">Settings</h1>
            <a
              href="/dashboard"
              className="text-sm text-muted-foreground hover:text-foreground"
            >
              &larr; Dashboard
            </a>
          </div>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Profile</CardTitle>
            <CardDescription>Your account information</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <span className="text-sm font-medium">Email</span>
              <p className="text-sm text-muted-foreground">
                {user?.email ?? "—"}
              </p>
            </div>
            <div>
              <span className="text-sm font-medium">User ID</span>
              <p className="text-sm text-muted-foreground">
                {user?.id ?? "—"}
              </p>
            </div>
            {user?.created_at && (
              <div>
                <span className="text-sm font-medium">Member since</span>
                <p className="text-sm text-muted-foreground">
                  {new Date(user.created_at).toLocaleDateString()}
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Account</CardTitle>
          </CardHeader>
          <CardContent>
            <Button variant="destructive" onClick={handleSignOut}>
              Sign Out
            </Button>
          </CardContent>
        </Card>
      </div>
    </main>
  );
}
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- settings
```

**Step 5: Commit**

```bash
gt modify -m "feat(web): add settings page with user profile and sign-out"
```

---

## Task 10: Update Root Page (Redirect)

**Files:**
- Modify: `apps/web/app/page.tsx`
- Modify: `apps/web/app/__tests__/page.test.tsx`

**Step 1: Rewrite the test**

Replace `apps/web/app/__tests__/page.test.tsx` entirely:

```tsx
import { describe, expect, it, vi } from "vitest";

const mockRedirect = vi.fn();
const mockGetUser = vi.fn();

vi.mock("next/navigation", () => ({
  redirect: mockRedirect,
}));

vi.mock("@/lib/supabase", () => ({
  createServerSupabase: () =>
    Promise.resolve({
      auth: { getUser: mockGetUser },
    }),
}));

import Home from "@/app/page";

describe("Root page", () => {
  it("redirects to /dashboard when user exists", async () => {
    mockGetUser.mockResolvedValue({
      data: { user: { id: "123" } },
      error: null,
    });
    await Home();
    expect(mockRedirect).toHaveBeenCalledWith("/dashboard");
  });

  it("redirects to /sign-in when no user", async () => {
    mockGetUser.mockResolvedValue({
      data: { user: null },
      error: null,
    });
    await Home();
    expect(mockRedirect).toHaveBeenCalledWith("/sign-in");
  });
});
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter web test -- page.test
```

Expected: FAIL — current page renders HTML, not redirects.

**Step 3: Rewrite the root page**

`apps/web/app/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { createServerSupabase } from "@/lib/supabase";

export default async function Home() {
  const supabase = await createServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    redirect("/dashboard");
  } else {
    redirect("/sign-in");
  }
}
```

**Step 4: Run test to verify it passes**

```bash
pnpm --filter web test -- page.test
```

**Step 5: Commit**

```bash
gt modify -m "feat(web): convert root page to auth-based redirect"
```

---

## Task 11: Landing Page — Tech Stack Bar and Value Props

**Files:**
- Modify: `apps/landing/components/logo-bar.tsx`
- Modify: `apps/landing/app/page.tsx`
- Modify: `apps/landing/app/__tests__/page.test.tsx`

**Step 1: Update the test first**

In `apps/landing/app/__tests__/page.test.tsx`, update the value prop assertion:

Replace:
```typescript
expect(screen.getByText("Zero Config DX")).toBeTruthy();
```
With:
```typescript
expect(screen.getByText("Auth & Storage Built In")).toBeTruthy();
```

**Step 2: Run test to verify it fails**

```bash
pnpm --filter landing test -- page.test
```

Expected: FAIL — "Zero Config DX" exists, "Auth & Storage Built In" doesn't.

**Step 3: Update logo-bar.tsx**

In `apps/landing/components/logo-bar.tsx`, add `"Supabase"` to the technologies array:

Replace:
```typescript
const technologies = [
  "Next.js",
  "Expo",
  "React Native",
  "Hono",
  "oRPC",
  "Tailwind CSS",
  "TypeScript",
  "Turborepo",
];
```
With:
```typescript
const technologies = [
  "Next.js",
  "Expo",
  "React Native",
  "Hono",
  "oRPC",
  "Supabase",
  "Tailwind CSS",
  "TypeScript",
  "Turborepo",
];
```

**Step 4: Update value props in page.tsx**

In `apps/landing/app/page.tsx`, replace the third value prop:

Replace:
```typescript
  {
    figure: "FIG 0.3",
    title: "Zero Config DX",
    description:
      "Turborepo caching, Biome linting, React Compiler, and pnpm workspaces. Everything just works out of the box.",
  },
```
With:
```typescript
  {
    figure: "FIG 0.3",
    title: "Auth & Storage Built In",
    description:
      "Supabase provides authentication, database, and file storage out of the box. Row-level security, OAuth providers, and typed queries — no backend assembly required.",
  },
```

**Step 5: Run test to verify it passes**

```bash
pnpm --filter landing test -- page.test
```

**Step 6: Commit**

```bash
gt modify -m "feat(landing): update tech stack bar and value props for Supabase"
```

---

## Task 12: Landing Page — New Feature Section 4.0 Backend + Renumber Infrastructure

**Files:**
- Modify: `apps/landing/app/page.tsx`

**Step 1: Add section 4.0 Backend and renumber Infrastructure to 5.0**

In `apps/landing/app/page.tsx`, in the `<div id="stack">` block, insert a new `FeatureSection` before the existing Infrastructure section. Then change Infrastructure's `number` from `"4.0"` to `"5.0"`.

After the section 3.0 API `FeatureSection`, add:

```tsx
        <FeatureSection
          number="4.0"
          title="Backend"
          description="Supabase for authentication, PostgreSQL database, and file storage. Row-level security scopes every query. JWT validation at the API layer. Auto-generated TypeScript types from your schema."
          features={[
            "Supabase Auth",
            "PostgreSQL",
            "Row-Level Security",
            "File Storage",
            "Generated Types",
          ]}
          codeLabel="packages/features/auth/src/example.ts"
          code={`import { useAuth } from "@infrastructure/supabase/auth";
import { createStorageClient } from "@infrastructure/supabase/storage";

// Auth — sign in with email or OAuth
const { signIn, signInWithOAuth, user } = useAuth();
await signIn({ email, password });
await signInWithOAuth("github");

// Storage — upload with RLS
const storage = createStorageClient(supabase);
await storage.upload("avatars", \`\${user.id}.png\`, file);`}
        />
```

Then change the Infrastructure section `number` from `"4.0"` to `"5.0"`.

**Step 2: Verify with tests**

```bash
pnpm --filter landing test
```

Expected: PASS (tests don't assert on section numbers directly since FeatureSection is mocked).

**Step 3: Commit**

```bash
gt modify -m "feat(landing): add Backend feature section (4.0) and renumber Infrastructure to 5.0"
```

---

## Task 13: Landing Page — Hero Updates

**Files:**
- Modify: `apps/landing/components/hero.tsx`

**Step 1: Update announcement badge**

In `apps/landing/components/hero.tsx`, replace the badge text:

Replace:
```tsx
            Now with Next.js 16, Expo SDK 54, and Hono
```
With:
```tsx
            Now with Supabase Auth, Database & Storage
```

**Step 2: Update subtitle**

Replace:
```tsx
          Ship web, mobile, and API from a single codebase. Type-safe from database to device, with
          shared packages that keep your team moving fast.
```
With:
```tsx
          Ship web, mobile, and API from a single codebase. Authentication, database, and storage
          included. Type-safe from backend to device.
```

**Step 3: Update hero test**

Check `apps/landing/components/__tests__/hero.test.tsx` and update any text assertions to match new copy.

**Step 4: Run tests**

```bash
pnpm --filter landing test -- hero
```

**Step 5: Commit**

```bash
gt modify -m "feat(landing): update hero badge and subtitle for Supabase"
```

---

## Task 14: Landing Page — Updated Browser Frame Mockup

**Files:**
- Modify: `apps/landing/components/browser-frame.tsx`
- Modify: `apps/landing/components/__tests__/browser-frame.test.tsx`

**Step 1: Update test assertions**

In `apps/landing/components/__tests__/browser-frame.test.tsx`, update tests to look for new content: "Welcome back", "user@email.com", "Sign Out", "supabase" in infrastructure badges.

**Step 2: Rewrite browser-frame.tsx**

Replace the dashboard content inside the browser frame. Keep the chrome bar (traffic lights, URL bar) and the `16:10` aspect ratio container. Replace the inner content:

```tsx
        {/* Dashboard content — 16:10 MacBook aspect ratio */}
        <div className="bg-background p-5 aspect-[16/10]">
          {/* Header bar */}
          <div className="mb-3 flex items-center justify-between">
            <div className="text-[11px] font-semibold text-foreground">Monorepo Template</div>
            <div className="flex items-center gap-2">
              <span className="flex size-4 items-center justify-center rounded-full bg-primary text-[7px] font-semibold text-primary-foreground">
                u
              </span>
              <span className="text-[8px] text-muted-foreground">user@email.com</span>
              <span className="rounded bg-muted px-1.5 py-0.5 text-[7px] text-muted-foreground">
                Sign Out
              </span>
            </div>
          </div>

          {/* Welcome */}
          <div className="mb-3">
            <div className="text-[12px] font-bold text-foreground">Welcome back</div>
            <div className="text-[8px] text-muted-foreground">user@email.com</div>
          </div>

          {/* Users card */}
          <div className="rounded-lg border border-border/60 bg-card p-2.5">
            <div className="text-[10px] font-semibold text-foreground">Users from API</div>
            <div className="mt-1.5 flex flex-col gap-1">
              {USER_ROWS.map((row) => (
                <div
                  key={row.name}
                  className="flex items-center justify-between rounded border border-border/40 px-2 py-1"
                >
                  <div>
                    <div className="text-[8px] font-medium text-foreground">{row.name}</div>
                    <div className="text-[7px] text-muted-foreground">{row.email}</div>
                  </div>
                  <div className="text-[7px] text-muted-foreground">ID: {row.id}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Infrastructure badges */}
          <div className="mt-2.5 grid grid-cols-2 gap-2.5">
            {BADGE_SECTIONS.map((section) => (
              <div key={section.label} className="rounded-lg border border-border/60 bg-card p-2.5">
                <div className="mb-1.5 text-[10px] font-semibold text-foreground">
                  {section.label}
                </div>
                <div className="flex flex-wrap gap-1">
                  {section.items.map((name) => (
                    <span
                      key={name}
                      className="rounded bg-muted px-1.5 py-0.5 text-[8px] text-muted-foreground"
                    >
                      {name}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
```

Add constants at the top of the file:

```typescript
const USER_ROWS = [
  { name: "Alex Chen", email: "alex@example.com", id: "1" },
  { name: "Sarah Park", email: "sarah@example.com", id: "2" },
] as const;

const INFRA_PACKAGES = ["api-client", "navigation", "supabase", "ui", "ui-web", "utils"] as const;
const TOOLING = ["Turborepo", "pnpm", "Biome", "Vitest", "Playwright"] as const;
const BADGE_SECTIONS = [
  { label: "Shared Infrastructure", items: INFRA_PACKAGES },
  { label: "Tooling", items: TOOLING },
] as const;
```

Remove the old `WEB_ITEMS`, `MOBILE_ITEMS`, `API_ITEMS`, `QUICK_START_CMDS` constants and the `AppCard` component since they're no longer used.

**Step 3: Run tests**

```bash
pnpm --filter landing test -- browser-frame
```

**Step 4: Commit**

```bash
gt modify -m "feat(landing): update browser frame to show authenticated dashboard"
```

---

## Task 15: Landing Page — Updated Phone Frame Mockup

**Files:**
- Modify: `apps/landing/components/phone-frame.tsx`
- Modify: `apps/landing/components/__tests__/phone-frame.test.tsx`

**Step 1: Update test assertions**

In the phone frame test, update assertions to look for: "Sign In", "Email", "Password", "Google", "Apple", "GitHub", "Sign Up".

**Step 2: Rewrite phone-frame.tsx app content**

Keep the phone bezel, Dynamic Island, status bar, and home indicator. Replace the app content section:

```tsx
          {/* App header */}
          <div className="border-b border-border/60 px-4 pb-2">
            <div className="text-[11px] font-semibold text-foreground">Monorepo Template</div>
          </div>

          {/* Sign-in form */}
          <div className="flex-1 p-4">
            <div className="mb-3 text-center">
              <div className="text-[13px] font-bold text-foreground">Sign In</div>
              <div className="mt-0.5 text-[7px] text-muted-foreground">
                Enter your credentials
              </div>
            </div>

            {/* Email field */}
            <div className="mb-2">
              <div className="mb-0.5 text-[7px] font-medium text-foreground">Email</div>
              <div className="rounded-md border border-border/60 bg-muted/30 px-2 py-1.5">
                <span className="text-[8px] text-muted-foreground/50">you@example.com</span>
              </div>
            </div>

            {/* Password field */}
            <div className="mb-3">
              <div className="mb-0.5 text-[7px] font-medium text-foreground">Password</div>
              <div className="rounded-md border border-border/60 bg-muted/30 px-2 py-1.5">
                <span className="text-[8px] text-muted-foreground/50">Your password</span>
              </div>
            </div>

            {/* Sign In button */}
            <div className="rounded-md bg-primary px-3 py-1.5 text-center">
              <span className="text-[9px] font-medium text-primary-foreground">Sign In</span>
            </div>

            {/* Divider */}
            <div className="my-3 flex items-center gap-2">
              <div className="h-px flex-1 bg-border/40" />
              <span className="text-[7px] text-muted-foreground">Or continue with</span>
              <div className="h-px flex-1 bg-border/40" />
            </div>

            {/* OAuth buttons */}
            <div className="grid grid-cols-3 gap-1.5">
              {(["Google", "Apple", "GitHub"] as const).map((provider) => (
                <div
                  key={provider}
                  className="rounded-md border border-border/60 py-1.5 text-center"
                >
                  <span className="text-[8px] font-medium text-muted-foreground">{provider}</span>
                </div>
              ))}
            </div>

            {/* Sign up link */}
            <div className="mt-3 text-center">
              <span className="text-[7px] text-muted-foreground">
                Don't have an account?{" "}
                <span className="text-foreground underline">Sign Up</span>
              </span>
            </div>
          </div>
```

Remove the old `PhoneCard` component and stacked cards content.

**Step 3: Run tests**

```bash
pnpm --filter landing test -- phone-frame
```

**Step 4: Commit**

```bash
gt modify -m "feat(landing): update phone frame to show sign-in screen"
```

---

## Task 16: Final Verification

**Step 1: Run all web tests**

```bash
pnpm --filter web test
```

Expected: All tests pass.

**Step 2: Run all landing tests**

```bash
pnpm --filter landing test
```

Expected: All tests pass.

**Step 3: Run typecheck**

```bash
pnpm typecheck
```

Expected: No type errors.

**Step 4: Run linter**

```bash
pnpm lint
```

Expected: No lint errors (run `pnpm lint:fix` if needed).

**Step 5: Run full test suite**

```bash
pnpm test
```

Expected: All tests pass across the monorepo.

**Step 6: Visual check (optional)**

If Supabase is running locally:

```bash
pnpm dev
```

- Visit `http://localhost:3000` — should redirect to `/sign-in`
- Visit `http://localhost:3002` — landing page with updated hero, tech stack, value props, sections

**Step 7: Final commit if any lint/format fixes were needed**

```bash
gt modify -m "chore: lint and format fixes"
```
