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
| Edge config (static) | **Vercel Edge Config** | — |
| Feature flags / experiments | **Vercel Flags SDK** (`flags` + `@flags-sdk/*` adapters) | LaunchDarkly, GrowthBook, Statsig |
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

## Feature flags

**Vercel Flags SDK** is the default for runtime feature gating, A/B tests, and gradual rollouts across web + mobile + API. It abstracts the provider behind a typed `flag(...)` definition so the backing store (Edge Config, Statsig, LaunchDarkly, GrowthBook) can swap without touching call sites.

| Surface | Adapter |
|---|---|
| `apps/web`, `apps/landing` | `flags/next` for server + client components, route handlers, Middleware/Proxy |
| `apps/api` (Hono) | `flags` core + `@flags-sdk/edge-config` (or chosen provider adapter) |
| `apps/mobile` | `flags` core with a Resend-style server endpoint that returns evaluated flag values; cache in React Query |

**Integration:**
- Default backing store: **Vercel Edge Config** via `@flags-sdk/edge-config`. Swap to `@flags-sdk/statsig`, `@flags-sdk/launchdarkly`, or `@flags-sdk/growthbook` when experimentation or targeting needs outgrow Edge Config.
- Define every flag in a single `packages/infrastructure/flags/` module: `export const myFlag = flag({ key, defaultValue, decide, adapter })`. Co-locate Zod schemas for flag values.
- Identify users with a stable `identify()` function that reads the Supabase session — never trust client-passed identifiers for gating server-side behavior.
- Server-side reads only inside Server Components, Route Handlers, or oRPC procedures. Client reads through `useFlag()` are fine but treat results as cosmetic — enforce gates on the server.
- Precompute flags for Middleware/Proxy with `precompute([...])` to keep rewrites + redirects cacheable.
- Env: `FLAGS_SECRET` (required, used to sign flag-overrides cookies + `.well-known/vercel/flags` endpoint), plus the chosen adapter's keys (`EDGE_CONFIG`, `STATSIG_SERVER_KEY`, etc.).
- Expose the discovery endpoint (`/.well-known/vercel/flags`) on `apps/web` so the Vercel Toolbar can surface flags in preview deployments.

## Email / messaging

| Need | Default |
|---|---|
| Transactional email | **Resend** |
| Webhook delivery | **Inngest** or native Hono routes |
| Chat / bot platforms | **Vercel Chat SDK** (Slack/Discord/Teams/etc.) |

**Resend integration:**
- SDK: `resend` package consumed from `apps/api` (server-only — never expose `RESEND_API_KEY` to client bundles).
- Templates: author with `@react-email/components`, render server-side, send via Resend.
- Env: `RESEND_API_KEY` on Vercel; per-environment sending domains verified in the Resend dashboard.

## Billing

| Need | Default |
|---|---|
| Payments + subscriptions | **Stripe** |
| Hosted checkout | **Stripe Checkout** |
| Self-service subscription management | **Stripe Customer Portal** |
| Webhook handling | Hono route on `apps/api` validating `Stripe-Signature` |

**Stripe integration:**
- SDK: `stripe` (server) consumed only from `apps/api`. Client surfaces use `@stripe/stripe-js` + `@stripe/react-stripe-js` when embedding Elements; otherwise redirect to Stripe-hosted Checkout / Portal.
- Env: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` (server); `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` / `EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY` (client).
- Webhook route: verify signature with raw request body — do not parse JSON first. Idempotently upsert subscription / invoice state into Supabase.
- Test mode keys for `development` + `preview` Vercel environments; live keys only on `production`.
- Place billing logic in `packages/features/billing/` per [architecture.md](architecture.md). oRPC procedures wrap Stripe SDK calls so web + mobile share contracts.

## Observability

| Need | Default |
|---|---|
| Error tracking | **Axiom** (web + RN + API) |
| Structured logs | **Axiom** (Vercel + Hono + RN SDKs) |
| Metrics / vitals | **Axiom** dashboards on ingested events |
| AI agent code review | **Vercel Agent** |

**Axiom integration:**
- Vercel projects: install the **Axiom Vercel integration** to ship runtime logs + Web Vitals to a dataset automatically.
- API (`apps/api`): use `@axiomhq/js` or `@axiomhq/winston` to emit structured logs and capture exceptions; tag every event with `service`, `env`, `release`.
- Web (`apps/web`, `apps/landing`): `@axiomhq/nextjs` for client + server logging and unhandled-error capture.
- Mobile (`apps/mobile`): `@axiomhq/react-native` or hand-rolled ingest client; flush on background.
- Env: `AXIOM_TOKEN`, `AXIOM_DATASET`, `AXIOM_ORG_ID` on Vercel + EAS Secrets.
- Alerts + dashboards configured in Axiom (latency, error rate, web vitals percentiles). One dataset per environment.

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
- Secrets: never log them. Redact at the logger before shipping to Axiom (deny-list `STRIPE_SECRET_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `AXIOM_TOKEN`, auth headers).
- Stripe webhook endpoints: reject any request whose `Stripe-Signature` fails verification — do not log raw payloads on failure.

## When to deviate

The defaults assume: a small team, web + mobile + API, ship-fast bias. Swap providers when:

- **Cost** dominates at scale → consider self-hosted or hyperscaler primitives (S3, RDS, ECS).
- **Compliance** requires a specific region/provider (HIPAA, FedRAMP).
- **Existing org infra** already owns one of these layers — reuse it.

Document any deviation in the project's own `README.md` so future contributors know why the spec was bent.
