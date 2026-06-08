# Infrastructure & Production Readiness

Guidelines for deployment targets, environment management, migrations, CI/CD, and observability. Swap and configure providers based on project scale and requirements.

---

## Hosting & Cloud Deployment

Choose hosting targets based on the selected application architectures (serverless, containerized, or traditional VPS):

- **Web Frontends**: Deploy to managed hosting providers (Vercel, Netlify, Cloudflare Pages) that support edge rendering, route-based caching, and automatic preview deployments out of the box.
- **APIs & Backend Services**: 
  - Deploy to serverless edge platforms (Vercel Functions, Cloudflare Workers, AWS Lambda) for auto-scaling and zero-maintenance global distribution.
  - Deploy to container platforms (Fly.io, AWS ECS, GCP Cloud Run, Render) for long-running processes, websocket connections, and heavy computing needs.
- **Mobile Apps**: Compile and submit through cloud build pipelines (e.g. Expo EAS for React Native, App Center) to handle certificates, profiles, and App Store/Play Store submissions.

---

## Data Layer & Migrations

Regardless of the chosen database provider (SQL or NoSQL), enforce the following production-readiness practices:

- **Stack-agnostic database migrations**: All schema mutations must be written as discrete, version-controlled migration files committed to the repository (e.g. under `supabase/migrations/`, `prisma/migrations/`, `db/migrate/`).
- **Migration Execution**: Never run migrations from the local developer machine directly to production. CI/CD pipelines or deployment hooks must run migrations automatically during deployment.
- **Connection Management**: Serverless API execution environments have connection limits. For relational databases, ensure connection pooling is configured (e.g. Supabase connection pooler, PgBouncer, AWS RDS Proxy) to prevent database exhaustion.

---

## Environment Variables

- **Source of Truth**: Managed service dashboards (e.g., Vercel Project Settings, Fly.io Secrets, Github Secrets, AWS SSM Parameter Store).
- **Local Development**: Use local `.env` files for local dev. **Never commit raw secrets to the repository.** Include a `.env.example` template in the root of the project with empty values.
- **Ignored Files**: The root `.gitignore` must strictly cover `.env`, `.env.local`, `.env.*.local` files.
- **Runtime Validation**: Use Zod, clean schemas, or framework validations to check for the presence of required environment variables at application startup, failing fast with descriptive errors if any are missing.

---

## Database Client Wrapper

Encapsulate database access within a shared `@infrastructure/db-client` package:

- **Vendor Abstraction**: Wrap database clients (e.g. Prisma, Drizzle, Supabase JS) in clean interface modules to keep the core application domain independent of the database vendor.
- **Connection Isolation**: Limit direct connection instantiation to `@infrastructure/db-client`, exposing only high-level query interfaces or a single pooled client.

---

## Authentication & Identity

Encapsulate authentication and session management within a shared `@infrastructure/auth` package:

- **SDK Isolation**: Wrap third-party auth SDKs (e.g. Supabase Auth, Clerk, Auth0) inside a unified interface so that downstream features do not directly import vendor libraries.
- **Server-Side Verification**: Provide trusted helper methods for token verification and session retrieval that run in server-only contexts (e.g. middleware, API context handlers).

---

## Observability & Logging

Encapsulate logging, metrics, and error tracking within a shared `@infrastructure/observability` package:

- **Structured Logging**: Emit logs as structured JSON (containing keys like `timestamp`, `level`, `message`, `service`, `env`) so they are easily queryable in logging platforms.
- **Error Capturing**: Catch unhandled exceptions and ship them to an error tracking service (e.g. Sentry, Axiom, Datadog).
- **Secrets Redaction**: Redact sensitive headers, API keys, and authorization tokens at the logger level before transmitting events to telemetry backends.

---

## CI/CD Pipelines

Implement a single root CI pipeline (typically using GitHub Actions) to run checks on every pull request targeting integration branches.

- **PR Validation Checks**:
  1. **Linting & Formatting**: Verify code style constraints (e.g. `biome ci` or `eslint`).
  2. **Type Checking**: Verify type safety across the monorepo.
  3. **Build Pipeline**: Compile all applications in the workspace (e.g. `pnpm turbo build`).
  4. **Testing**: Run unit and integration tests (e.g. `pnpm test`).
- **Deployment Pipelines**: Set up automated deployments. Merges to the primary branch (`main`) trigger production builds and deployments; PR branches trigger preview/staging deployments automatically.
