# Infrastructure & Hosting

Recommended deployment targets, CI/CD, env management, and managed services. Defaults assume small-to-mid scale; swap providers when scale or org policy requires it.

## Hosting

| Surface | Default | Notes |
|---|---|---|
| Web app (`apps/web`) | **Vercel** | Native Next.js support; Edge runtime + ISR + Image Optimization out of the box. |
| Landing page (`apps/landing`) | **Vercel** | Same project preferred or separate Vercel project for marketing-team autonomy. |
| API (`apps/api`) | **Vercel Functions** (Fluid Compute) or **Cloudflare Workers** | Hono runs on both. Choose Vercel when colocated with web for shared env + preview URLs; Workers for global edge + lower cold-start cost. |
| Mobile (`apps/mobile`) | **Expo EAS Build + Submit** | OTA updates via EAS Update; app store submission via EAS Submit. |
| Mobile web build | Same Vercel project as `web` (subpath) or its own | Optional — only if mobile web is a shipping surface. |

## Data layer

**Supabase** is the default backend-as-a-service for new projects. It bundles Postgres, auth, storage, realtime, and edge functions behind one provider — fewer integrations to wire and a single dashboard for ops.

| Need | Default | Alternative |
|---|---|---|
| Relational DB | **Supabase Postgres** | Neon, RDS |
| Auth | **Supabase Auth** | Auth0, custom |
| Object storage | **Supabase Storage** | S3, R2, Vercel Blob |
| Realtime | **Supabase Realtime** | Pusher, Ably |
| Edge functions | **Supabase Edge Functions** (Deno) | Vercel Functions, Cloudflare Workers |
| Key-value / cache | **Upstash Redis** (via Vercel Marketplace) | Vercel KV |
| Edge config / feature flags | **Vercel Edge Config** | LaunchDarkly, GrowthBook |
| Runtime cache | **Vercel Runtime Cache API** | App-level memoization |

**Provision:**
- Create a Supabase project per environment (`dev`, `staging`, `prod`) or use Supabase branching for preview environments tied to PRs.
- Pull connection strings + anon/service keys into Vercel env vars (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DATABASE_URL`).
- Use `@supabase/supabase-js` on web + mobile clients; on `apps/api` use the service role key for server-only operations.
- Run schema migrations with the Supabase CLI (`supabase db push`) committed to the repo under `supabase/migrations/`.

## Auth

**Supabase Auth** handles sign-up, sign-in, OAuth, magic links, MFA, and row-level security policies tied to the same Postgres instance. Use it unless a constraint forces otherwise.

| Default | When to use |
|---|---|
| **Supabase Auth** | Default. Covers email/password, OAuth (Google, Apple, GitHub, etc.), magic link, OTP, MFA. RLS policies enforce access in Postgres. |
| **Auth0** | Enterprise SSO, strict compliance, existing IdP integration. |
| **Custom (Hono + JWT + Postgres)** | Only when no managed provider fits. |

**Integration:**
- Web (`apps/web`): `@supabase/ssr` for App Router cookie-based sessions.
- Mobile (`apps/mobile`): `@supabase/supabase-js` + `expo-secure-store` for session persistence.
- API (`apps/api`): validate JWTs via Supabase's JWKS endpoint or by using the service role for trusted server actions.
- Row-level security: enable on every table; write policies that scope rows to `auth.uid()`.

## Email / messaging

| Need | Default |
|---|---|
| Transactional email | **Resend** |
| Webhook delivery | **Inngest** or native Hono routes |
| Chat / bot platforms | **Vercel Chat SDK** (Slack/Discord/Teams/etc.) |

## Observability

| Need | Default |
|---|---|
| Error tracking | **Sentry** (web + RN + API) |
| Logs | Vercel runtime logs + Sentry breadcrumbs |
| Metrics / vitals | Vercel Web Analytics + Speed Insights |
| AI agent code review | **Vercel Agent** |

## CI/CD

GitHub Actions only. Single workflow per project — keep it small.

```
.github/workflows/ci.yml
```

Minimum jobs on every PR:

1. **Lint + format check** — `biome ci`
2. **Build** — `pnpm turbo build`
3. **Test changed packages** — `pnpm test:changed`

Notes:
- **Do not** run `pnpm typecheck` in CI by default. It's slow and redundant if `build` succeeds. Run locally before pushing, or add a separate optional check.
- Run on Node 22 LTS or the latest LTS at bootstrap time. Pin via `actions/setup-node` `node-version`.
- Pin `pnpm` to the `packageManager` field via `pnpm/action-setup`.
- Cache `~/.pnpm-store` and Turborepo remote cache (`TURBO_TOKEN` + `TURBO_TEAM`).

### Branch + PR flow

- Branch tool: **Graphite** (`gt create`, `gt modify`, `gt submit`).
- Trunk: `main`. Optional `staging` for non-critical merges (e.g. Dependabot).
- Dependabot weekly scan targeting `staging` (or `main` if no staging branch).

### Deployment pipeline

- Vercel auto-deploys every PR to a preview URL.
- Production deploy on merge to `main`.
- EAS Update channel mapping: `main` → `production`, feature branches → `preview`.
- Use Vercel rollback button or `vercel rollback` for fast revert; never force-push to `main`.

## Environment variables

- Source of truth: Vercel (web/api) + EAS Secrets (mobile).
- Local dev: `vercel env pull .env.local`.
- Never commit `.env*` files. `.gitignore` must cover `.env`, `.env.local`, `.env.*.local`.
- Per-environment values: `development`, `preview`, `production` on Vercel.
- For client-exposed values on web: `NEXT_PUBLIC_*`. On mobile: `EXPO_PUBLIC_*`.

## Domain + DNS

- Domains managed in Vercel where possible (auto SSL).
- Production: apex (`example.com`) + `www` redirect.
- Preview deploys get autogenerated `*.vercel.app` subdomains.

## Security baselines

- HTTPS everywhere (Vercel enforces).
- Strict CSP on web (`next.config.ts` headers).
- Vercel Firewall: enable managed rulesets + bot management.
- API: validate all inputs through Zod (oRPC contracts).
- Secrets: never log them. Mask in Sentry.

## When to deviate

The defaults assume: a small team, web + mobile + API, ship-fast bias. Swap providers when:

- **Cost** dominates at scale → consider self-hosted or hyperscaler primitives (S3, RDS, ECS).
- **Compliance** requires a specific region/provider (HIPAA, FedRAMP).
- **Existing org infra** already owns one of these layers — reuse it.

Document any deviation in the project's own `README.md` so future contributors know why the spec was bent.
