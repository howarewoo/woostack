# Decisions

Every choice a bootstrap makes. Walk the user through **all** of these before scaffolding — including the ones that have a default. The user confirms or overrides each; nothing gets scaffolded that the user has not signed off on.

## Confirmation protocol

Run this gate **before** any scaffolding (it is step 0 of [bootstrap.md](bootstrap.md)).

0. **Start from the goal.** The skill is invoked as `/woo-stack-bootstrap <goal>`. Read that goal first and infer a *recommended* shape — name, surfaces, candidate features, likely capabilities — then present each decision below pre-filled with that recommendation, not a blank default. Example: "mobile app for cataloging recipes" → recommend `mobile` (+ `api` for sync), a `recipes` feature, Supabase Postgres + Storage (images) + Auth (accounts), and *no* billing. The user still confirms or overrides every item; the goal just makes the recommendations specific instead of generic.
1. **Surface only the relevant decisions.** Filter by the recommended/confirmed surfaces — don't ask mobile questions if there's no `mobile` surface, don't ask the API-host question if there's no `api`.
2. **For every decision below, state the default and the alternatives, then get an explicit answer.** "Confirm everything" means the user actively accepts each default — silence is not consent. Group related decisions so the user answers in batches, not one popup at a time.
3. **Capabilities are opt-in.** For billing, transactional email, webhooks, chat, observability, and realtime, first ask whether the project needs the capability at all. If no, skip its package and env entirely. If yes, confirm the provider. (`flags` is the exception — it is **not** opt-in: a standing package scaffolded empty in every project regardless of answer; see section 5 below.)
4. **Never invent an unconfirmed value.** If a decision has neither a user answer nor a documented default, stop and ask. Do not guess.
5. **Record the outcome.** Write the confirmed choices — and any deviation from a default — into the project's own README at hand-off (bootstrap step 11), so the next contributor sees what was decided and why.

Do not proceed to scaffolding until every relevant decision below is confirmed.

## 1. Project basics — derive a recommendation from the goal, then confirm

Infer each of these from the `/woo-stack-bootstrap` goal and propose it; the user confirms or corrects.

| Decision | Notes |
|---|---|
| Project name | Suggest one from the goal (e.g. "cataloging recipes" → `recipe-box`); confirm. Used for repo, root `package.json`, default app names. |
| Surfaces | Infer from the goal ("mobile app" → `mobile`; "dashboard + marketing site" → `web` + `landing`). Any subset of `web`, `landing`, `mobile`, `api`. Drives every later filter. |
| Initial features | Propose features the goal implies (e.g. `recipes`, `users`). May be empty. |
| Repo host | Default **GitHub**. Confirm or override. |
| Package manager | Default **pnpm** (catalog protocol assumes it). Override only with reason. |

## 2. Core frameworks — defaults from [frameworks.md](frameworks.md)

Confirm per surface that's in scope.

| Layer | Default | Applies when |
|---|---|---|
| Web / Landing | Next.js (App Router) + React Compiler + shadcn/ui | `web` / `landing` |
| Mobile | Expo + React Native + react-native-reusables + UniWind | `mobile` |
| API | Hono + oRPC | `api` |
| Styling | Tailwind CSS (CSS-first) + shared theme | any UI surface |
| Build | Turborepo + pnpm catalog | always |
| Lint / format | Biome | always |
| Testing | Vitest, Jest (RN), Playwright | always |

Versions are resolved live at bootstrap — see [frameworks.md](frameworks.md). The *choice* of framework is confirmed here; the *version* is never invented.

## 3. Hosting — defaults from [infrastructure.md#hosting](infrastructure.md#hosting)

| Decision | Default | Alternatives | Applies when |
|---|---|---|---|
| Web / landing host | Vercel | — | `web` / `landing` |
| **API host** | *no single default — a real fork* | Vercel Functions (Fluid Compute) **or** Cloudflare Workers | `api` |
| Mobile build / submit | Expo EAS Build + Submit | — | `mobile` |
| Domains / DNS | Vercel-managed (auto SSL) | external registrar | any web surface |

The API-host question must always be asked when `api` is in scope — colocate on Vercel for shared env + preview URLs, or Cloudflare Workers for global edge + lower cold-start cost.

## 4. Data & backend — defaults from [infrastructure.md#data-layer](infrastructure.md#data-layer)

| Decision | Default | Alternatives |
|---|---|---|
| Relational DB | Supabase Postgres | Neon, RDS |
| Auth | Supabase Auth | Auth0, custom (Hono + JWT) |
| Object storage | Supabase Storage | S3, R2, Vercel Blob |
| Key-value / cache | Upstash Redis (Vercel Marketplace) | Vercel KV |
| Edge functions | Supabase Edge Functions (Deno) | Vercel Functions, Cloudflare Workers |

The DB / auth / storage rows usually move together — picking Supabase answers all three. Only ask the **edge-functions** row if the project actually needs server-side compute beyond `apps/api`; otherwise skip it. Tie the choice to the data-layer provider you confirmed above.

## 5. Capabilities — opt-in; ask "does this project need it?" first

Every row here is opt-in **except `flags`** (see the note below the table). For the opt-in rows: if the user declines, skip the capability entirely.

| Capability | Default provider | Alternatives | Package |
|---|---|---|---|
| Realtime | Supabase Realtime | Pusher, Ably | — |
| Feature flags / experiments | Vercel Flags SDK + Edge Config backing store | Statsig, LaunchDarkly, GrowthBook adapters | `flags` — **not opt-in**: standing package, scaffolded empty even if no flags yet (see [bootstrap.md](bootstrap.md)); only the *backing store* is a choice |
| Transactional email | Resend | — | consumed from `apps/api` |
| Webhook delivery | Inngest or native Hono routes | — | — |
| Chat / bot platforms | Vercel Chat SDK | — | — |
| Billing / subscriptions | Stripe (Checkout + Customer Portal) | — | `packages/features/billing/` |
| Observability | Axiom (errors, logs, vitals) | — | per-surface Axiom SDK |
| AI code review | Vercel Agent | — | — |

If a capability is declined, do not scaffold its package, SDK, or env vars. (Exception: `flags` is a standing package — scaffold it empty regardless, but only wire a backing store if flags are wanted.)

## 6. Workflow & CI — defaults from [infrastructure.md#cicd](infrastructure.md#cicd) and [development.md](development.md)

| Decision | Default | Notes |
|---|---|---|
| Branch tool | Graphite (`gt`) | — |
| Trunk / integration | `main` trunk, optional `staging` | See branching model in [development.md](development.md). |
| Node version | Latest LTS at bootstrap (resolve live) | Pin in CI via `actions/setup-node`. |
| CI jobs | `biome ci`, `pnpm turbo build`, `pnpm test:changed` | No `typecheck` job — local-only. |

## When the user defers

If the user says "use the defaults" or "you decide," that **is** a confirmation — proceed with the documented defaults for the relevant surfaces, but still resolve the genuine forks that have no default (API host) and the opt-in capabilities (don't silently add Stripe/Resend/Axiom to a project that didn't ask for them). State the full set of defaults you're applying so the user can object before scaffolding starts.
