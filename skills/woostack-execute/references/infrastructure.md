# Deployment and operations

Load this reference when a change affects deployment, data migrations, environment configuration
or secrets, external client lifecycle, or observability. These are outcomes for the project's
selected stack and delivery model, not vendor or hosting defaults; existing repository and host
policy stay authoritative, and the guidance applies to new or materially changed flows rather
than untouched code. Repository checks and CI remain owned by the Execute entrypoint and the
project's own configuration.

## Deployment

- Match the deployment model to the workload's runtime duration, scaling, latency, state,
  networking, and regional requirements, and state the assumptions it rests on.
- Make certificates, release credentials, rollback, and store or platform submission
  responsibility explicit for every deployable surface.
- Automate repeatable production and preview/staging deployments where the delivery model
  supports them; a new project has no pipeline until it defines one.
- Document the exact release commands that exist. A command that was not observed running is not
  a verified step.

## Schema and data migrations

- Keep every schema mutation discrete, ordered, version-controlled, and reproducible with the
  project's data tooling.
- Do not run production migrations from a developer machine; use controlled deployment automation
  with observable failure and recovery behavior.
- Configure connection limits, pooling, retries, backups, restoration, and destructive-change
  safeguards to match the selected database and runtime, and define a destructive change's
  rollback or recovery path before applying it.

## Environment and secrets

- The production secret store or managed runtime configuration is the production source of truth.
- Keep local development secrets out of source control and provide a non-secret inventory of
  required configuration names.
- Ensure ignore rules cover the local secret files the selected stack uses.
- Validate required configuration at startup and fail with descriptive, non-secret errors.

## External clients and identity

- Add a project-owned interface around a vendor client only when it provides real portability,
  testability, isolation, or reuse; do not add pass-through abstractions.
- Centralize connection or client instantiation when the selected service requires shared
  lifecycle, pooling, or rate-limit control, and close clients the project owns.
- Verify identity tokens and sessions only in trusted server-side contexts, and keep authorization
  decisions explicit at protected boundaries.

## Observability

- Emit structured, queryable events with consistent time, severity, message, service, and
  environment fields.
- Capture unhandled failures through the project's monitoring path.
- Redact credentials, authorization material, personal data, and other secrets before telemetry
  leaves the process.