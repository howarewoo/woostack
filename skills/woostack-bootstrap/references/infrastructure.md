# Infrastructure & Production Readiness

Select infrastructure from the approved workload, operational, compliance, budget, and team
requirements. This guidance defines outcomes, not vendors or deployment tools.

## Hosting and deployment

- Match the deployment model to runtime duration, scaling, latency, state, networking, and regional
  requirements.
- Automate repeatable production and preview/staging deployments where the approved delivery model
  supports them.
- Make certificates, release credentials, rollback, and store or platform submission responsibilities
  explicit for every deployable surface.

## Data and migrations

- Keep every schema mutation discrete, ordered, version-controlled, and reproducible with the
  approved data tooling.
- Do not run production migrations directly from a developer machine; use controlled deployment
  automation with observable failure and recovery behavior.
- Configure connection limits, pooling, retries, backups, restoration, and destructive-change
  safeguards to match the selected database and runtime.

## Environment and secrets

- Use the approved production secret store or managed runtime configuration as the production source
  of truth.
- Keep local development secrets out of source control and provide a non-secret inventory of required
  configuration names.
- Ensure ignore rules cover local secret files used by the selected stack.
- Validate required configuration at startup and fail with descriptive, non-secret errors.

## External clients and identity

- Add a project-owned interface around a vendor client only when it provides real portability,
  testability, isolation, or reuse; do not add pass-through abstractions.
- Centralize connection or client instantiation when the selected service requires shared lifecycle,
  pooling, or rate-limit control.
- Verify identity tokens and sessions only in trusted server-side contexts and keep authorization
  decisions explicit at protected boundaries.

## Observability

- Emit structured, queryable events with consistent time, severity, message, service, and environment
  fields.
- Capture unhandled failures through the approved monitoring path.
- Redact credentials, authorization material, personal data, and other secrets before telemetry
  leaves the process.

## CI/CD

- Use the repository's approved automation and commands.
- On pull requests, run every applicable formatting, static-analysis, type/compile, build, and test
  check already defined by the scaffold.
- Automate releases and migrations according to the repository's documented branch and deployment
  policy.
- Never report a nonexistent or unobserved command as passing.
