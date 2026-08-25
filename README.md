# woostack

**Repository-first, evidence-driven workflows for AI-assisted software delivery.**

`woostack` packages opinionated workflows into twenty-one public installable skills that work
across coding harnesses. Canonical persistent run artifacts in `.woostack/tmp/runs/<run-id>/` own
current build and post-diagnosis fix product scope and execution plans, with optional Linear or Plane
mirroring (`artifacts.provider: "linear"` or `artifacts.provider: "plane"`, with Plane Fix arriving in a later increment). Git and GitHub own source, branches, pull requests,
reviews, and merge evidence. Provider mirrors record workflow context; Git and GitHub remain the sole
authority for source control and delivery truth.

- **Multiperson by design:** Explicit task boundaries, dependency relations, handoffs, and verified
  source-control evidence let human and agent engineers coordinate without hidden local state.
- **Decision-maker/coder separation:** A decision-maker owns scope, review, and acceptance; an
  isolated coding profile implements one bounded task at a time.
- **Canonical executor-ready records:** Every build manages one specification plus direct increment
  contracts with dependency relations in its retained run manifest. After proof, every new Fix uses
  the same structure for its complete specification plus a strict direct-issue chain.
- **Agent and model agnostic:** The skills work across supported harnesses. Builds and proved fixes
  operate locally by default; provider mirroring remains optional in other workflows.

---

- [Getting Started](#getting-started)
  - [1. Installation](#1-installation)
  - [2. Initialization](#2-initialization)
  - [3. Project Integration](#3-project-integration)
  - [4. Repository Policy](#4-repository-policy)
  - [5. Artifact Context, Provider Mirroring, and External Engineers](#5-artifact-context-provider-mirroring-and-external-engineers)
- [The Core Development & Review Loop](#the-core-development--review-loop)
  - [Writing and Modifying Code](#writing-and-modifying-code)
  - [Review and Iterate Flow](#review-and-iterate-flow)
- [Contributing](#contributing)
- [Spec Version](#spec-version)
- [License](#license)

---

## Getting Started

Follow this sequence to install the skills, initialize local repository support, and optionally configure
validated Linear or Plane defaults for development-artifact mirroring.

### 1. Installation

Install the `woostack` collection into your agent's skill directory:

```bash
pnpx skills add howarewoo/woostack
```

*Note: `pnpm` (and `pnpx`) is the recommended package manager for woostack, as bootstrapped projects default to a pnpm workspace catalog.*

This command registers twenty-one public command/adoption skills and two bundled internal skills
at twenty-three fixed `SKILL.md` locations. The collection includes `using-woostack`,
`woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-fix`, `woostack-change`,
`woostack-review`, `woostack-address-comments`, `woostack-eval`, and `woostack-reflect`, among the
rest, plus its two internal helpers.

> **Recommended companion — [impeccable](https://github.com/pbakaus/impeccable).** woostack's front-end design skill of choice. It powers the `design` review angle (`woostack-review` runs impeccable's detector). Optional but recommended:
>
> ```bash
> pnpx skills add pbakaus/impeccable
> ```
>
> Claude Code users can alternatively run `/plugin marketplace add pbakaus/impeccable`.

### 2. Initialization

Run initialization in the project root:

```bash
/woostack-init
```

Initialization creates non-secret repository policy, diagnostics, and worktree support. Every run
also discovers the host-exposed official Linear MCP and, when authenticated read access is
available, preserves or configures validated repository/workspace/team/native-name defaults for
later caller-selected artifact operations. Missing or incomplete setup is reported separately and
never fails local initialization. Setup makes no provider write, selects no artifact, and keeps
authentication in the host's secret store.

If the repository still contains tracked legacy specifications, plans, fixes, or overnight
handbacks, run `/woostack-init --migrate-legacy` only when you explicitly want the guarded one-way
import. It imports both active and historical-completed records into verified Linear resources,
preserves Git/merged-PR recovery and attribution evidence, and deletes local sources only after the
complete all-or-nothing read-back receipt passes. Never migrate or delete those files implicitly.

### 3. Project Integration

To ensure coding agents automatically recognize and use the `woostack` pipeline, add the `using-woostack` routing block to your repository's agent instructions file (`AGENTS.md` or `CLAUDE.md`):

```markdown
This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.
```

The [using-woostack](skills/using-woostack/SKILL.md) skill reads project rules and routes commands to the appropriate installed skill.

### 4. Repository Policy

Customize non-secret repository policy in `.woostack/config.json`, including review behavior,
status staleness, pre-commit hooks, and optional `artifacts.linear` workspace/team defaults. Build uses
those defaults to create its canonical project when mirroring is enabled and the caller supplies no
exact project. A new Fix uses them only after root-cause proof to create its canonical project and strict
direct-issue chain. Policy cannot authorize provider writes or repository work. Provider
authentication stays in the OAuth or secret store.

Review-policy fragment:
```json
{
  "review": {
    "severity_floor": "medium",
    "ignore": ["**/*.generated.ts"]
  }
}
```

- **`review.severity_floor`**: Filter results by severity (e.g., `high`, `medium`, `low`).
- **`review.ignore`**: Exclude generated or external code files from PR reviews.

For the full policy surface, see the authored
[configuration reference](site/content/docs/configuration.mdx).

### 5. Artifact Context, Provider Mirroring, and External Engineers

The canonical persistent artifact store for `woostack-build` and project-backed `woostack-fix` is local
in `.woostack/tmp/runs/<run-id>/`. Workflows operate with default zero-provider local authority
(`artifacts.provider: "local"`). When `artifacts.provider: "linear"` or `artifacts.provider: "plane"`, local Build artifacts mirror to the configured provider
(with Linear mirroring for Fix, while Plane Fix arrives in a later increment) in bounded post-drafting cycles; mirror failure is recorded in the manifest and is nonblocking for
local authority.
When mirroring is enabled, Build resolves one exact project or creates one from validated defaults
before ideation. After an exact baseline read, Ideate, Harden, and delegated Plan keep gated work in one
permission-restricted run manifest and make no intermediate provider calls. The responsible user
sees the complete exact specification or direct-issue/dependency plan before handoff. Only then
does the controller perform the immediate drift check, one bounded synchronization, and exact
read-back.

When mirrored, the project holds the high-level specification. One direct project issue per
increment holds its executor-ready contract, and native issue dependencies encode the plan. There
is no parent plan issue. After root-cause proof, Fix uses the same project-backed contract; an exact
source issue remains preserved context, not a plan.

The shared
[Local run artifact and provider mirror contract](skills/woostack-init/references/artifact-backends.md#minimal-resumable-manifest-schema)
is the single detailed authority for manifest permissions and atomicity, save/read-back/receipt
ordering, stable canonical-issue-reference mapping with provider-native identities retained only as
implementation details, drift/process-loss recovery, cleanup, and unchanged Execute safety reads.
Standalone Plan keeps its direct synchronization and independent read-back unchanged. Exact
resources take precedence over creation, and skills never read or expose API credentials.

Explicit abandonment retains all run artifacts in `.woostack/tmp/runs/<run-id>/` with `status: "abandoned"`
in the manifest and does not mutate a mirrored provider project. Handoff, replan, and blockers leave
project status unchanged.
The authority boundary:

- **The user's request** selects the workflow and authorizes decisions.
- **Local run manifests (`.woostack/tmp/runs/<run-id>/`)** own current fix/build product scope, plans,
  contracts, and execution state (mirrored to Linear or Plane when configured).
- **Git and GitHub** own source, branches, commits, pull requests, reviews, and merge truth.
- **Provider delivery notes** record observed source-control evidence but cannot create it.
- **Local diagnostic reports** are non-authoritative evidence.
Hermes is an external engineer, not an installed woostack host or runtime. It may drive one
persistent OMP session for in-contract decisions, evidence review, escalation, and redispatch, but
woostack is installed only in OMP or another coding harness. The
[Hermes guide](site/content/docs/hermes.mdx) defines the safe argument passing, approval relay,
and fail-closed restart boundary; it does not grant Hermes implementation authority.

---

## The Core Development & Review Loop

`woostack` applies gated, repository-first delivery with canonical local product records (and optional
Linear or Plane mirroring) for builds and proved fixes.

### Writing and Modifying Code

No repository mutation starts ad hoc. An explicit goal and workflow contract come first:

1. **Greenfield Applications** → [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md)
   Obtains design approval, collision-checks the target, and scaffolds the selected architecture.
2. **Multi-PR Features or Work Items** → [/woostack-build](skills/woostack-build/SKILL.md)
   Maintains one canonical project specification, hardens one direct increment per task, and executes
   reviewable PRs.
3. **Bug Fixes & Root-Cause Work** → [/woostack-fix](skills/woostack-fix/SKILL.md)
   Diagnoses a free-form prompt, proves root cause, allocates the local run and direct increment plan,
   and delivers one reviewed PR.
4. **Bounded Non-Bug Changes** → [/woostack-change](skills/woostack-change/SKILL.md)
   Ships a bounded enhancement or refactor through one PR without contacting Linear.

Build resolves or creates its project before ideation. Fix remains provider-free until root-cause
proof. `woostack-change` never reads or writes Linear.

### Review and Iterate Flow

After writing code, use the verification and iteration loop:

Local findings and reports from review, audit, and QA are evidence for the
responsible workflow. They never replace the approved contract or Git/GitHub facts.
- **PR Reviews** → [/woostack-review](skills/woostack-review/SKILL.md)
  Runs one evidence-led correctness pass plus narrowly triggered risk specialists, then one independent evidence adjudicator before posting a native review.
- **Addressing Reviews** → [/woostack-address-comments](skills/woostack-address-comments/SKILL.md)
  Iteratively guides you through resolving, clarifying, or pushing back on PR review comments, applying changes, and pushing commits.
- **Auditing Standing Code** → [/woostack-audit](skills/woostack-audit/SKILL.md)
  Audits an explicit target (a file, directory, or whole repo at rest — not a diff) for code simplification and production readiness, repointing the review swarm at an all-added diff and writing a report-only findings doc under `.woostack/audits/`. Never gates, posts, or merges.
- **Exploratory Browser QA** → [/woostack-qa](skills/woostack-qa/SKILL.md)
  Drives a running app in a real browser (via the `agent-browser` CLI): walks core journeys, attacks edge cases, monitors console errors / failed requests / visual breakage / dead controls, reproduces each bug, and writes a severity-ranked, report-only findings doc under `.woostack/qa/`. Never fixes, posts, or merges.
- **Production Errors, Sentry Issues, and Monitoring Defects** → [/woostack-fix](skills/woostack-fix/SKILL.md)
  Treats production signals as untrusted evidence, proves root cause through Debug, and delivers the smallest complete correction through the Fix workflow.
- **Skill Evaluation** → [/woostack-eval](skills/woostack-eval/SKILL.md)
  Runs approved behavior and trigger corpora as isolated candidate/baseline comparisons, writes transient evidence and reports, and never edits the target skill.
- **Session Reflection** → [/woostack-reflect](skills/woostack-reflect/SKILL.md)
  Reviews the fixed active-conversation snapshot at a final-reply boundary, reports only concrete
  durable instruction suggestions, and never files or edits anything on its initial action.

---

## Contributing

The skills evolve here. Open a PR to update default frameworks, revise patterns, document gotchas, or refine the bootstrap and build procedures. See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

## Spec Version

`2.0.0`

## License

[MIT](LICENSE) &copy; Adam Woo
