# TanStack Form + shadcn Integration Design

**Date**: 2026-02-22
**Status**: Approved

## Goal

Add TanStack Form with shadcn Field components to the monorepo. Migrate existing auth forms. Design for future mobile reuse.

## Scope

- **Apps**: `apps/web` + `apps/landing` (both get TanStack Form)
- **Auth forms**: Retrofit all 4 (sign-in, sign-up, forgot-password, reset-password)
- **Mobile**: Schemas shared now; mobile UI layer deferred
- **Future forms**: Auth forms only for now; pattern established for future use

## Architecture

### Package Layout

```
packages/features/auth/
  src/
    contracts/
      authSchemas.ts          # Zod schemas for auth forms
    index.ts                  # Barrel export

packages/infrastructure/ui-web/
  src/components/
    field.tsx                 # Field, FieldLabel, FieldError (shadcn)
    index.ts                  # Updated barrel

apps/web/app/(auth)/
  sign-in/sign-in-form.tsx   # Migrated to useForm() + shared schema
  sign-up/sign-up-form.tsx
  forgot-password/forgot-password-form.tsx
  reset-password/reset-password-form.tsx
```

### Dependency Flow

```
apps/web ──> @infrastructure/ui-web (Field, Input, Button)
         ──> @features/auth (authSchemas)
         ──> @tanstack/react-form (useForm)

apps/landing ──> same

(future) apps/mobile ──> @features/auth (schemas only)
                     ──> own RN form components
```

### New Dependencies

| Package | Location | Purpose |
|---------|----------|---------|
| `@tanstack/react-form` | pnpm catalog | Headless form state management |
| `@tanstack/zod-form-adapter` | pnpm catalog | Zod validation integration |

## Auth Form Schemas

Located in `packages/features/auth/src/contracts/authSchemas.ts`:

- `signInSchema`: email + password (min 1)
- `signUpSchema`: email + password (min 8)
- `forgotPasswordSchema`: email only
- `resetPasswordSchema`: password + confirmPassword with refine match

Schemas are pure Zod — no TanStack Form coupling. Portable to mobile.

Uses Zod v4 syntax: `z.email()` instead of `z.string().email()`.

## Field Components

In `@infrastructure/ui-web/src/components/field.tsx`:

- `Field` — wrapper div with `data-invalid` attribute
- `FieldLabel` — label with htmlFor binding
- `FieldError` — renders validation error messages from TanStack Form's `meta.errors`

These are generic form field components, not auth-specific.

## Migrated Auth Form Pattern

Each auth page gets its own `useForm()` with shared schemas:

```typescript
const form = useForm({
  defaultValues: { email: "", password: "" },
  validators: { onBlur: signInSchema, onSubmit: signInSchema },
  onSubmit: async ({ value }) => {
    await signIn(value.email, value.password);
    navigate("/dashboard");
  },
});
```

Key changes from current pattern:
- `AuthForm` presentational component simplified or removed
- Each form directly uses `useForm()` + Field components
- Validation: **onBlur + onSubmit** (default)
- Submit state via `form.state.isSubmitting`

## Error Handling

- **Field errors**: Inline via `<FieldError>` after blur/submit (automatic via Zod adapter)
- **Server errors**: Caught in `onSubmit`, displayed as top-level form error or toast
- **Network errors**: Caught in `onSubmit`, displayed as toast
- **Double-submit**: Button disabled via `form.state.isSubmitting`

## Testing

- **Schema tests** (`packages/features/auth/src/contracts/__tests__/authSchemas.test.ts`): Pure Zod validation — valid/invalid inputs
- **Form component tests** (`apps/web/app/(auth)/*/__tests__/`): Render, blur validation, submit, server error display
- **Field component tests** (`packages/infrastructure/ui-web/src/components/__tests__/field.test.tsx`): Rendering, error display, data-invalid attribute

## Documentation Updates

- **CLAUDE.md**: Add TanStack Form to "Key Patterns" section
- **CLAUDE.md**: Update `@infrastructure/ui-web` description
- **CLAUDE.md**: Add `@features/auth` to architecture section
- **CLAUDE.md**: Add form-related gotchas (Zod v4 syntax, validation timing)

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Schema location | `@features/auth` | Feature packages own their contracts |
| UI components location | `@infrastructure/ui-web` | Shared across web apps |
| Validation timing | onBlur + onSubmit | Good UX balance |
| Mobile support | Schemas shared, UI deferred | YAGNI for mobile UI layer |
| AuthForm wrapper | Removed | Each form uses useForm() directly |
