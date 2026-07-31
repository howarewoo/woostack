# Bootstrap Procedure

How an agent spins up a genuinely greenfield project. Stack research and version resolution remain
dynamic; the approved design must first become one verified managed Linear feature project before
the target directory or Git repository is touched.

## Route before bootstrap

Classify the request before requirements gathering, MCP preflight, project creation, or target
access:

- an existing-repository bug or root-cause request routes to `woostack-fix`;
- an existing-repository non-bug change that fits one reviewable PR, including a one-file change,
  routes to `woostack-change`;
- an existing-repository initiative requiring multiple PRs routes to `woostack-build`;
- only creation of a new codebase continues through bootstrap.

An empty remote repository may be the destination of a greenfield bootstrap. Existing code,
conventions, or source history make the work brownfield even when the requested edit sounds small.

## Inputs retained without target access

The invocation `/woostack-bootstrap <goal>` supplies a plain-language goal. Retain the requested
target path as an opaque string; do not stat, list, read, canonicalize, create, or write it and do
not invoke Git. Gather and keep these values in the run context:

1. project name;
2. required surfaces, such as web, API, mobile, desktop, or workers;
3. selected stack option and its live-resolved technologies;
4. initial features, which may be empty;
5. complete approved architecture and scope;
6. canonical future `https://github.com/<owner>/<repository>` URL;
7. intended initial integration/base branch; and
8. proposed non-secret Linear policy: workspace, team, all six `projectStatuses`, and all five
   `issueStates`.

The design and these values are in-memory workflow context, not a local spec, plan, README, Linear
document, or other development artifact.

## Authority and write barrier

The canonical
[Linear MCP development authority](../../woostack-init/references/artifact-backends.md) owns
managed identity, metadata, event, receipt, and trust semantics. Reuse
[`woostack-init`](../../woostack-init/SKILL.md)'s official-MCP capability and non-secret config
preflight. Do not invent a bootstrap-specific schema or transport.

Five conditions must all hold before any target access, target-directory creation, scaffolding CLI,
workspace write, or Git invocation:

1. the complete design has explicit user approval;
2. the official Linear MCP/config preflight has a complete independent receipt;
3. exact canonical repository attribution and initial base intent are retained;
4. the one managed `feature` project has a complete independent create/resume receipt; and
5. its initial `designApproved` event has a complete independent read-back.

Missing MCP, authentication, capability, policy mapping, identity, pagination completeness, or
read-back blocks before the target exists. Do not fall back to local records, a Linear document,
backend selection, repository credentials, environment tokens, direct HTTP, custom Linear
GraphQL, a local adapter, or another provider path.

## Steps

### 0. Classify and keep the design artifact-free

Route brownfield work as described above. For greenfield work, follow
[decisions.md](decisions.md): gather requirements, perform live industry and registry research,
compare 2–3 cohesive options, and present one complete proposed architecture and scope. Do not
persist the design or create any Linear development resource.

<HARD-GATE name="design-approval">
Wait for explicit approval of the complete presented design. Silence, an initial goal, a preferred
framework, partial agreement, or agent inference does not clear the gate. Before approval there is
no project, project update, issue, target directory, local development record, branch, commit, or
PR.
</HARD-GATE>

### 1. Establish repository/base intent and preflight official MCP

Only after approval, retain the exact canonical future repository URL and intended initial
integration/base branch. Construct the proposed `.woostack/config.json` `linear` policy in memory;
do not create the target or config file yet.

Through the host-exposed official Linear MCP, discover operations by capability rather than fixed
tool name. Resolve exactly one workspace/team, each configured project-status name to its required
native category, and every configured issue-state name to its required native category. Require
authenticated, paginated capabilities for project create/read/status mutation; project-update
create/list/read; issue create/read/update, project membership, state, comments,
assignment/delegation, and dependency/blocker relations; repository-scoped discovery; and
independent post-mutation reads.

Authentication remains exclusively in the host MCP/OAuth secret store. Independently read the
resolved policy and capability observations into one normalized non-secret preflight receipt. A
missing, read-only, partial, ambiguous, unauthenticated, foreign, stale, or conflicting result is a
hard stop with zero target filesystem and Git access.

### 2. Derive restart-safe identity, then create or resume one feature project

Derive an exact approved-design identity before choosing a resource `clientId` or mutating Linear:

1. Build one approved payload with exactly the keys `goal` and `scope`. `scope` contains the
   approved surfaces, initial features, constraints, exclusions, and architecture decisions.
   Normalize every string to Unicode NFC and LF line endings, remove trailing spaces/tabs per line,
   and trim outer blank lines. Serialize the payload with RFC 8785 JSON Canonicalization Scheme;
   arrays preserve the explicitly approved order.
2. Compute `approvedDesignKey` as lowercase
   `sha256:<hex>` over the UTF-8 bytes of
   `woostack-bootstrap-design-v1\n<canonical-repository>\n<canonical-payload>`.
3. Derive the feature resource `clientId` as UUIDv5 in the standard URL namespace
   `6ba7b811-9dad-11d1-80b4-00c04fd430c8`, using
   `urn:woostack:bootstrap:design:v1:<approvedDesignKey>` as the name. That deterministic UUID is
   the approved-design key's representation in the canonical managed resource envelope; do not add
   a bootstrap-only metadata field.

This computation uses only the approved run context. It writes no local receipt. A fresh invocation
with no retained state recomputes the same key and UUID from the same canonical repository and
normalized approved goal/scope.

Before create, paginate the complete repository-owned `feature` project set in the configured
workspace/team. Inspect each managed envelope and search for the deterministic client UUID plus
canonical repository, exact `woostack` label, role `feature`, and configured workspace/team. Also
treat a malformed or partial managed block containing the exact deterministic UUID as a candidate
that cannot be ignored.

- Exactly one complete valid candidate resumes after a fresh direct read verifies its approved
  goal/scope and identity.
- Zero candidates after proven-complete pagination permits one create containing the deterministic
  UUID in its managed overview, approved goal/scope, repository attribution, configured
  workspace/team, and native `backlog` status.
- Multiple candidates, a partial candidate, foreign ownership, mismatched approved content, or
  conflicting identity blocks before mutation. A title, slug, timestamp, local target, or prior
  filesystem receipt never selects a project.

Independently read back the project after create/resume. Verify the deterministic client UUID,
native project ID and canonical Linear URL, repository, label, role, workspace/team, readable
approved goal/scope, managed schema, and configured `backlog` category. A mutation response is not a
receipt. After an unknown outcome, recompute or retain the same approved-design key/client UUID,
repeat complete discovery, and never allocate or create a replacement.

### 3. Reconcile, append if absent, and verify the approved design

Derive the stable `designApproved` event UUID as UUIDv5 in the same standard URL namespace, using
`urn:woostack:bootstrap:event:v1:<feature-clientId>:designApproved` as the name. It is stable across
an interrupted mutation and a fresh invocation that retained no in-memory event ID.

Before any append, paginate the complete project-update set and validate all managed phase events
needed to prove one chain. Search both parsed envelopes and malformed managed blocks for the stable
event UUID:

- Exactly one valid stable event identity, with one valid current unsuperseded revision, is read
  back directly and reused without append. Its readable body must match the normalized approved
  design/key, approval evidence, canonical repository, and exact initial base intent. The full
  phase chain must be unique and rooted in that event; a valid later descendant head may be
  resumed only when that root still matches all four fields.
- Zero matching events permits append only when pagination is provably complete and no other
  `designApproved` event, phase root, or conflicting current head exists.
- Multiple matches, duplicate revisions, multiple current heads, a malformed/partial candidate,
  conflicting approved content, project identity, or initial base intent, an illegal
  predecessor/supersession chain, or incomplete pagination blocks before append and target access.

When proven absent, append one `projectEvent` update whose readable body contains the complete
approved architecture and scope, approved-design key, explicit approval evidence, canonical
repository attribution, and initial base intent. Its managed envelope uses:

- `event: "designApproved"`;
- `revision: 1`;
- the verified native `projectId`;
- `predecessorId: null`;
- `relatedIds: []`; and
- `supersedesId: null`.

After append, directly read the exact native update and independently paginate the full update set
again. Verify the event UUID, envelope/schema, project identity, canonical repository,
workspace/team, readable design/key and approval evidence, exact initial base intent, native
`backlog` category, one current event revision, and exactly one valid lifecycle chain. A changed,
missing, or conflicting base intent is a failed read-back and blocks. Retry an unknown append only
by the same deterministic event UUID after complete discovery; never append a same-phase duplicate.

### 4. Retain authority receipts and collision-check before local writes

Retain one in-memory context containing:
- approved-design key and normalization version;
- feature resource client UUID;
- native project ID and canonical Linear project URL;
- canonical repository URL and intended initial base branch;
- verified workspace/team native IDs and policy mappings;
- native `designApproved` update ID and stable event UUID; and
- the latest independent project and event receipts.

The first target-filesystem action after these receipts is a read-only collision check; do not
invoke Git as part of it. Resolve/lstat the requested path and, only when it is a real directory,
list it completely and inspect for a `.git` file or directory:

- an absent target passes and may be created afterward;
- an existing directory passes only when the complete listing proves it empty and non-Git;
- a populated directory, existing Git checkout/worktree, file, symlink, device, permission error,
  partial listing, path race, or any unreadable/ambiguous result blocks before mkdir, write,
  scaffold, or Git.

On a collision stop, preserve and report the approved-design key, project/event UUIDs, native IDs,
canonical URLs, and verified receipts; do not abandon, replace, or mutate the remote project.
After a passing collision receipt, pass the exact retained context into every scaffold step. A
callee independently refreshes mutable remote state but must not select a different project,
rediscover by title, or serialize the context as a local development record.

### 5. Read the implementation references and resolve exact versions

Load:

- [architecture.md](architecture.md)
- [frameworks.md](frameworks.md)
- [infrastructure.md](infrastructure.md)
- [patterns.md](patterns.md)
- [development.md](development.md)

For every dependency in the approved stack, query the current registry live (for example,
`npm view <pkg> version` or the equivalent for another runtime). Write the exact resolved versions
into the shared catalog/workspace configuration only after the authority receipts and target
collision receipt both pass.

### 6. Create the repository skeleton

Create a monorepo layout matching [architecture.md](architecture.md), omitting surfaces not
requested:

```text
<project>/
├── apps/                     # only requested surfaces
├── packages/
│   ├── features/             # one directory per requested feature
│   └── infrastructure/       # DB, auth, logging, client, and other wrappers
├── .github/workflows/ci.yml
├── .gitignore
├── package.json              # root scripts only
├── pnpm-workspace.yaml       # workspaces + catalog, or language equivalent
└── turbo.json
```

### 7. Configure root tooling

Configure the chosen build orchestrator, root scripts, formatting/linting, workspace/catalog, and
gitignore. Cover dependencies, caches, build output, and local `.env` files.

### 8. Scaffold infrastructure packages

For each required capability such as database, auth, API clients, observability, and feature flags,
create a wrapper under `packages/infrastructure/`. Each package has a native manifest, exports, an
entry point, and a clean interface that prevents features from importing vendor SDKs directly.

### 9. Scaffold apps

Resolve the exact current CLI for each approved surface, run it non-interactively under `apps/`,
remove generated visual boilerplate, retain minimal landing/health-check entry points, and connect
the apps to the root workspace.

### 10. Scaffold initial features

For each approved initial feature, create `packages/features/<feature>/` with the contracts,
services, schemas, layouts, and components its surface requires. Wire feature entry points into the
appropriate app without bypassing package boundaries.

### 11. Configure CI/CD

Create the selected CI/CD workflow for pull requests to the intended integration branch. It checks
out source, installs dependencies, runs formatting/linting, tests, type checks, and the complete
build using the actual scripts established by the scaffold.

### 12. Initialize local policy and source control

Invoke `/woostack-init` with the retained target, verified non-secret policy, and official-MCP
preflight receipt. Persist only the canonical repository URL, workspace/team, project-status and
issue-state mappings, plus unrelated tool policy. Init may create local knowledge, response,
worktree, and diagnostic stores; it must not create `.woostack/specs/`, `.woostack/plans/`, or
`.woostack/fixes/`.

Initialize Git in the primary tree, create or connect the intended remote, and independently verify
the actual canonical remote URL and initial base branch against the retained intent before the
first commit or push. Git/GitHub remain source-control authority. Bootstrap's initial scaffold and
first commit are the one worktree exemption because no base branch existed beforehand.

### 13. Verify

Install dependencies; run type checks, formatters, linters, tests, and the full build; then boot
each application and verify its health check or port. Do not hand off a scaffold that does not run.

### 14. Hand off the exact project identity

Write the project README with apps/packages, final stack decisions and rationale, exact resolved
versions, verification and development commands, canonical repository/base, and the canonical
Linear project URL. The README is onboarding documentation, not lifecycle authority.

Return the retained feature client UUID, native project ID/URL, repository, and current verified
event context to the caller. Any continuation through `woostack-build` resumes that exact project;
when its valid lifecycle reaches planning, it passes the exact project UUID or URL to
`woostack-plan`. Planning creates or reconciles managed Linear updates, issues, and relations and
never creates a local spec or plan.
