# woostack

**Linear-backed multiperson collaboration and project tracking for AI-assisted software delivery.**

`woostack` packages opinionated workflows into twenty-three public installable skills that work
across coding harnesses. The official Linear MCP is the only development-record channel: a
standalone change or fix is one Linear issue, while multi-issue work is one Linear project with
specification-bearing project updates and ordered increment issues. Those updates own the project's
specification, decisions, phase, and progress; no Linear document is created. Git and GitHub remain
authoritative for code, branches, pull requests, reviews, and merge evidence.

- **Multiperson by design:** Explicit ownership, dependency relations, handoffs, and verified
  read-backs let human and agent engineers coordinate without hidden local state.
- **Decision-maker/coder separation:** A decision-making engineer owns scope, review, and
  acceptance; an isolated coding agent implements one assigned issue at a time.
- **Local knowledge, not shadow state:** Memory and wisdom retain reusable learnings per clone.
  Local diagnostic reports are advisory and never determine scope, status, assignment, or
  acceptance.
- **Agent and model agnostic:** The skills work across supported harnesses without moving
  development authority out of Linear.

---

- [Getting Started](#getting-started)
  - [1. Installation](#1-installation)
  - [2. Initialization](#2-initialization)
  - [3. Project Integration](#3-project-integration)
  - [4. Repository Policy](#4-repository-policy)
  - [5. Linear MCP and Engineer Units](#5-linear-mcp-and-engineer-units)
- [The Core Development & Review Loop](#the-core-development--review-loop)
  - [Writing and Modifying Code](#writing-and-modifying-code)
  - [Review and Iterate Flow](#review-and-iterate-flow)
- [Local Knowledge System](#local-knowledge-system)
  - [Architecture](#architecture)
  - [Context Routing](#context-routing)
  - [Obsidian Vault Integration](#obsidian-vault-integration)
- [Contributing](#contributing)
- [Spec Version](#spec-version)
- [License](#license)

---

## Getting Started

Follow this sequence to connect your repository to the official Linear MCP, install the skills, and
give every human or agent engineer an explicit authority envelope.

### 1. Installation

Install the `woostack` collection into your agent's skill directory:

```bash
pnpx skills add howarewoo/woostack
```

*Note: `pnpm` (and `pnpx`) is the recommended package manager for woostack, as bootstrapped projects default to a pnpm workspace catalog.*

This command registers twenty-three public command/adoption skills and three bundled supporting
skills at twenty-six fixed `SKILL.md` locations. The collection includes `using-woostack`,
`woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-fix`, `woostack-change`,
`woostack-review`, `woostack-address-comments`, and `woostack-eval`, among the rest, plus its
internal and unregistered helpers.

> **Recommended companion — [impeccable](https://github.com/pbakaus/impeccable).** woostack's front-end design skill of choice. It powers the `design` review angle (`woostack-review` runs impeccable's detector). Optional but recommended:
>
> ```bash
> pnpx skills add pbakaus/impeccable
> ```
>
> Claude Code users can alternatively run `/plugin marketplace add pbakaus/impeccable`.

### 2. Initialization

Authenticate the current host against the
[official Linear MCP](https://mcp.linear.app/mcp). This current-host connection is the only host
setup required for generic initialization; Hermes, OMP, and paired launchers are not prerequisites.
Then run the initialization skill in the project root:

```bash
/woostack-init
```

> [!IMPORTANT]
> **Run `/woostack-init` before using any other woostack skill.** Initialization requires only the
> current host's authenticated official Linear MCP connection. It verifies the repository's Linear
> policy, then creates the local knowledge, configuration, and diagnostic workspace.

If the repository still contains tracked legacy specifications, plans, fixes, or overnight
handbacks, run `/woostack-init --migrate-legacy`. This is the only migration route. Active work
moves to verified Linear resources; completed history stays in Git. Every source file remains until
ownership, provenance repair, independent read-back, and Git byte recovery all pass.

### 3. Project Integration

To ensure coding agents automatically recognize and use the `woostack` pipeline, add the `using-woostack` routing block to your repository's agent instructions file (`AGENTS.md` or `CLAUDE.md`):

```markdown
This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.
```

The [using-woostack](skills/using-woostack/SKILL.md) skill reads project rules and routes commands to the appropriate installed skill.

### 4. Repository Policy

Customize non-secret repository policy in `.woostack/config.json`, including code-review behavior,
native Linear status mappings, and pre-commit hooks. MCP authentication stays in the host's OAuth
and secret store, never in repository configuration.

Review-policy fragment (merge it into the init-generated file; do not replace the required `linear` mappings):
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

### 5. Linear MCP and Engineer Units

Every participating profile connects to the
[official Linear MCP](https://mcp.linear.app/mcp). Woostack discovers the capabilities exposed by
the active host, proves the required project, issue, update, comment, ownership, relation, status,
and independent read-back operations, and fails closed before development when that proof is
incomplete. It never assumes a host-specific MCP tool name.

The authority boundary is deliberate:

- **Linear** is the only development record. One standalone issue owns a bounded change or fix.
  Multi-issue work uses one project, specification-bearing project updates, and ordered increment
  issues. Project updates own its specification, decisions, phase, and progress. No Linear document
  is created.
- **Git and GitHub** own source, branches, commits, pull requests, reviews, and merge truth.
- **Local memory and wisdom** are reusable knowledge only. Local audit, QA, response, evaluation,
  and other diagnostic reports are non-authoritative evidence.

Only after `/woostack-init` has established and verified repository policy may an operator
explicitly select the optional
[Hermes decision-maker + isolated OMP adapter](site/content/docs/getting-started.mdx). That pairing
is a conditional host setup, not part of generic initialization.

The generic [engineer-agent contract](skills/using-woostack/references/engineer-agents.md) separates
decisions from implementation. In the published
[Hermes + OMP setup](site/content/docs/getting-started.mdx), Hermes decides, independently reads and
reviews the result, comments on the PR, and accepts or redispatches. Hermes never edits source, runs
implementation or tests, commits, pushes, or opens an implementation PR. Its isolated OMP profile
codes exactly one assigned Linear issue at a time. Only an explicit `/woostack-review` invocation
may delegate independent review analysis; Hermes still owns the acceptance decision.

---

## The Core Development & Review Loop

`woostack` applies the same gated workflow to each Linear-backed development record.

### Writing and Modifying Code

No repository mutation starts ad hoc. The sole pre-issue exception is
`/woostack-bootstrap`'s approved project-first scaffold: its verified Linear project authorizes the
initial scaffold before planning creates increment issues. Every later implementation task, and
every non-bootstrap coding task, binds to exactly one Linear issue and enters through one of four
development skills:

1. **Greenfield Applications** → [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md)
   Obtains design approval, creates the Linear project record, and scaffolds the selected
   architecture.
2. **Multi-PR Features or Work Items** → [/woostack-build](skills/woostack-build/SKILL.md)
   Uses one Linear project and ordered increment issues for work that needs multiple reviewable
   PRs.
3. **Bug Fixes & Root-Cause Work** → [/woostack-fix](skills/woostack-fix/SKILL.md)
   Diagnoses the root cause and binds the approved fix to one standalone Linear issue.
4. **Bounded Non-Bug Changes** → [/woostack-change](skills/woostack-change/SKILL.md)
   Ships a bounded enhancement or refactor through one standalone Linear issue and one PR.

> [!WARNING]
> **No implementation code should be written or modified without a bound Linear issue.** The only
> exception is `/woostack-bootstrap`'s initial approved project-first, project-owned scaffold before
> planning; every later bootstrap implementation increment is issue-bound. Multi-PR features use
> `/woostack-build`, bugs use `/woostack-fix`, and bounded one-PR non-bug work uses
> `/woostack-change`.

### Review and Iterate Flow

After writing code, use the verification and iteration loop:

Local findings and reports from review, audit, QA, response, and evaluation are evidence for the
responsible decision-maker. They never replace the Linear contract or Git/GitHub facts.

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

## Local Knowledge System

The local memory and wisdom stores retain reusable architecture patterns, gotchas, and conventions
on a per-clone basis so later sessions do not repeat mistakes. They are knowledge, not a
development ledger: only Linear can establish scope, ownership, dependencies, lifecycle, progress,
or acceptance.

### Architecture

Memories are scoped per-fact Markdown notes under `.woostack/memory/`, which is gitignored to avoid
cross-developer leakage. Each note contains one reusable fact plus simple context and provenance:

```markdown
---
name: orpc-error-mapping
type: pattern
scope: packages/api/**, packages/api/orpc/**
hook: oRPC error → TanStack retry policy
updated: 2026-06-02
source: linear://issue/22222222-2222-4222-8222-222222222222
---
oRPC ORPCError maps to TanStack retry policy: throw typed,
let [[tanstack-query-retries]] decide.
```

### Context Routing

Rather than loading the entire memory corpus on every run (which would bloat prompts and waste tokens), `woostack` routes context dynamically:
1. **Scope Matching**: The recall script checks the files modified in the current session against note `scope` glob patterns.
2. **One-Hop Expansion**: Only the matching notes—and any notes they link to directly via `[[wikilinks]]`—are loaded.
This keeps prompt growth sub-linear, loading only the few notes relevant to the files under development.

### Obsidian Vault Integration

The `.woostack/memory/` store is designed to be fully compatible with Obsidian. Developers can open `.woostack/` directly as an Obsidian vault to visualize their local knowledge graph.

- Scaffold Obsidian configuration files using:
  ```bash
  /woostack-init --obsidian
  ```

For more details on the memory specification, see the [Scope-Routed Memory Contract](skills/woostack-init/references/memory.md).

---

## Contributing

The skills evolve here. Open a PR to update default frameworks, revise patterns, document gotchas, or refine the bootstrap and build procedures. See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

## Spec Version

`2.0.0`

## License

[MIT](LICENSE) &copy; Adam Woo
