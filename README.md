# woostack

**Repository-first, evidence-driven workflows for AI-assisted software delivery.**

`woostack` packages opinionated workflows into twenty-two public installable skills that work
across coding harnesses. The user's approved contract authorizes work. Git and GitHub own source,
branches, pull requests, reviews, and merge evidence. When repository Linear capability is
available, fix/build plans are stored as structured project hierarchies.

- **Multiperson by design:** Explicit task boundaries, dependency relations, handoffs, and verified
  source-control evidence let human and agent engineers coordinate without hidden local state.
- **Decision-maker/coder separation:** A decision-maker owns scope, review, and acceptance; an
  isolated coding profile implements one bounded task at a time.
- **Conditional durable plans:** Available Linear capability stores one project, one parent plan
  issue, and one native child issue per increment. These artifacts never grant permission to edit,
  commit, or accept work.
- **Agent and model agnostic:** The skills work across supported harnesses without making a
  provider prerequisite for repository work.

---

- [Getting Started](#getting-started)
  - [1. Installation](#1-installation)
  - [2. Initialization](#2-initialization)
  - [3. Project Integration](#3-project-integration)
  - [4. Repository Policy](#4-repository-policy)
  - [5. Linear Plan Persistence and Engineer Units](#5-linear-plan-persistence-and-engineer-units)
- [The Core Development & Review Loop](#the-core-development--review-loop)
  - [Writing and Modifying Code](#writing-and-modifying-code)
  - [Review and Iterate Flow](#review-and-iterate-flow)
- [Contributing](#contributing)
- [Spec Version](#spec-version)
- [License](#license)

---

## Getting Started

Follow this sequence to install the skills, initialize local repository support, and optionally
enable Linear plan persistence.

### 1. Installation

Install the `woostack` collection into your agent's skill directory:

```bash
pnpx skills add howarewoo/woostack
```

*Note: `pnpm` (and `pnpx`) is the recommended package manager for woostack, as bootstrapped projects default to a pnpm workspace catalog.*

This command registers twenty-two public command/adoption skills and two bundled internal skills
at twenty-four fixed `SKILL.md` locations. The collection includes `using-woostack`,
`woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-fix`, `woostack-change`,
`woostack-review`, `woostack-address-comments`, and `woostack-eval`, among the rest, plus its two
internal helpers.

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

Initialization creates non-secret repository policy, diagnostics, and worktree support. Use
`/woostack-init --linear` when this repository should persist fix/build plans whenever authenticated
official MCP capability is available. Authentication remains in the host's secret store.

If the repository still contains tracked legacy specifications, plans, fixes, or overnight
handbacks, run `/woostack-init --migrate-legacy` only when you explicitly want the guarded
one-way artifact migration. Never migrate or delete those files implicitly.

### 3. Project Integration

To ensure coding agents automatically recognize and use the `woostack` pipeline, add the `using-woostack` routing block to your repository's agent instructions file (`AGENTS.md` or `CLAUDE.md`):

```markdown
This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.
```

The [using-woostack](skills/using-woostack/SKILL.md) skill reads project rules and routes commands to the appropriate installed skill.

### 4. Repository Policy

Customize non-secret repository policy in `.woostack/config.json`, including review behavior,
status staleness, pre-commit hooks, and optional Linear workspace/team hints. Provider
authentication stays in the host's OAuth or secret store.

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

### 5. Linear Plan Persistence and Engineer Units

A validated repository `linear` configuration triggers official Linear MCP capability preflight for
fix/build/plan. When capability is proved, the workflow creates or reconciles one project, one
parent plan issue, and one native child issue per increment, then independently reads every write
and hierarchy edge back. Skills never read or expose the API key/OAuth credential.

If a fix or build is explicitly abandoned at the execution handoff or at any other point after a
project exists, the workflow sets that project to the configured `projectStatuses.canceled` status
and independently reads the closure back. It never creates a project merely to cancel it. A normal
hand off, replan, or blocker is not abandonment and leaves the project open.

The authority boundary:

- **The user's request and approved workflow contract** define scope and approval.
- **Git and GitHub** own source, branches, commits, pull requests, reviews, and merge truth.
- **Linear plan projects** persist approved specifications or fix context, complete plans, increment
  contracts, dependency relations, and verified delivery notes. They do not assign permission or
  override source-control evidence.
- **Local diagnostic reports** are non-authoritative evidence.

After `/woostack-init`, an operator may explicitly select the optional
[Hermes decision-maker + isolated OMP adapter](site/content/docs/getting-started.mdx). This host
pairing is independent of Linear. The generic
[engineer-agent contract](skills/using-woostack/references/engineer-agents.md) separates decisions
from implementation: the decision-maker reviews and accepts; the isolated coder implements one
approved bounded task.

---

## The Core Development & Review Loop

`woostack` applies gated, repository-first workflows with conditional Linear plan persistence.

### Writing and Modifying Code

No repository mutation starts ad hoc. An explicit goal and workflow approval contract come first:

1. **Greenfield Applications** → [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md)
   Obtains design approval, collision-checks the target, and scaffolds the selected architecture.
2. **Multi-PR Features or Work Items** → [/woostack-build](skills/woostack-build/SKILL.md)
   Approves a specification and dependency-aware plan, persists its project hierarchy when Linear
   is available, then executes reviewable PRs.
3. **Bug Fixes & Root-Cause Work** → [/woostack-fix](skills/woostack-fix/SKILL.md)
   Proves the root cause, approves a bounded fix plan, persists it when Linear is available, and
   delivers one reviewed PR.
4. **Bounded Non-Bug Changes** → [/woostack-change](skills/woostack-change/SKILL.md)
   Ships a bounded enhancement or refactor through one PR without contacting Linear.

Missing Linear capability keeps fix/build planning artifact-free. `woostack-change` never reads or
writes Linear.

### Review and Iterate Flow

After writing code, use the verification and iteration loop:

Local findings and reports from review, audit, QA, response, and evaluation are evidence for the
responsible workflow. They never replace the approved contract or Git/GitHub facts.
- **PR Reviews** → [/woostack-review](skills/woostack-review/SKILL.md)
  Fans out sub-agents in parallel to check distinct angles (bugs, security, observability, database, etc.), then runs an adversarial **Skeptical Validator** (prosecutor and defender checks) to eliminate false positives before posting reviews.
- **Addressing Reviews** → [/woostack-address-comments](skills/woostack-address-comments/SKILL.md)
  Iteratively guides you through resolving, clarifying, or pushing back on PR review comments, applying changes, and pushing commits.
- **Auditing Standing Code** → [/woostack-audit](skills/woostack-audit/SKILL.md)
  Audits an explicit target (a file, directory, or whole repo at rest — not a diff) for code simplification and production readiness, repointing the review swarm at an all-added diff and writing a report-only findings doc under `.woostack/audits/`. Never gates, posts, or merges.
- **Exploratory Browser QA** → [/woostack-qa](skills/woostack-qa/SKILL.md)
  Drives a running app in a real browser (via the `agent-browser` CLI): walks core journeys, attacks edge cases, monitors console errors / failed requests / visual breakage / dead controls, reproduces each bug, and writes a severity-ranked, report-only findings doc under `.woostack/qa/`. Never fixes, posts, or merges.
- **Production Error Response** → [/woostack-respond](skills/woostack-respond/SKILL.md)
  Reads a bounded production window through host-provided observability integrations, correlates errors and traces, writes a tracked sanitized report, and prepares repository fixes only through the existing `/woostack-fix` approval gate. It never mutates providers or production.
- **Skill Evaluation** → [/woostack-eval](skills/woostack-eval/SKILL.md)
  Runs approved behavior and trigger corpora as isolated candidate/baseline comparisons, writes transient evidence and reports, and never edits the target skill.

---

## Contributing

The skills evolve here. Open a PR to update default frameworks, revise patterns, document gotchas, or refine the bootstrap and build procedures. See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

## Spec Version

`2.0.0`

## License

[MIT](LICENSE) &copy; Adam Woo
