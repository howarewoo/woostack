# CI Environment Variables for Web Build

**Date:** 2026-02-21
**Status:** Approved

## Problem

`web:build` fails in CI (PR #49) because `apps/web/middleware.ts` validates `NEXT_PUBLIC_SUPABASE_URL` at module scope. The env vars are set in the GitHub `Staging` environment as Variables, but GitHub Actions does not auto-pass `vars.*` as process environment variables.

## Root Cause

`apps/web/middleware.ts` lines 3-8 perform eager validation:

```typescript
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
if (!supabaseUrl || !supabasePublishableKey) {
  throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL or ...");
}
```

Next.js evaluates middleware at build time during static page generation, causing the `/_not-found` prerender to crash.

## Solution

Add an `env:` block to the Build step in `.github/workflows/ci.yml` mapping the two Supabase public variables from `vars.*` context.

## Scope

Single file: `.github/workflows/ci.yml`, Build step only.
