# Supabase Publishable/Secret Key Naming Update

**Date:** 2026-02-21
**Status:** Approved

## Overview

Update the Supabase integration to use Supabase's new API key terminology. The legacy `anon` and `service_role` JWT-based keys are being replaced by `publishable` (`sb_publishable_...`) and `secret` (`sb_secret_...`) keys. Since this is the initial Supabase implementation (not yet shipped), we adopt the new naming from the start with no backward compatibility.

**References:**
- [Supabase API Keys docs](https://supabase.com/docs/guides/api/api-keys)
- [Upcoming changes discussion](https://github.com/orgs/supabase/discussions/29260)
- [Migration discussion](https://github.com/orgs/supabase/discussions/40300)

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Approach | Big-bang rename | Initial implementation, no backward compat needed |
| Server publishable env var | `SUPABASE_PUBLISHABLE_KEY` | Mirrors client-side naming, matches Supabase direction |
| Server secret env var | `SUPABASE_SECRET_KEY` | Aligns with `sb_secret_...` key format |
| Internal variable names | Rename all | `supabaseAnonKey` → `supabasePublishableKey`, `supabaseServiceKey` → `supabaseSecretKey` |
| Key format validation | No | Local Supabase doesn't use `sb_publishable_` prefix; would break local dev |

## Environment Variable Renames

| Old | New | Used in |
|-----|-----|---------|
| `SUPABASE_ANON_KEY` | `SUPABASE_PUBLISHABLE_KEY` | `apps/api` |
| `SUPABASE_SERVICE_ROLE_KEY` | `SUPABASE_SECRET_KEY` | `apps/api` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `apps/web` |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` | `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `apps/mobile` |

## Internal Code Renames

| Old identifier | New identifier | Locations |
|----------------|----------------|-----------|
| `supabaseAnonKey` (variable/param) | `supabasePublishableKey` | `hono.ts`, `nextjs.ts`, middleware options, client factories, `app.ts`, web/mobile `supabase.ts` |
| `supabaseServiceKey` (variable/param) | `supabaseSecretKey` | `hono.ts`, `app.ts` |
| `anonClient` (variable) | `publishableClient` | `hono.ts` middleware |
| `"test-anon-key"` (test fixture) | `"test-publishable-key"` | All test files |
| `"test-service-key"` (test fixture) | `"test-secret-key"` | All test files |

## Documentation Updates

- `CLAUDE.md` — env var table, middleware description, all "anon key" references
- `eng-constitution.md` — "anon-key client" → "publishable-key client"
- `.env.example` / `.env.local.example` files in all apps
- Existing design docs (`2026-02-21-supabase-integration-design.md`, `2026-02-21-supabase-integration-plan.md`)
- JSDoc comments in client/middleware source code
- `README.md` if it references these keys

## Affected Files

### Source code
- `packages/infrastructure/supabase/src/middleware/hono.ts`
- `packages/infrastructure/supabase/src/middleware/nextjs.ts`
- `packages/infrastructure/supabase/src/clients/browser.ts`
- `packages/infrastructure/supabase/src/clients/browser-ssr.ts`
- `packages/infrastructure/supabase/src/clients/server-ssr.ts`
- `apps/api/src/app.ts`
- `apps/web/lib/supabase.ts`
- `apps/web/middleware.ts`
- `apps/mobile/lib/supabase.ts`

### Tests
- `packages/infrastructure/supabase/src/middleware/__tests__/hono.test.ts`
- `packages/infrastructure/supabase/src/middleware/__tests__/nextjs.test.ts`
- `packages/infrastructure/supabase/src/clients/__tests__/browser.test.ts`
- `packages/infrastructure/supabase/src/clients/__tests__/browser-ssr.test.ts`
- `packages/infrastructure/supabase/src/clients/__tests__/server-ssr.test.ts`
- `apps/api/src/__tests__/index.test.ts`

### Config/env
- `apps/api/.env.example`
- `apps/web/.env.local.example`
- `apps/mobile/.env.example`

### Documentation
- `.claude/CLAUDE.md`
- `eng-constitution.md`
- `docs/plans/2026-02-21-supabase-integration-design.md`
- `docs/plans/2026-02-21-supabase-integration-plan.md`

## Out of Scope (YAGNI)

- Runtime validation of key format (`sb_publishable_...` prefix) — local Supabase uses different key format
- Backward compatibility / fallback logic — initial implementation, not a migration
- Changes to `apps/supabase/config.toml` — Supabase CLI's domain
- New key rotation utilities
