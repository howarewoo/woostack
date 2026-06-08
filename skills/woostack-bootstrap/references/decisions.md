# Decisions & Questionnaire Protocol

Every technology stack choice must be aligned with the user's specific project goals and constraints. Walk the user through this protocol **before** any files are created or scaffolded.

## Dynamic Stack Selection Protocol

Run this gate **before** any scaffolding (it is step 0 of [bootstrap.md](bootstrap.md)).

1. **Submit the Goal**: The user initiates bootstrap with a goal, e.g. `/woostack-bootstrap <goal>`.
2. **Gather Requirements**: Ask the user 1-2 targeted questions to clarify:
   - **Scale & Traffic Patterns**: Expected user base, read/write ratios, real-time requirements.
   - **Hosting & Infrastructure restrictions**: Preferred cloud provider (AWS, GCP, Azure, Vercel, Cloudflare, Fly.io, self-hosted/VPS).
   - **Database & Data Structure**: Relational vs. Document vs. Key-Value, blob storage requirements.
   - **Auth & Compliance**: Need for SSO, social logins, RLS/database policies, GDPR/HIPAA compliance.
   - **External Integrations**: Third-party APIs (e.g. Stripe for billing, Resend for email, flags).
   - **Budget & Team constraints**: Familiarity with languages/tools, hosting budget limits.
3. **Research & Lookup**: 
   - Based on the requirements, look up the current industry-standard frameworks, libraries, databases, and services.
   - Ground the research in **latest stable versions** using registry commands (`npm view <pkg> version` or equivalent tools for other platforms) or web searches.
4. **Present 2-3 Stack Options**: Present the stack options clearly in a comparison table. For each option, specify:
   - **Detailed Tech Stack**: Language, framework, database, auth, hosting, observability.
   - **Pros & Cons**: Trade-offs around developer speed, complexity, scaling, cold starts, and lock-in.
   - **Production Readiness**: Security baselines, disaster recovery, logging/monitoring backing.
   - **Cost Estimation**: Free-tier availability and estimated operational costs.
5. **Get Explicit Approval**: The user must explicitly select or customize one of the proposed stack options. **Do not scaffold any decision the user has not approved.**
6. **Record the Stack**: Write the selected stack, resolved versions, and architectural decisions into the project's root `README.md` at hand-off.

---

## Requirements gathering questionnaire

Below is a template of the requirements questionnaire the agent should present to the user:

```markdown
To bootstrap the best stack for your project, please answer the following questions (defaults will be recommended based on your goal):

1. **Scale & Performance**: What are your traffic expectations? Does the project need real-time sync, edge compute, or heavy background workers?
2. **Hosting/Cloud Preferences**: Do you have a preferred hosting target (e.g., Vercel, AWS, Cloudflare Workers, Fly.io, or a simple VPS)?
3. **Data & Storage**: What kind of database is preferred (SQL/Postgres, NoSQL/Mongo, key-value)? Do you need object storage for files?
4. **Auth & Security**: What type of authentication is required (e.g., social login, passwordless, email/password)? Any compliance constraints (HIPAA, GDPR)?
5. **Additional Capabilities**: Do you need billing (Stripe), feature flags, email delivery, or structured observability?
```

## Option Presentation Format

When presenting the researched options, structure them like this to keep evaluations scannable:

### Option 1: Edge-Native / Serverless (e.g., Next.js + Cloudflare Workers + Supabase)
- **Use Case**: Best for global low latency, fast scaling, and low initial costs.
- **Components**: Next.js (Frontend), Hono + Cloudflare Workers (API), Supabase (Postgres & Auth), Resend (Email).
- **Pros**: Zero server maintenance, instant global distribution, low cold starts.
- **Cons**: Vendor lock-in with Supabase/Cloudflare; database connection pooling limits.
- **Production Readiness**: High; auto-scaling, managed SSL, and built-in edge caching.

### Option 2: Containerized / Traditional VPS (e.g., Express/FastAPI + PostgreSQL + Docker)
- **Use Case**: Best for complete control, predictability at scale, and avoiding serverless limits.
- **Components**: React/Vite (Frontend), FastAPI (API), PostgreSQL (managed or Docker), Keycloak/Auth0 (Auth), Fly.io/AWS ECS (Hosting).
- **Pros**: No serverless execution timeouts, complete language flexibility, portable container setup.
- **Cons**: Requires setting up CI/CD pipelines, managing DB backups, higher maintenance overhead.
- **Production Readiness**: High, provided health checks, migrations, and standard Docker configs are wired.
