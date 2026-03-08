# PR Review GitHub Action Design

## Goal

Convert the existing Claude Code `/pr-review` skill (5 parallel subagents) into a GitHub Action that runs automatically on every PR and on-demand via `/review` comments.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Trigger | Auto on PR open/sync + on-demand `/review` comment | Maximum coverage + manual re-review |
| Tool | `anthropics/claude-code-action@v1` | Official Anthropic action, supports skills and custom prompts |
| Auth | `CLAUDE_CODE_OAUTH_TOKEN` (Claude subscription) | No API billing; Pro/Max users generate via `claude setup-token` |
| Review scope | Full review on every PR | No cost concern with subscription auth |
| Prompt strategy | Custom prompt embedding all auditor criteria | Single-pass, predictable in CI, no subagent spawning |
| Output format | GitHub PR review (inline comments) + summary comment | Best developer experience |

## Architecture

### New File

```
.github/workflows/claude-review.yml
```

### Unchanged

- `.github/workflows/ci.yml` — existing CI (lint, typecheck, build, test, react-doctor, E2E)
- `.claude/skills/pr-review/` — existing local skill (still usable via `/pr-review` in Claude Code)

### Workflow Structure

```yaml
name: Claude PR Review

on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  review:
    if: |
      github.event_name == 'pull_request' ||
      (github.event_name == 'issue_comment' &&
       github.event.issue.pull_request &&
       contains(github.event.comment.body, '/review'))
    runs-on: ubuntu-latest
    concurrency:
      group: claude-review-${{ github.event.pull_request.number || github.event.issue.number }}
      cancel-in-progress: true
    timeout-minutes: 30
    steps:
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: <custom review prompt>
          claude_args: "--model claude-opus-4-6 --max-turns 10"
```

### Custom Review Prompt

The prompt consolidates all 5 auditor criteria into a single-pass instruction:

1. **Security Audit** — SQL/NoSQL injection, XSS, auth gaps, authorization bypass, sensitive data exposure, CSRF, race conditions, insecure randomness, path traversal, deserialization, command injection, Next.js/React-specific (server action security, API route protection, client-side secrets, redirect vulnerabilities)

2. **Architecture Audit** — Monorepo import boundaries (Principles I & II: features can only import from infrastructure, never from other features), file organization (Principle III: procedures in `procedures/`, contracts as `{feature}Contract.ts`, routers as `{feature}ORPCRouter.ts`), feature exposure patterns (Principle XII/XIII: Surface/Handler/Layout suffixes), infrastructure usage (Principle IV: no duplicating what exists in `@infrastructure/*`), file extension (.ts unless JSX)

3. **Constitution Audit** — All 14 project principles: monorepo structure (I), feature-based architecture (II), naming conventions (III), infrastructure priority (IV), pnpm catalog (V), TypeScript standardization (VI), cross-platform UI (VII), TDD (VIII), oRPC API (IX: contract-first, proper naming, ORPCError), TanStack Query (X: no useEffect for data loading), Next.js server components (XI), feature exposure (XII), API stability (XIII), platform-agnostic navigation (XIV: use @infrastructure/navigation, never next/navigation or expo-router)

4. **Code Quality Audit** — Complexity (functions >50 lines, cyclomatic complexity >10, nesting >3 levels, >5 parameters), code smells (duplication, dead code, magic numbers, primitive obsession), error handling (missing try/catch, swallowed errors, generic messages, missing type guards), TypeScript quality (missing return types, unsafe `as` assertions), performance (N+1 queries, large bundle imports), testing gaps (missing tests for new logic, insufficient edge case coverage)

5. **API Stability Audit** — oRPC contract-first pattern (Principle IX), breaking URL changes (path changes, endpoint removal, route renaming), breaking input schema changes (field removal/rename, type changes, optional→required), breaking output schema changes (field removal, type changes, field renames), correct import paths (contracts in `contracts/`, routers in `routers/`, client via `@infrastructure/api-client`)

### Output Format

Claude is instructed to:

1. **Submit a GitHub PR review** with:
   - Inline comments on specific files/lines for each finding
   - Each comment includes severity tag, category, description, and suggested fix
   - Review action: REQUEST_CHANGES if any HIGH findings, COMMENT otherwise

2. **Post a summary comment** with:
   - Auditor results table (findings per category)
   - Severity breakdown (HIGH/MEDIUM/LOW counts)
   - Prioritized recommendations (Immediate/Should Address/Consider Later)
   - Mermaid diagram for complex logic flows (when applicable)

### Severity & Blocking Guidelines

- **HIGH**: Exploitable vulnerabilities, import boundary violations, breaking API changes, N+1 queries, swallowed errors
- **MEDIUM**: Conditional vulnerabilities, naming violations, code smells, missing tests
- **LOW**: Best practice improvements, minor style issues, optional optimizations

### What React Doctor Covers (excluded from prompt)

React Doctor already runs as a separate CI job in `ci.yml` with 63+ rules. The Claude review prompt explicitly excludes React-specific patterns (state management, effects, performance, hooks rules) to avoid duplication.

## Setup Requirements

1. Run `claude setup-token` locally to generate OAuth token
2. Add `CLAUDE_CODE_OAUTH_TOKEN` as a GitHub Actions secret
3. Install the Claude GitHub app: https://github.com/apps/claude
4. Add the workflow file to `.github/workflows/`

## Relationship to Existing Skill

The local `/pr-review` skill continues to work unchanged. The GitHub Action is an independent automation path:

| Aspect | Local `/pr-review` | GitHub Action |
|--------|---------------------|---------------|
| Execution | Claude Code CLI, 5 parallel subagents | GitHub runner, single-pass |
| Trigger | Manual invocation | Auto on PR + `/review` comment |
| Auth | Local Claude subscription | OAuth token in GitHub secrets |
| React Doctor | Pre-check before auditors | Separate CI job (unchanged) |
| Output | `gh pr comment` + `gh pr edit` | Native PR review + summary comment |
| Loop mode | Supported (iterative fix) | Not supported (single-pass only) |
| Local mode | Supported (task list) | N/A |
