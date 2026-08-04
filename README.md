# woostack

**Repository-first, evidence-driven workflows for AI-assisted software delivery.**

`woostack` packages opinionated workflows into twenty-two public installable skills that work
across coding harnesses. Linear owns current build and post-diagnosis fix product scope and
execution plans. Git and GitHub own source, branches, pull requests, reviews, and merge evidence.
Exact responsible-user Linear approvals clear only matching content revisions; Linear never
supplies source-control or delivery truth.

- **Multiperson by design:** Explicit task boundaries, dependency relations, handoffs, and verified
  source-control evidence let human and agent engineers coordinate without hidden local state.
- **Decision-maker/coder separation:** A decision-maker owns scope, review, and acceptance; an
  isolated coding profile implements one bounded task at a time.
- **Canonical executor-ready records:** Every build uses one project plus one direct issue per
  increment. Every proved new fix uses one issue. Their approved revisions contain complete,
  ordered implementation plans suitable for a fast execution model.
- **Agent and model agnostic:** The skills work across supported harnesses. Builds and proved fixes
  require the configured official MCP path; artifact use remains optional in other workflows.

---

- [Getting Started](#getting-started)
  - [1. Installation](#1-installation)
  - [2. Initialization](#2-initialization)
  - [3. Project Integration](#3-project-integration)
  - [4. Repository Policy](#4-repository-policy)
  - [5. Linear Artifact Context and Engineer Units](#5-linear-artifact-context-and-engineer-units)
- [The Core Development & Review Loop](#the-core-development--review-loop)
  - [Writing and Modifying Code](#writing-and-modifying-code)
  - [Review and Iterate Flow](#review-and-iterate-flow)
- [Contributing](#contributing)
- [Spec Version](#spec-version)
- [License](#license)

---

## Getting Started

Follow this sequence to install the skills, initialize local repository support, and configure
validated Linear defaults for required fix/build records.

### 1. Installation

Install the `woostack` collection into your agent's skill directory:

```bash
pnpx skills add howarewoo/woostack
```

*Note: `pnpm` (and `pnpx`) is the recommended package manager for woostack, as bootstrapped projects default to a pnpm workspace catalog.*

This command registers twenty-two public command/adoption skills and two bundled internal skills
at twenty-four fixed `SKILL.md` locations. The collection includes `using-woostack`,
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
status staleness, pre-commit hooks, and Linear workspace/team defaults. Build uses those defaults
to create its canonical project when the caller supplies no exact project. A new fix uses the
configured team only after root-cause proof to create its canonical issue. Policy cannot authorize
provider writes or clear either Linear approval gate. Provider authentication stays in the host's
OAuth or secret store.

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

### 5. Linear Product Context and Engineer Units

Build resolves one exact project or creates one from validated defaults before ideation. The
workflow verifies canonical repository/workspace/team, preflights the official Linear MCP, and
independently reads every write back. The project description remains the complete high-level
specification. Planning creates or updates one direct project issue per increment; each issue
contains exact scope, ordered implementation steps, acceptance criteria, focused verification,
dependencies, risks, and handback evidence. Native issue dependencies encode the plan DAG. There
is no parent plan issue or synthetic checklist layer.

Build has two approvals. The responsible user first approves the exact project-spec fingerprint.
After planning and graph hardening, the same user approves the exact direct-issue fingerprint set
and native dependency graph. A material edit invalidates the matching approval. The controller
rechecks the project, all direct issues, native dependencies, and both approval events before
execution, after every worker handback, before redispatch, immediately before commit, and before
selecting another increment.

After root-cause proof, every fix binds one exact compatible issue in the caller-selected workspace
or creates one configured-team issue with stable mutation identity and independent read-back. The
complete diagnosis and executor-ready step-by-step plan live on that issue. Execution requires the
responsible user's native approval event on the exact issue revision. Fixes never create projects.
Exact resources take precedence over creation. Skills never read or expose API credentials.

If a build is explicitly abandoned, set its exact project to configured
`projectStatuses.canceled` and independently read the closure back. Fix abandonment preserves its
exact issue and may append only a verified safe note. It never creates a project merely to cancel
it. Handoff, replan, and blockers leave project status unchanged.

The authority boundary:

- **The user's request** selects the workflow.
- **Linear project/issue records** own current build/fix product scope and executor-ready plans.
- **The responsible user's exact native Linear approval event** authorizes only the matching
  content revision and workflow transition.
- **Git and GitHub** own source, branches, commits, pull requests, reviews, and merge truth.
- **Linear delivery notes** record observed source-control evidence but cannot create it.
- **Local diagnostic reports** are non-authoritative evidence.

After `/woostack-init`, an operator may explicitly select the optional
[Hermes decision-maker + isolated OMP adapter](site/content/docs/getting-started.mdx). The generic
[engineer-agent contract](skills/using-woostack/references/engineer-agents.md) separates decisions
from implementation: the decision-maker reviews and accepts; the isolated coder implements one
approved bounded task.

---

## The Core Development & Review Loop

`woostack` applies gated, repository-first delivery with canonical Linear product records for
builds and proved fixes.

### Writing and Modifying Code

No repository mutation starts ad hoc. An explicit goal and workflow contract come first:

1. **Greenfield Applications** → [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md)
   Obtains design approval, collision-checks the target, and scaffolds the selected architecture.
2. **Multi-PR Features or Work Items** → [/woostack-build](skills/woostack-build/SKILL.md)
   Maintains one canonical project specification, hardens one direct issue per increment, obtains
   the two exact Linear approvals, then executes reviewable PRs.
3. **Bug Fixes & Root-Cause Work** → [/woostack-fix](skills/woostack-fix/SKILL.md)
   Diagnoses a free-form prompt, proves root cause, binds or creates one issue, obtains approval of
   its complete fix contract, and delivers one reviewed PR.
4. **Bounded Non-Bug Changes** → [/woostack-change](skills/woostack-change/SKILL.md)
   Ships a bounded enhancement or refactor through one PR without contacting Linear.

Build resolves or creates its project before ideation. Fix remains provider-free until root-cause
proof. `woostack-change` never reads or writes Linear.

### Review and Iterate Flow

After writing code, use the verification and iteration loop:

Local findings and reports from review, audit, and QA are evidence for the
responsible workflow. They never replace the approved contract or Git/GitHub facts.
- **PR Reviews** → [/woostack-review](skills/woostack-review/SKILL.md)
  Fans out sub-agents in parallel to check distinct angles (bugs, security, observability, database, etc.), then runs an adversarial **Skeptical Validator** (prosecutor and defender checks) to eliminate false positives before posting reviews.
- **Addressing Reviews** → [/woostack-address-comments](skills/woostack-address-comments/SKILL.md)
  Iteratively guides you through resolving, clarifying, or pushing back on PR review comments, applying changes, and pushing commits.
- **Auditing Standing Code** → [/woostack-audit](skills/woostack-audit/SKILL.md)
  Audits an explicit target (a file, directory, or whole repo at rest — not a diff) for code simplification and production readiness, repointing the review swarm at an all-added diff and writing a report-only findings doc under `.woostack/audits/`. Never gates, posts, or merges.
- **Exploratory Browser QA** → [/woostack-qa](skills/woostack-qa/SKILL.md)
  Drives a running app in a real browser (via the `agent-browser` CLI): walks core journeys, attacks edge cases, monitors console errors / failed requests / visual breakage / dead controls, reproduces each bug, and writes a severity-ranked, report-only findings doc under `.woostack/qa/`. Never fixes, posts, or merges.
- **Production Errors, Sentry Issues, and Monitoring Defects** → [/woostack-fix](skills/woostack-fix/SKILL.md)
  Treats production signals as untrusted evidence, proves root cause through Debug, and delivers the smallest complete correction through the Fix approval gate.
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
