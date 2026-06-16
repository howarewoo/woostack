# woostack

**A model-agnostic collection of software development skills covering every phase of the engineering process.**

`woostack` packages opinionated, gated workflows into installable skills that any AI coding agent can follow—covering every stage of software engineering from greenfield project bootstrapping to feature building, debugging, automated code review, and feedback iteration. It provides a standard set of decisions for projects of any size, complete with a local, token-efficient memory system.

- **Agent & Model Agnostic**: Works seamlessly across Claude Code, Cursor, Codex, Aider, and other agents that respect the `skills` convention.
- **Local Memory System**: Retains and routes learnings on a per-clone basis, ensuring subsequent agent sessions do not repeat prior mistakes.
- **Team-Ready**: Designed for small-to-medium teams working on collaborative codebases.

---

- [Getting Started](#getting-started)
  - [1. Installation](#1-installation)
  - [2. Initialization](#2-initialization)
  - [3. Project Integration](#3-project-integration)
  - [4. Repository Configuration](#4-repository-configuration)
- [The Core Development & Review Loop](#the-core-development--review-loop)
  - [Writing and Modifying Code](#writing-and-modifying-code)
  - [Review and Iterate Flow](#review-and-iterate-flow)
- [Local Memory System](#local-memory-system)
  - [Architecture](#architecture)
  - [Context Routing](#context-routing)
  - [Obsidian Vault Integration](#obsidian-vault-integration)
- [Contributing](#contributing)
- [Spec Version](#spec-version)
- [License](#license)

---

## Getting Started

Follow this sequence to adopt and configure `woostack` in your repository.

### 1. Installation

Install the `woostack` collection into your agent's skill directory:

```bash
pnpx skills add howarewoo/woostack
```

*Note: `pnpm` (and `pnpx`) is the recommended package manager for woostack, as bootstrapped projects default to a pnpm workspace catalog.*

This command registers the public skills (e.g. `using-woostack`, `woostack-init`, `woostack-bootstrap`, `woostack-build`, `woostack-fix`, `woostack-review`, `woostack-address-comments`, etc.) and internal helper skills in `skills-lock.json`.

> **Recommended companion — [impeccable](https://github.com/pbakaus/impeccable).** woostack's front-end design skill of choice. It powers the `design` review angle (`woostack-review` runs impeccable's detector) and front-end design craft inside the build loop. Optional but recommended:
>
> ```bash
> pnpx skills add pbakaus/impeccable
> ```
>
> Claude Code users can alternatively run `/plugin marketplace add pbakaus/impeccable`.

### 2. Initialization

Run the initialization skill in the project root:

```bash
/woostack-init
```

> [!IMPORTANT]
> **You must run `/woostack-init` before using any other woostack skills.** This sets up the `.woostack/` workspace structure, default configurations, and gitignores.

### 3. Project Integration

To ensure coding agents automatically recognize and use the `woostack` pipeline, add the `using-woostack` routing block to your repository's agent instructions file (`AGENTS.md` or `CLAUDE.md`):

```markdown
This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.
```

The [using-woostack](skills/using-woostack/SKILL.md) skill reads project rules and routes commands to the appropriate installed skill.

### 4. Repository Configuration

Customize tool behaviors using `.woostack/config.json`. This configures aspects like code reviews and pre-commit hooks without requiring you to fork the skill collection.

Example `.woostack/config.json`:
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

For detailed configurations, see [woostack-review config options](skills/woostack-review/SKILL.md#per-repo-configuration-woostackconfigjson).

---

## The Core Development & Review Loop

`woostack` enforces structured, gated pipelines to ensure high-quality code changes.

### Writing and Modifying Code

No code changes should be made ad-hoc. All coding tasks must go through one of the three primary development entry points:

1. **Greenfield Applications** → [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md)
   Walks through a technology selection protocol, obtains design approval, and scaffolds a clean monorepo architecture.
2. **Features** → [/woostack-build](skills/woostack-build/SKILL.md)
   A fixed, gated loop from idea to PR: `ideate → spec → spec-approval (gate) → plan → execute (TDD) → review → commit`.
3. **Fixes & Refactors** → [/woostack-fix](skills/woostack-fix/SKILL.md)
   A lightweight, unified fix loop for bugs: `diagnose root-cause → plan → plan-approval (gate) → execute (TDD) → commit`.

> [!WARNING]
> **No code should be written or modified without using one of these three skills.** Greenfield apps use `/woostack-bootstrap`, features use `/woostack-build`, and fixes/bugs use `/woostack-fix`. This ensures all code changes follow a gated, structured design and test-driven workflow.

### Review and Iterate Flow

After writing code, use the verification and iteration loop:

- **PR Reviews** → [/woostack-review](skills/woostack-review/SKILL.md)
  Fans out sub-agents in parallel to check distinct angles (bugs, security, observability, database, etc.), then runs an adversarial **Skeptical Validator** (prosecutor and defender checks) to eliminate false positives before posting reviews.
- **Addressing Reviews** → [/woostack-address-comments](skills/woostack-address-comments/SKILL.md)
  Iteratively guides you through resolving, clarifying, or pushing back on PR review comments, applying changes, and pushing commits.

---

## Local Memory System

The memory system allows agents to accumulate durable learnings (such as architecture patterns, gotchas, and conventions) locally on a per-clone basis, ensuring later sessions build upon previous ones.

### Architecture

All memories are saved locally as scoped per-fact Markdown notes under `.woostack/memory/` (which is gitignored to prevent cross-developer leakage). Each note defines a single fact and contains simple frontmatter declaring its context scope, type, and source:

```markdown
---
name: orpc-error-mapping
type: pattern
scope: packages/api/**, packages/api/orpc/**
hook: oRPC error → TanStack retry policy
updated: 2026-06-02
source: .woostack/specs/2026-06-02-api-errors.md
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
