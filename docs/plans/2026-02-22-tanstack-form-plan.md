# TanStack Form + shadcn Forms Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add TanStack Form with shadcn Field components, create `@features/auth` with form schemas, and migrate all 4 auth forms.

**Architecture:** Schemas in `packages/features/auth/` (pure Zod, portable). Field UI components in `packages/infrastructure/ui-web/`. Each auth page in `apps/web/` gets its own `useForm()` with shared schemas. TanStack Form v1 uses Standard Schema spec — Zod works natively, no adapter needed.

**Tech Stack:** `@tanstack/react-form` v1.28+, Zod v4.3.6 (already in catalog), shadcn Field components, Vitest, Testing Library

---

### Task 1: Add @tanstack/react-form to pnpm catalog and install

**Files:**
- Modify: `pnpm-workspace.yaml`

**Step 1: Add to catalog**

Add `@tanstack/react-form` to the catalog section of `pnpm-workspace.yaml`, after the existing `@tanstack/react-query` entry:

```yaml
  "@tanstack/react-form": "1.28.3"
```

**Step 2: Install**

Run: `pnpm install`
Expected: Clean install, no errors.

**Step 3: Commit**

```bash
gt create -m "chore: add @tanstack/react-form to pnpm catalog"
```

---

### Task 2: Create @features/auth package scaffolding

**Files:**
- Create: `packages/features/auth/package.json`
- Create: `packages/features/auth/tsconfig.json`
- Create: `packages/features/auth/vitest.config.ts`
- Create: `packages/features/auth/src/index.ts`

**Step 1: Create package.json**

Model after `packages/features/users/package.json`. Auth only needs `zod` (no oRPC routers yet):

```json
{
  "name": "@features/auth",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "zod": "catalog:"
  },
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

**Step 2: Create tsconfig.json**

```json
{
  "extends": "@infrastructure/typescript-config/library.json",
  "compilerOptions": {
    "outDir": "dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**Step 3: Create vitest.config.ts**

Pure Zod schemas — no DOM needed:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
  },
});
```

**Step 4: Create src/index.ts**

Placeholder barrel export (populated in Task 3):

```typescript
export type {
  SignInValues,
  SignUpValues,
  ForgotPasswordValues,
  ResetPasswordValues,
} from "./contracts/authSchemas";

export {
  signInSchema,
  signUpSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
} from "./contracts/authSchemas";
```

**Step 5: Install dependencies**

Run: `pnpm install`
Expected: Clean install. New `@features/auth` package recognized.

**Step 6: Commit**

```bash
gt modify -m "feat(auth): scaffold @features/auth package"
```

---

### Task 3: Write auth form schemas with tests (TDD)

**Files:**
- Create: `packages/features/auth/src/contracts/__tests__/authSchemas.test.ts`
- Create: `packages/features/auth/src/contracts/authSchemas.ts`

**Step 1: Write failing tests**

Create `packages/features/auth/src/contracts/__tests__/authSchemas.test.ts`:

```typescript
import { describe, expect, it } from "vitest";
import {
  signInSchema,
  signUpSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
} from "../authSchemas";

describe("signInSchema", () => {
  it("accepts valid email and password", () => {
    const result = signInSchema.safeParse({ email: "user@example.com", password: "pass123" });
    expect(result.success).toBe(true);
  });

  it("rejects invalid email", () => {
    const result = signInSchema.safeParse({ email: "not-an-email", password: "pass123" });
    expect(result.success).toBe(false);
  });

  it("rejects empty password", () => {
    const result = signInSchema.safeParse({ email: "user@example.com", password: "" });
    expect(result.success).toBe(false);
  });
});

describe("signUpSchema", () => {
  it("accepts valid email and strong password", () => {
    const result = signUpSchema.safeParse({ email: "user@example.com", password: "longpass8" });
    expect(result.success).toBe(true);
  });

  it("rejects password shorter than 8 characters", () => {
    const result = signUpSchema.safeParse({ email: "user@example.com", password: "short" });
    expect(result.success).toBe(false);
  });

  it("rejects invalid email", () => {
    const result = signUpSchema.safeParse({ email: "bad", password: "longpass8" });
    expect(result.success).toBe(false);
  });
});

describe("forgotPasswordSchema", () => {
  it("accepts valid email", () => {
    const result = forgotPasswordSchema.safeParse({ email: "user@example.com" });
    expect(result.success).toBe(true);
  });

  it("rejects invalid email", () => {
    const result = forgotPasswordSchema.safeParse({ email: "nope" });
    expect(result.success).toBe(false);
  });
});

describe("resetPasswordSchema", () => {
  it("accepts matching passwords", () => {
    const result = resetPasswordSchema.safeParse({
      password: "newpass88",
      confirmPassword: "newpass88",
    });
    expect(result.success).toBe(true);
  });

  it("rejects mismatched passwords", () => {
    const result = resetPasswordSchema.safeParse({
      password: "newpass88",
      confirmPassword: "different",
    });
    expect(result.success).toBe(false);
  });

  it("rejects short password", () => {
    const result = resetPasswordSchema.safeParse({
      password: "short",
      confirmPassword: "short",
    });
    expect(result.success).toBe(false);
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `pnpm --filter @features/auth test`
Expected: FAIL — `authSchemas` module not found.

**Step 3: Write schemas**

Create `packages/features/auth/src/contracts/authSchemas.ts`:

```typescript
import { z } from "zod";

/** Schema for sign-in form: email + password (any length). */
export const signInSchema = z.object({
  email: z.email("Please enter a valid email"),
  password: z.string().min(1, "Password is required"),
});

export type SignInValues = z.infer<typeof signInSchema>;

/** Schema for sign-up form: email + password (min 8 characters). */
export const signUpSchema = z.object({
  email: z.email("Please enter a valid email"),
  password: z.string().min(8, "Password must be at least 8 characters"),
});

export type SignUpValues = z.infer<typeof signUpSchema>;

/** Schema for forgot-password form: email only. */
export const forgotPasswordSchema = z.object({
  email: z.email("Please enter a valid email"),
});

export type ForgotPasswordValues = z.infer<typeof forgotPasswordSchema>;

/** Schema for reset-password form: password + confirmPassword must match. */
export const resetPasswordSchema = z
  .object({
    password: z.string().min(8, "Password must be at least 8 characters"),
    confirmPassword: z.string().min(1, "Please confirm your password"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords don't match",
    path: ["confirmPassword"],
  });

export type ResetPasswordValues = z.infer<typeof resetPasswordSchema>;
```

**Step 4: Run tests to verify they pass**

Run: `pnpm --filter @features/auth test`
Expected: All 9 tests PASS.

**Step 5: Commit**

```bash
gt modify -m "feat(auth): add auth form Zod schemas with tests"
```

---

### Task 4: Add shadcn Field components to @infrastructure/ui-web

**Files:**
- Create: `packages/infrastructure/ui-web/src/components/field.tsx`
- Modify: `packages/infrastructure/ui-web/src/index.ts`
- Create: `packages/infrastructure/ui-web/src/__tests__/field.test.tsx`

**Step 1: Write failing tests**

Create `packages/infrastructure/ui-web/src/__tests__/field.test.tsx`:

```typescript
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Field, FieldError, FieldLabel } from "../index";

describe("Field", () => {
  it("renders children", () => {
    render(<Field>field content</Field>);
    expect(screen.getByText("field content")).toBeDefined();
  });

  it("sets data-invalid attribute", () => {
    render(<Field data-invalid={true}>content</Field>);
    const field = screen.getByRole("group");
    expect(field.getAttribute("data-invalid")).toBe("true");
  });
});

describe("FieldLabel", () => {
  it("renders label text", () => {
    render(<FieldLabel>Email</FieldLabel>);
    expect(screen.getByText("Email")).toBeDefined();
  });

  it("associates with input via htmlFor", () => {
    render(<FieldLabel htmlFor="email-input">Email</FieldLabel>);
    const label = screen.getByText("Email");
    expect(label.getAttribute("for")).toBe("email-input");
  });
});

describe("FieldError", () => {
  it("renders nothing when no errors", () => {
    const { container } = render(<FieldError errors={[]} />);
    expect(container.innerHTML).toBe("");
  });

  it("renders single error message", () => {
    render(<FieldError errors={[{ message: "Required" }]} />);
    expect(screen.getByText("Required")).toBeDefined();
  });

  it("renders multiple error messages as list", () => {
    render(
      <FieldError
        errors={[{ message: "Too short" }, { message: "Must contain number" }]}
      />
    );
    expect(screen.getByText("Too short")).toBeDefined();
    expect(screen.getByText("Must contain number")).toBeDefined();
  });

  it("has role=alert for accessibility", () => {
    render(<FieldError errors={[{ message: "Error" }]} />);
    expect(screen.getByRole("alert")).toBeDefined();
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `pnpm --filter @infrastructure/ui-web test`
Expected: FAIL — Field, FieldError, FieldLabel not found in exports.

**Step 3: Create field.tsx**

Create `packages/infrastructure/ui-web/src/components/field.tsx`. This is the shadcn Field component adapted to our monorepo imports:

```tsx
"use client";

import { useMemo } from "react";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@infrastructure/ui";
import { Label } from "./label";
import { Separator } from "./separator";

/** Wrapper for a group of related form fields. */
function FieldSet({ className, ...props }: React.ComponentProps<"fieldset">) {
  return (
    <fieldset
      data-slot="field-set"
      className={cn(
        "flex flex-col gap-6",
        "has-[>[data-slot=checkbox-group]]:gap-3 has-[>[data-slot=radio-group]]:gap-3",
        className,
      )}
      {...props}
    />
  );
}

/** Legend for a FieldSet. Supports "legend" and "label" variants. */
function FieldLegend({
  className,
  variant = "legend",
  ...props
}: React.ComponentProps<"legend"> & { variant?: "legend" | "label" }) {
  return (
    <legend
      data-slot="field-legend"
      data-variant={variant}
      className={cn(
        "mb-3 font-medium",
        "data-[variant=legend]:text-base",
        "data-[variant=label]:text-sm",
        className,
      )}
      {...props}
    />
  );
}

/** Container for a group of Field components. */
function FieldGroup({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="field-group"
      className={cn(
        "group/field-group @container/field-group flex w-full flex-col gap-7 data-[slot=checkbox-group]:gap-3 [&>[data-slot=field-group]]:gap-4",
        className,
      )}
      {...props}
    />
  );
}

const fieldVariants = cva(
  "group/field flex w-full gap-3 data-[invalid=true]:text-destructive",
  {
    variants: {
      orientation: {
        vertical: ["flex-col [&>*]:w-full [&>.sr-only]:w-auto"],
        horizontal: [
          "flex-row items-center",
          "[&>[data-slot=field-label]]:flex-auto",
          "has-[>[data-slot=field-content]]:items-start has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px",
        ],
        responsive: [
          "flex-col [&>*]:w-full [&>.sr-only]:w-auto @md/field-group:flex-row @md/field-group:items-center @md/field-group:[&>*]:w-auto",
          "@md/field-group:[&>[data-slot=field-label]]:flex-auto",
          "@md/field-group:has-[>[data-slot=field-content]]:items-start @md/field-group:has-[>[data-slot=field-content]]:[&>[role=checkbox],[role=radio]]:mt-px",
        ],
      },
    },
    defaultVariants: {
      orientation: "vertical",
    },
  },
);

/** Single form field wrapper with validation state and orientation support. */
function Field({
  className,
  orientation = "vertical",
  ...props
}: React.ComponentProps<"div"> & VariantProps<typeof fieldVariants>) {
  return (
    <div
      role="group"
      data-slot="field"
      data-orientation={orientation}
      className={cn(fieldVariants({ orientation }), className)}
      {...props}
    />
  );
}

/** Content wrapper inside a Field, for stacking label + input + error. */
function FieldContent({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="field-content"
      className={cn(
        "group/field-content flex flex-1 flex-col gap-1.5 leading-snug",
        className,
      )}
      {...props}
    />
  );
}

/** Label for a form field. Wraps the shared Label component with field-aware styling. */
function FieldLabel({
  className,
  ...props
}: React.ComponentProps<typeof Label>) {
  return (
    <Label
      data-slot="field-label"
      className={cn(
        "group/field-label peer/field-label flex w-fit gap-2 leading-snug group-data-[disabled=true]/field:opacity-50",
        "has-[>[data-slot=field]]:w-full has-[>[data-slot=field]]:flex-col has-[>[data-slot=field]]:rounded-md has-[>[data-slot=field]]:border [&>*]:data-[slot=field]:p-4",
        "has-data-[state=checked]:bg-primary/5 has-data-[state=checked]:border-primary dark:has-data-[state=checked]:bg-primary/10",
        className,
      )}
      {...props}
    />
  );
}

/** Non-interactive title inside a field (use FieldLabel for interactive labels). */
function FieldTitle({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="field-label"
      className={cn(
        "flex w-fit items-center gap-2 text-sm leading-snug font-medium group-data-[disabled=true]/field:opacity-50",
        className,
      )}
      {...props}
    />
  );
}

/** Help text below a form field. */
function FieldDescription({ className, ...props }: React.ComponentProps<"p">) {
  return (
    <p
      data-slot="field-description"
      className={cn(
        "text-muted-foreground text-sm leading-normal font-normal group-has-[[data-orientation=horizontal]]/field:text-balance",
        "last:mt-0 nth-last-2:-mt-1 [[data-variant=legend]+&]:-mt-1.5",
        "[&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
        className,
      )}
      {...props}
    />
  );
}

/** Visual separator between fields, optionally with text content. */
function FieldSeparator({
  children,
  className,
  ...props
}: React.ComponentProps<"div"> & {
  children?: React.ReactNode;
}) {
  return (
    <div
      data-slot="field-separator"
      data-content={!!children}
      className={cn(
        "relative -my-2 h-5 text-sm group-data-[variant=outline]/field-group:-mb-2",
        className,
      )}
      {...props}
    >
      <Separator className="absolute inset-0 top-1/2" />
      {children && (
        <span
          className="bg-background text-muted-foreground relative mx-auto block w-fit px-2"
          data-slot="field-separator-content"
        >
          {children}
        </span>
      )}
    </div>
  );
}

/** Displays validation error messages. Accepts TanStack Form's meta.errors array. */
function FieldError({
  className,
  children,
  errors,
  ...props
}: React.ComponentProps<"div"> & {
  errors?: Array<{ message?: string } | undefined>;
}) {
  const content = useMemo(() => {
    if (children) {
      return children;
    }

    if (!errors?.length) {
      return null;
    }

    const uniqueErrors = [
      ...new Map(errors.map((error) => [error?.message, error])).values(),
    ];

    if (uniqueErrors?.length === 1) {
      return uniqueErrors[0]?.message;
    }

    return (
      <ul className="ml-4 flex list-disc flex-col gap-1">
        {uniqueErrors.map(
          (error, index) =>
            error?.message && <li key={index}>{error.message}</li>,
        )}
      </ul>
    );
  }, [children, errors]);

  if (!content) {
    return null;
  }

  return (
    <div
      role="alert"
      data-slot="field-error"
      className={cn("text-destructive text-sm font-normal", className)}
      {...props}
    >
      {content}
    </div>
  );
}

export {
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FieldLegend,
  FieldSeparator,
  FieldSet,
  FieldTitle,
};
```

**Step 4: Update barrel export**

Add to `packages/infrastructure/ui-web/src/index.ts`:

```typescript
export {
  Field,
  FieldContent,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FieldLegend,
  FieldSeparator,
  FieldSet,
  FieldTitle,
} from "./components/field";
```

**Step 5: Run tests to verify they pass**

Run: `pnpm --filter @infrastructure/ui-web test`
Expected: All field tests PASS (plus existing exports tests).

**Step 6: Commit**

```bash
gt modify -m "feat(ui-web): add shadcn Field components for form building"
```

---

### Task 5: Add @tanstack/react-form + @features/auth to apps/web

**Files:**
- Modify: `apps/web/package.json`

**Step 1: Add dependencies**

Add to `apps/web/package.json` dependencies:

```json
"@features/auth": "workspace:*",
"@tanstack/react-form": "catalog:",
```

**Step 2: Install**

Run: `pnpm install`
Expected: Clean install.

**Step 3: Commit**

```bash
gt modify -m "chore(web): add @features/auth and @tanstack/react-form deps"
```

---

### Task 6: Migrate sign-in form

**Files:**
- Modify: `apps/web/app/(auth)/sign-in/sign-in-form.tsx`

**Step 1: Rewrite sign-in form**

Replace `apps/web/app/(auth)/sign-in/sign-in-form.tsx` with:

```tsx
"use client";

import { signInSchema } from "@features/auth";
import { Link, useNavigation } from "@infrastructure/navigation";
import { useAuth } from "@infrastructure/supabase/auth";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
} from "@infrastructure/ui-web";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { toast } from "sonner";

const isDev = process.env.NODE_ENV === "development";

/** Client-side sign-in form with email/password validation and OAuth support. */
export function SignInForm() {
  const { signIn } = useAuth();
  const { replace } = useNavigation();
  const [serverError, setServerError] = useState("");

  const form = useForm({
    defaultValues: {
      email: isDev ? "demo@example.com" : "",
      password: isDev ? "demo1234" : "",
    },
    validators: {
      onBlur: signInSchema,
      onSubmit: signInSchema,
    },
    onSubmit: async ({ value }) => {
      setServerError("");
      try {
        await signIn({ email: value.email, password: value.password });
        replace("/dashboard");
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Sign in failed");
      }
    },
  });

  function handleOAuth(provider: "google" | "apple" | "github") {
    toast.info(`TODO: Implement OAuth sign-in for ${provider}`);
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Sign In</CardTitle>
          <CardDescription>Enter your credentials to access your account</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              form.handleSubmit();
            }}
          >
            <div className="flex flex-col gap-4">
              <form.Field
                name="email"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Email</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="email"
                        placeholder="you@example.com"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                        disabled={isDev}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              <form.Field
                name="password"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Password</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="password"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                        disabled={isDev}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              {serverError && <p className="text-sm text-destructive">{serverError}</p>}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Sign In
              </Button>
            </div>
          </form>
          <div className="mt-4 space-y-4">
            <div className="relative justify-center flex">
              <span className="bg-card px-2 text-xs text-muted-foreground">Or continue with</span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              <Button variant="outline" aria-label="Continue with Google" onClick={() => handleOAuth("google")}>
                Google
              </Button>
              <Button variant="outline" aria-label="Continue with Apple" onClick={() => handleOAuth("apple")}>
                Apple
              </Button>
              <Button variant="outline" aria-label="Continue with GitHub" onClick={() => handleOAuth("github")}>
                GitHub
              </Button>
            </div>
          </div>
          <div className="mt-4 text-center text-sm">
            <Link href="/forgot-password" className="text-muted-foreground hover:text-foreground">
              Forgot password?
            </Link>
            <p className="mt-2 text-muted-foreground">
              Don&apos;t have an account?{" "}
              <Link href="/sign-up" className="text-foreground underline">
                Sign Up
              </Link>
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

**Step 2: Verify typecheck**

Run: `pnpm --filter web typecheck`
Expected: No type errors.

**Step 3: Commit**

```bash
gt modify -m "feat(web): migrate sign-in form to TanStack Form + Zod validation"
```

---

### Task 7: Migrate sign-up form

**Files:**
- Modify: `apps/web/app/(auth)/sign-up/sign-up-form.tsx`

**Step 1: Rewrite sign-up form**

Replace `apps/web/app/(auth)/sign-up/sign-up-form.tsx` with:

```tsx
"use client";

import { signUpSchema } from "@features/auth";
import { Link } from "@infrastructure/navigation";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
} from "@infrastructure/ui-web";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { toast } from "sonner";

/** Client-side sign-up form with email/password validation and OAuth support. */
export function SignUpForm() {
  const [serverError, setServerError] = useState("");

  const form = useForm({
    defaultValues: { email: "", password: "" },
    validators: {
      onBlur: signUpSchema,
      onSubmit: signUpSchema,
    },
    onSubmit: async ({ value: _value }) => {
      setServerError("");
      try {
        // TODO: Implement sign-up logic (e.g. signUp({ email, password }) via your auth provider)
        toast.info("TODO: Implement sign-up logic");
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Sign up failed");
      }
    },
  });

  function handleOAuth(provider: "google" | "apple" | "github") {
    toast.info(`TODO: Implement OAuth sign-up for ${provider}`);
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Sign Up</CardTitle>
          <CardDescription>Create an account to get started</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              form.handleSubmit();
            }}
          >
            <div className="flex flex-col gap-4">
              <form.Field
                name="email"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Email</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="email"
                        placeholder="you@example.com"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              <form.Field
                name="password"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Password</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="password"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              {serverError && <p className="text-sm text-destructive">{serverError}</p>}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Create Account
              </Button>
            </div>
          </form>
          <div className="mt-4 space-y-4">
            <div className="relative justify-center flex">
              <span className="bg-card px-2 text-xs text-muted-foreground">Or continue with</span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              <Button variant="outline" aria-label="Continue with Google" onClick={() => handleOAuth("google")}>
                Google
              </Button>
              <Button variant="outline" aria-label="Continue with Apple" onClick={() => handleOAuth("apple")}>
                Apple
              </Button>
              <Button variant="outline" aria-label="Continue with GitHub" onClick={() => handleOAuth("github")}>
                GitHub
              </Button>
            </div>
          </div>
          <div className="mt-4 text-center text-sm">
            <p className="text-muted-foreground">
              Already have an account?{" "}
              <Link href="/sign-in" className="text-foreground underline">
                Sign In
              </Link>
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

**Step 2: Verify typecheck**

Run: `pnpm --filter web typecheck`
Expected: No type errors.

**Step 3: Commit**

```bash
gt modify -m "feat(web): migrate sign-up form to TanStack Form + Zod validation"
```

---

### Task 8: Migrate forgot-password form

**Files:**
- Modify: `apps/web/app/(auth)/forgot-password/forgot-password-form.tsx`

**Step 1: Rewrite forgot-password form**

Replace `apps/web/app/(auth)/forgot-password/forgot-password-form.tsx` with:

```tsx
"use client";

import { forgotPasswordSchema } from "@features/auth";
import { Link } from "@infrastructure/navigation";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
} from "@infrastructure/ui-web";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { toast } from "sonner";

/** Client-side forgot-password form that sends a password reset email. */
export function ForgotPasswordForm() {
  const [serverError, setServerError] = useState("");
  const [sent, setSent] = useState(false);

  const form = useForm({
    defaultValues: { email: "" },
    validators: {
      onBlur: forgotPasswordSchema,
      onSubmit: forgotPasswordSchema,
    },
    onSubmit: async ({ value: _value }) => {
      setServerError("");
      try {
        // TODO: Implement password reset email (e.g. supabase.auth.resetPasswordForEmail(email))
        toast.info("TODO: Implement password reset email");
        setSent(true);
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Failed to send reset email");
      }
    },
  });

  if (sent) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <div className="w-full max-w-md space-y-4 text-center">
          <h2 className="text-2xl font-bold">Check your email</h2>
          <p className="text-muted-foreground">
            We sent a password reset link to your email address.
          </p>
          <Link href="/sign-in" className="text-sm text-muted-foreground hover:text-foreground">
            Back to Sign In
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Forgot Password</CardTitle>
          <CardDescription>Enter your email to receive a password reset link</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              form.handleSubmit();
            }}
          >
            <div className="flex flex-col gap-4">
              <form.Field
                name="email"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Email</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="email"
                        placeholder="you@example.com"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              {serverError && <p className="text-sm text-destructive">{serverError}</p>}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Send Reset Link
              </Button>
            </div>
          </form>
          <div className="mt-4 text-center text-sm">
            <Link href="/sign-in" className="text-muted-foreground hover:text-foreground">
              Back to Sign In
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

**Step 2: Verify typecheck**

Run: `pnpm --filter web typecheck`
Expected: No type errors.

**Step 3: Commit**

```bash
gt modify -m "feat(web): migrate forgot-password form to TanStack Form + Zod validation"
```

---

### Task 9: Migrate reset-password form

**Files:**
- Modify: `apps/web/app/(auth)/reset-password/reset-password-form.tsx`

Note: This form is different from the others — it has `password` + `confirmPassword` fields (no email). The `resetPasswordSchema` includes a `.refine()` for matching passwords.

**Step 1: Rewrite reset-password form**

Replace `apps/web/app/(auth)/reset-password/reset-password-form.tsx` with:

```tsx
"use client";

import { resetPasswordSchema } from "@features/auth";
import { Link } from "@infrastructure/navigation";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
} from "@infrastructure/ui-web";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { toast } from "sonner";

/** Client-side reset-password form for setting a new password. */
export function ResetPasswordForm() {
  const [serverError, setServerError] = useState("");

  const form = useForm({
    defaultValues: { password: "", confirmPassword: "" },
    validators: {
      onBlur: resetPasswordSchema,
      onSubmit: resetPasswordSchema,
    },
    onSubmit: async ({ value: _value }) => {
      setServerError("");
      try {
        // TODO: Implement password reset logic (e.g. supabase.auth.updateUser({ password }))
        toast.info("TODO: Implement password reset logic");
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Failed to reset password");
      }
    },
  });

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Reset Password</CardTitle>
          <CardDescription>Enter your new password</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              form.handleSubmit();
            }}
          >
            <div className="flex flex-col gap-4">
              <form.Field
                name="password"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>New Password</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="password"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              <form.Field
                name="confirmPassword"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Confirm Password</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="password"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              {serverError && <p className="text-sm text-destructive">{serverError}</p>}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Update Password
              </Button>
            </div>
          </form>
          <div className="mt-4 text-center text-sm">
            <Link href="/sign-in" className="text-muted-foreground hover:text-foreground">
              Back to Sign In
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

**Step 2: Verify typecheck**

Run: `pnpm --filter web typecheck`
Expected: No type errors.

**Step 3: Commit**

```bash
gt modify -m "feat(web): migrate reset-password form to TanStack Form + Zod validation"
```

---

### Task 10: Remove old AuthForm component and update tests

**Files:**
- Delete: `apps/web/components/auth-form.tsx`
- Delete: `apps/web/components/__tests__/auth-form.test.tsx`

**Step 1: Verify no remaining imports**

Search for any remaining imports of `auth-form`:

Run: `grep -r "auth-form" apps/web/ --include="*.ts" --include="*.tsx"`
Expected: No results (all 4 forms now import directly from `@infrastructure/ui-web` and `@features/auth`).

**Step 2: Delete files**

Delete `apps/web/components/auth-form.tsx` and `apps/web/components/__tests__/auth-form.test.tsx`.

**Step 3: Verify typecheck and tests**

Run: `pnpm --filter web typecheck && pnpm --filter web test`
Expected: No type errors. Tests pass (the auth-form tests are gone, any remaining tests still pass).

**Step 4: Commit**

```bash
gt modify -m "refactor(web): remove old AuthForm component (replaced by TanStack Form)"
```

---

### Task 11: Update CLAUDE.md documentation

**Files:**
- Modify: `.claude/CLAUDE.md`

**Step 1: Update Architecture section**

In the Architecture section, under "Features", add:

```markdown
  - `@features/auth` — Auth form Zod schemas (signIn, signUp, forgotPassword, resetPassword); portable across web and mobile
```

Update `@infrastructure/ui-web` description:

```markdown
  - `@infrastructure/ui-web` — Shared shadcn/ui components (Button, Card, Field, FieldError, FieldLabel, Input, Label, etc.) for web apps
```

**Step 2: Add "Forms (TanStack Form)" to Key Patterns section**

Add a new subsection after the "Navigation" subsection:

```markdown
### Forms (TanStack Form)

Forms use TanStack Form (`@tanstack/react-form`) for state management with Zod schemas for validation. Field UI components come from `@infrastructure/ui-web` (shadcn Field, FieldLabel, FieldError).

**Pattern:**
- **Schemas**: Feature packages own form schemas (e.g., `@features/auth` owns `signInSchema`). Schemas are pure Zod — no TanStack Form coupling, portable to mobile.
- **UI**: `Field`, `FieldLabel`, `FieldError` from `@infrastructure/ui-web` wrap inputs with validation state and accessible error display.
- **Validation timing**: `onBlur` + `onSubmit` (default). Users see errors after leaving a field, not while typing.
- **Server errors**: Caught in `onSubmit`, displayed as a top-level error message or toast — not via TanStack Form's field errors.

```typescript
import { signInSchema } from "@features/auth";
import { Field, FieldError, FieldLabel, Input, Button } from "@infrastructure/ui-web";
import { useForm } from "@tanstack/react-form";

const form = useForm({
  defaultValues: { email: "", password: "" },
  validators: { onBlur: signInSchema, onSubmit: signInSchema },
  onSubmit: async ({ value }) => { /* handle submit */ },
});

// In JSX:
<form.Field name="email" children={(field) => {
  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
  return (
    <Field data-invalid={isInvalid}>
      <FieldLabel htmlFor={field.name}>Email</FieldLabel>
      <Input
        id={field.name}
        value={field.state.value}
        onBlur={field.handleBlur}
        onChange={(e) => field.handleChange(e.target.value)}
        aria-invalid={isInvalid}
      />
      <FieldError errors={field.state.meta.errors} />
    </Field>
  );
}} />
```

**Gotcha**: TanStack Form v1 uses Standard Schema spec — Zod works natively. No `@tanstack/zod-form-adapter` needed.

**Gotcha**: Zod `.refine()` cross-field validation (e.g., password confirmation) works at the form level but field-level `onBlur` won't catch cross-field issues until submit. Design forms so cross-field checks are visible on submit.
```

**Step 3: Commit**

```bash
gt modify -m "docs: add TanStack Form pattern and @features/auth to CLAUDE.md"
```

---

### Task 12: Final verification

**Step 1: Full typecheck**

Run: `pnpm typecheck`
Expected: No type errors across all packages.

**Step 2: Full test suite**

Run: `pnpm test`
Expected: All tests pass (including new schema tests and field component tests).

**Step 3: Lint and format**

Run: `pnpm lint:fix && pnpm format`
Expected: No errors.

**Step 4: Commit any formatting fixes**

If lint/format made changes:

```bash
gt modify -m "style: fix formatting after TanStack Form migration"
```

**Step 5: Submit PR**

Run: `gt submit`
Expected: PR created targeting `staging`.

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Add @tanstack/react-form to catalog | `pnpm-workspace.yaml` |
| 2 | Scaffold @features/auth package | `packages/features/auth/*` |
| 3 | Auth schemas + tests (TDD) | `packages/features/auth/src/contracts/*` |
| 4 | shadcn Field components + tests | `packages/infrastructure/ui-web/src/components/field.tsx` |
| 5 | Add deps to apps/web | `apps/web/package.json` |
| 6 | Migrate sign-in form | `apps/web/app/(auth)/sign-in/sign-in-form.tsx` |
| 7 | Migrate sign-up form | `apps/web/app/(auth)/sign-up/sign-up-form.tsx` |
| 8 | Migrate forgot-password form | `apps/web/app/(auth)/forgot-password/forgot-password-form.tsx` |
| 9 | Migrate reset-password form | `apps/web/app/(auth)/reset-password/reset-password-form.tsx` |
| 10 | Remove old AuthForm + tests | `apps/web/components/auth-form.tsx` |
| 11 | Update CLAUDE.md | `.claude/CLAUDE.md` |
| 12 | Final verification | typecheck, test, lint, submit |
