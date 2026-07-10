# Provider discovery

`woostack-respond` discovers read-only evidence sources without shipping provider clients or treating installed software as authority to query production.

## Singular resolver

Use exactly one ordered resolver:

```text
explicit request → config → repository evidence → host capability
```

In operational terms, the precedence is:

1. An explicit provider and target in the current request.
2. A non-`auto` `respond.provider` value in `.woostack/config.json`.
3. Corroborating repository evidence.
4. A matching host capability, selected in the capability order below.

A higher-precedence provider choice is never silently replaced by a lower-precedence signal. A provider name alone does not prove a target, environment, or authorization.

## Repository evidence

Inspect only evidence already available in the repository or host context:

- dependency manifests and lockfiles;
- SDK imports and initialization calls;
- provider configuration filenames;
- OpenTelemetry exporter configuration;
- deployment configuration;
- environment-variable **names only**, never their values.

Known signatures accelerate discovery; they are not a whitelist. Examples include Sentry SDK initialization or `SENTRY_DSN`, Datadog libraries or `DD_SERVICE`, Axiom exporters or `AXIOM_DATASET`, Honeycomb/OpenTelemetry exporters or `HONEYCOMB_SERVICE_NAME`, generic OTLP exporter configuration, and deployment metadata from a hosting integration. Other providers and signatures remain valid.

Repository evidence identifies a candidate provider and role. It does not prove that a host integration is authenticated, that its account maps to the repository, or that it may be queried.

## Host capabilities

For a provider already selected or corroborated, choose the first usable capability in this order:

1. specialized provider MCP or tool;
2. installed provider skill;
3. authenticated official CLI;
4. user-supplied exported artifact.

The resolver never auto-selects an uncorroborated host capability. An installed tool, skill, authenticated CLI, or available artifact is not queried merely because it exists. If repository evidence is absent and exactly one provider capability is available, offer that provider for explicit confirmation and wait. If zero capabilities are usable, record the role as blocked. If multiple uncorroborated capabilities are available, stop and ask rather than offering a guess.

Never automate a provider web dashboard as a fallback.

## Roles and ambiguity

A run may select complementary providers for distinct source roles such as error tracking, logs, traces, metrics, and deployment metadata. Each selected source must be proven to refer to the same target service, environment, and exact UTC window. Similar names, a shared organization, or temporal overlap alone are insufficient proof.

If two candidates claim the same role and precedence does not resolve them, stop and ask the user which provider is authoritative. Do not merge or query ambiguous same-role sources. A deployment provider may complement Sentry error tracking, Datadog logs, Axiom logs, Honeycomb traces, or generic OpenTelemetry data only after the same-target/environment/window proof succeeds.

## Authentication and target gates

Before querying each selected role, verify all of the following:

- the chosen capability is available and supports the required read operation;
- authentication is present according to that integration's own non-secret status mechanism;
- the account, organization, project, dataset, or service target is resolved;
- the requested environment exists or is unambiguously mapped;
- the source can apply the exact requested UTC window;
- the operation is read-only.

Missing authentication, an unresolved target, an environment mismatch, an unsupported window, or no available integration is **blocked**, never an empty result. Init or host guidance may describe provider-native authentication, but respond never requests, reads, prints, stores, or persists credentials. It also never mutates provider state, production systems, dashboards, alerts, sampling, or retention.

For an exported artifact, record its provenance and require the user or artifact metadata to establish provider, target, environment, and window. If those facts cannot be established, treat the affected role as blocked.
