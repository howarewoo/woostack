# Decisions & Questionnaire Protocol

Every technology choice must follow the user's project goals and constraints. Run this protocol
before creating or scaffolding files; woostack supplies no built-in stack defaults.

## Dynamic stack selection protocol

1. **Submit the goal:** The user initiates bootstrap with a goal, for example
   `/woostack-bootstrap <goal>`.
2. **Gather requirements:** Ask one or two targeted rounds covering the relevant scale, traffic,
   hosting, data, identity, compliance, integration, budget, and team constraints.
3. **Research current named options:** Find the current production-ready languages, frameworks,
   libraries, databases, services, and deployment choices that fit those requirements. Resolve
   versions live from authoritative registries (`npm view <pkg> version` or the selected ecosystem's
   equivalent) and use current authoritative sources for operational claims.
4. **Present two or three cohesive options:** Name the technologies in each option and compare
   developer experience, complexity, performance, scaling, portability or lock-in, production
   readiness, and estimated operating cost.
5. **Get explicit approval:** The user must select or customize one complete option. Do not scaffold
   a technology or architectural decision the user has not approved.
6. **Record the stack:** At handoff, write the selected technologies, live-resolved versions, and
   material architectural decisions into the project's root `README.md`.

## Requirements questionnaire

Ask only questions that discriminate among viable options. A concise prompt may cover:

1. Expected traffic, latency, real-time, edge, offline, or background-work requirements.
2. Hosting restrictions, portability needs, regions, and operational ownership.
3. Data shape, consistency, search, retention, backup, and object-storage needs.
4. Authentication, authorization, privacy, and compliance requirements.
5. External integrations, observability, budget, and team familiarity.

Do not suggest a default before the research. If the user has already selected part of the stack,
treat it as a constraint and research compatible choices for the undecided parts.

## Option presentation format

Use a scannable comparison grounded in the live research:

```markdown
### Option <n>: <descriptive architecture>
- **Components:** <named language, frameworks, data, identity, hosting, and observability choices>
- **Fit:** <requirements this option satisfies>
- **Trade-offs:** <complexity, performance, scaling, portability or lock-in>
- **Production readiness:** <security, recovery, deployment, and monitoring implications>
- **Estimated cost:** <current assumptions and material thresholds>
- **Versions and sources:** <live registry results and authoritative references>
```
