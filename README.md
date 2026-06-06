# woostack

**An installable collection of opinionated skills that encode my software-development process (bootstrap, build, review, iterate) for both new and existing codebases.**

This is a public representation of how I build software, packaged so any AI coding agent can follow the same loop. It covers the life of a change end to end: load project rules, scaffold a project (greenfield), drive a feature, review it, and address the feedback (brownfield, since those work in any existing repo, not just one woostack created). The scope grows over time toward the rest of the loop. A commit utility for good messages and other day-to-day tools are on the way.

Not a template. It's the decisions and workflow an agent follows. For greenfield, that's the frameworks, architecture, infrastructure, and patterns to scaffold, resolved at the latest versions every time. For brownfield, it's the gated build → review → iterate loop applied to whatever repo you're in.

- [Why a skill instead of a template?](#why-a-skill-instead-of-a-template)
- [Install](#install)
- [How it works](#how-it-works): what each command does
- [Quickstart](#quickstart): greenfield and brownfield entry points
- [Concepts](#concepts): artifacts, branching, the review swarm
- [Configuration](#configuration)
- [Default stack](#default-stack)
- [What it defines](#what-it-defines)
- [Cloud / CI review](#cloud--ci-review)

## Why a skill instead of a template?

Templates rot. Dependencies drift, breaking changes pile up, and every new project starts from a snapshot that was already stale by the time you cloned it. Coding agents are good enough now that scaffolding from scratch is cheap. What's expensive is *deciding* what to scaffold. This skill holds those decisions so the agent doesn't re-litigate them every time someone wants a new project.

## Install

```bash
pnpx skills add howarewoo/woostack
```

This installs the woostack **collection** into your agent's skill directory and records it in `skills-lock.json`. The public command/adoption surface is thirteen skills: using-woostack, woostack-init, woostack-bootstrap, woostack-build, woostack-plan, woostack-execute, woostack-execute-overnight, woostack-commit, woostack-review, woostack-address-comments, woostack-status, woostack-visualize, and woostack-debug. The collection also installs two internal sub-skills used by `woostack-build` — `woostack-ideate` and `woostack-harden`; neither is a `/woostack-*` command. Works in any agent that respects the `skills` convention: Claude Code, Cursor, Codex, Aider, and others.

> **pnpm is the recommended package manager.** Commands in this repo use `pnpx` (and `pnpm`) over `npx` / `npm`. If you only have npm, `npx skills add howarewoo/woostack` works too, but woostack-bootstrapped projects use a pnpm catalog, so pnpm is the path of least friction.

To make a repo consistently use woostack, add `using-woostack` to the repo's agent instructions file (`AGENTS.md` for Codex and other agents, or `CLAUDE.md` for Claude Code). This gives agents an entry point for loading repo-local rules and routing `/woostack-*` requests to the matching skill.

Minimal `AGENTS.md` / `CLAUDE.md` snippet:

```markdown
This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.
```

## How it works

Each command is a skill with its own gated procedure. Together they cover the life of a change: load project rules, scaffold, build, review, iterate. Run a command by name in your agent (e.g. `/woostack-build add password reset`); the agent loads that skill's `SKILL.md` and follows it. **Codex syntax differs:** use `$woostack-build add password reset` or open `/skills` and select the skill. Only `bootstrap` is greenfield-specific. `build`, `review`, and `address-comments` operate on any repo, whether woostack scaffolded it or not.

### `using-woostack`: project adoption and command routing

An adoption skill for consumer repositories. Reference it from a project's root `AGENTS.md` when you want agents to load project-local woostack rules before acting, then route `/woostack-*` requests to the matching command skill. It does not initialize `.woostack/`, scaffold code, or mutate the project by itself. → [SKILL.md](skills/using-woostack/SKILL.md)

### `/woostack-bootstrap <goal>`: scaffold a new monorepo

Walks you through the [decision catalog](skills/woostack-bootstrap/references/decisions.md) and gets explicit sign-off on every relevant choice, then scaffolds a web/mobile/API monorepo. Versions are resolved **live** at scaffold time (`npm view <pkg> version`), never hard-coded, and cross-checked against a known-gotchas list. After scaffolding it verifies the project boots: `pnpm install && typecheck && build && test && dev`. → [SKILL.md](skills/woostack-bootstrap/SKILL.md)

### `/woostack-build <goal>`: feature loop, idea to PR

A fixed, gated chain that drives one feature from idea to implementation:

```
ideate → markdown spec → harden → approve spec → plan → execute (TDD) → reviewed PR stack
```

It sequences woostack's own ideate, harden, plan, and execute phases (`woostack-ideate`, `woostack-harden`, `woostack-plan`, `woostack-execute`), inheriting the ideate design gate and hosting the relocated spec-approval gate before planning — the build loop has no external skill dependencies. Specs and plans are both written as markdown under `.woostack/`; an HTML render is available on demand for a richer view but is never the authored format. Work ships as PR-sized stacked increments (soft target ≤500 LOC) — one plan per spec, multiple PRs per plan — each committed, reviewed (`woostack-review --fast`), and distilled. The execution-handoff gate lets you Go (execute now), Hand off (execute later/elsewhere), or Run overnight (`woostack-execute-overnight`, unattended). It ends on the reviewed PR stack. It never merges. → [SKILL.md](skills/woostack-build/SKILL.md)

### `/woostack-plan <spec-path>`: write a plan from a spec

Writes a comprehensive implementation plan for an approved markdown spec from `.woostack/specs/` — file-structure first, bite-sized TDD tasks with no placeholders, structured as PR-sized increments — saved frontmatter-free to `.woostack/plans/<spec-basename>.md` with an opening `**Source:**` line that joins it 1:1 to the spec, and sets the spec's `status: planning`. It is the plan phase `woostack-build` step 4 delegates to, and is usable standalone. Pairs with `woostack-execute` (produce-plan / consume-plan). Writes the plan and hands back; never executes or merges. → [SKILL.md](skills/woostack-plan/SKILL.md)

### `/woostack-execute <plan-path>`: run a plan as stacked PRs

Executes an approved markdown plan from `.woostack/plans/` as a sequence of PR-sized, stacked increments — implementing each with TDD, ticking the plan's checkboxes in place, committing via `woostack-commit` on its own Graphite branch, reviewing it with `woostack-review --fast`, and distilling durable learnings — pausing only on a blocking review. One plan per spec, multiple PRs per plan. It is the execute phase `woostack-build` step 9 delegates to, and is usable standalone. Never merges. → [SKILL.md](skills/woostack-execute/SKILL.md)

### `/woostack-execute-overnight <plan-path>`: run a plan unattended overnight

Executes an approved plan the way `woostack-execute` does, but **unattended** — one autonomous run with no input after launch. It reuses execute's per-increment cadence and drivers and overrides only the stop-points: a stuck verification routes to `woostack-debug --auto`, a blocking review is auto-addressed (`woostack-address-comments --auto`, bounded) or escalated, and anything unsafe or ambiguous becomes a logged blocker — safety is never relaxed for autonomy. A blocker ends its track (plans may group increments under optional `## Track:` headings; default is one linear stack) and the run continues. It writes a **morning report** to `.woostack/overnight/` for a human to test in the morning. It is the third choice at `woostack-build`'s execution-handoff gate (Go / Hand off / Run overnight), and is usable standalone. Never merges. → [SKILL.md](skills/woostack-execute-overnight/SKILL.md)

### `/woostack-review [PR#]`: parallel review swarm

Detects relevant review angles for the diff (bugs and security always on; SEO, design, react, database, tests, api, types, i18n, docs and more conditionally), fans out one sub-agent per angle in parallel, then runs an adversarial **Skeptical Validator** (a prosecutor pass and a defender pass) to cut false positives before anything is posted. With a PR number it posts a single batched native GitHub review; with no PR it reviews the local diff and prints findings. Host-agnostic: it falls back to a sequential loop on agents without parallel sub-agents. → [SKILL.md](skills/woostack-review/SKILL.md)

### `/woostack-commit`: commit and update the PR

Commits only the changes relevant to the current session, creates a `feature/*` branch first when the agent is on `staging` or `main`, then pushes/submits and updates the PR title/body with a concise bulleted summary and test plan. It prefers Graphite, never force-pushes, and stops before staging ambiguous unrelated work. → [SKILL.md](skills/woostack-commit/SKILL.md)

### `/woostack-address-comments [PR#]`: work the review threads

Walks every unresolved review thread on a PR, recommends a verdict per thread (fix / push back / clarify), then, once you approve the batch, applies fixes, replies, resolves, and pushes. Accept-by-design dismissals are recorded to `.woostack/memory.md` so future reviews don't re-raise them. Never merges. A thin delegator to the review skill's `address` verb. → [SKILL.md](skills/woostack-address-comments/SKILL.md)

### `/woostack-status [--all] [--fetch]`: derived feature board

A read-only, on-demand board derived fresh from your `.woostack/` artifacts: for every spec it shows the reconciled phase, plan progress, increment-PR rollup, owner, age, and the single next action, and flags any drift between the authored `status:` and what's on disk. It never fetches (except the opt-in `--fetch`), commits, or pushes, and writes no `STATUS.md`. Backed by the `spec : plan : PRs = 1 : 1 : N` invariant and the phase enum defined once in [conventions.md](skills/woostack-status/references/conventions.md). → [SKILL.md](skills/woostack-status/SKILL.md)

### `/woostack-visualize <source> [for <audience>]`: audience-tailored HTML render

A discovery command for rendering source material as an audience-tailored HTML view while keeping the source authoritative. → [SKILL.md](skills/woostack-visualize/SKILL.md)

### `/woostack-debug <target> [--auto]`: find the root cause before fixing

Runs woostack's systematic-debugging method on a bug, test failure, or unexpected behavior: root-cause investigation → pattern analysis → hypothesis/test → a minimal fix with a failing test first, under the Iron Law (no fix without a root cause) and a 3-fixes-→-question-the-architecture escalation. It recalls known `gotcha`s from `.woostack/memory/` at the start and distills one at the end. Standalone it gates on the root cause before fixing (the gated form `woostack-review` points you at for a confirmed bug); `--auto` runs autonomously (how `woostack-execute` calls it on a stuck verification). Never commits or merges. → [SKILL.md](skills/woostack-debug/SKILL.md)

### Growing scope

The collection tracks more of my day-to-day loop as it matures. Planned next: a commit utility that writes well-documented, conventional commit messages, plus other small tools that smooth the edges between the steps above.

## Quickstart

Install once, then pick the entry point that matches where you are.

**Greenfield: start a new project**

```bash
pnpx skills add howarewoo/woostack          # install the collection into your agent

/woostack-bootstrap a habit-tracker with web + mobile + API   # scaffolds a fresh repo; walks you through decisions first
/woostack-build add streak tracking with a weekly reset       # build a feature in the new repo
/woostack-review 42                                           # review the PR build opened
/woostack-address-comments 42                                 # iterate on the review's findings
```

**Brownfield: work in an existing repo.** Skip `bootstrap` and run the loop in place.

```bash
pnpx skills add howarewoo/woostack          # install once
# add `using-woostack` to AGENTS.md or CLAUDE.md so agents load repo rules

/woostack-build add CSV export to the reports page   # feature loop in your current repo
/woostack-review 1337                                # review the PR
/woostack-address-comments 1337                      # iterate
```

Review and address-comments need the GitHub CLI (`gh`) authenticated for any step that touches a PR.

## Concepts

**Artifacts live under `.woostack/`.** Each project the skills touch keeps its working artifacts there: markdown specs in `.woostack/specs/`, markdown plans in `.woostack/plans/`, and review config + memory in `.woostack/config.json` and `.woostack/memory.md`. `.woostack/metrics.json` is per-clone and gitignored. See [development.md](skills/woostack-bootstrap/references/development.md).

**Branching model.** Bootstrapped projects use `main` (production) ← `staging` (integration) ← `feature/*` (one change, one PR). Feature branches cut from `staging` and PR back into it; `staging` merges to `main` on a release cadence. → [development.md](skills/woostack-bootstrap/references/development.md)

**Memory: scope-routed notes that persist across runs.** The skills accumulate durable learnings — patterns, decisions, gotchas, conventions, hotspots — so later runs don't re-litigate or re-discover what an earlier run already settled. Memory is two coexisting layers, both checked into the repo:

- **Flat shard** (`.woostack/memory.md`) — a free-form bullet list, always loaded in full. This is where accept-by-design dismissals land (so future reviews don't re-raise a finding you intentionally accepted).
- **Scope-routed store** (`.woostack/memory/`) — one Markdown note per fact, each with a `scope:` glob declaring which files it governs (e.g. `packages/api/**`). A derived index (`MEMORY.md`) carries one cheap line per note. When a skill loads context for a working set of files, it matches only the notes whose scope overlaps those files, plus their direct `[[wikilinks]]` (one hop). Recall stays sub-linear: on a repo with 500 notes, only the handful touching the changed files load, not the whole corpus.

Notes are written two ways: **distillation** by `woostack-execute` after each implemented increment (durable cross-feature learnings, scoped to the touched files, with `source:` provenance back to the spec/plan), and the **accept-by-design** path from `woostack-address-comments` (review-noise suppression → flat shard). `/woostack-init` scaffolds the store; `build-index.sh` rebuilds the index; `doctor.sh` lints it. → [memory.md](skills/woostack-init/references/memory.md)

**The review swarm + skeptical validation.** Review isn't a single agent reading a diff. It's `detect → fan-out (one sub-agent per angle) → merge → skeptical validator → post`. The validator runs as a prosecutor (find reasons each finding is real) and a defender (find reasons to drop it), and only findings that survive both get posted, which keeps the output low-noise. The chat-host swarm and the cloud GitHub Action run the *same* scripts and prompts. → [SKILL.md](skills/woostack-review/SKILL.md#architecture)

**woostack-review is first-party here.** It lives at `skills/woostack-review/`; the standalone `howarewoo/woo-review` repo is deprecated.

## Configuration

Consumer repos can add `.woostack/config.json` to tune woostack behavior without forking the skill collection. Run `/woostack-init` once to scaffold the `.woostack/` workspace, or create the file directly when you only need a small override.

Review settings live under a top-level `review` object so the same config file can grow sibling namespaces later without collisions. All keys are optional; missing config keeps the built-in defaults. The review defaults are intentionally quiet: `severity_floor` is `high`, bot-authored dependency/update PRs are skipped, and release-rollup PR titles are skipped unless you override those rules.

Minimal example:

```json
{
  "review": {
    "severity_floor": "medium",
    "angles": {
      "skip": ["seo"],
      "force": ["database"]
    },
    "ignore": ["**/*.generated.ts"],
    "project_rules": ["docs/standards/*.md"]
  }
}
```

Use config for repository-specific review policy: widen or narrow the severity floor, force or skip optional angles, ignore generated files, add rule documents, customize bot/release auto-skips, opt into local metrics, or adjust diff chunking for large PRs. `bugs` and `security` always run and cannot be skipped. Invalid JSON or unknown keys inside `review` fail loudly so configuration mistakes do not silently change review behavior. → [Per-repo Configuration](skills/woostack-review/SKILL.md#per-repo-configuration-woostackconfigjson)

## Default stack

| Layer | Default |
|---|---|
| Web / Landing | Next.js (App Router) + React Compiler + shadcn/ui |
| Mobile | Expo + React Native + react-native-reusables + UniWind |
| API | Hono + oRPC |
| Data | TanStack Query + Zod + Supabase (Postgres, Auth, Storage) |
| Styling | Tailwind CSS (CSS-first) with a shared theme |
| Build | Turborepo + pnpm catalog |
| Lint/format | Biome |
| Testing | Vitest, Jest (RN), Playwright |
| Hosting | Vercel (web + api) + Expo EAS (mobile) |

Defaults, not mandates. Bootstrap confirms each with you. Versions are resolved at bootstrap time. See [frameworks.md](skills/woostack-bootstrap/references/frameworks.md).

## What it defines

The bootstrap skill's decisions live in reference files, loaded on demand:

| Reference | What it defines |
|---|---|
| [decisions.md](skills/woostack-bootstrap/references/decisions.md) | Decision catalog the agent walks the user through before scaffolding |
| [bootstrap.md](skills/woostack-bootstrap/references/bootstrap.md) | Step-by-step bootstrap procedure for AI agents |
| [architecture.md](skills/woostack-bootstrap/references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [frameworks.md](skills/woostack-bootstrap/references/frameworks.md) | Recommended frameworks per layer, catalog protocol, known gotchas |
| [infrastructure.md](skills/woostack-bootstrap/references/infrastructure.md) | Hosting, CI/CD, env, observability, auth, data layer |
| [patterns.md](skills/woostack-bootstrap/references/patterns.md) | oRPC contracts, TanStack Query, RSC, navigation, TDD, feature exposure |
| [development.md](skills/woostack-bootstrap/references/development.md) | Development workflow and branching model |

## Cloud / CI review

`/woostack-review` also ships as a GitHub Action so the same swarm runs in your CI, with no local agent required. It's delivered two ways from this repo: a composite action ([`action.yml`](action.yml)) and a `workflow_call`-only reusable workflow ([`.github/workflows/reusable-review.yml`](.github/workflows/reusable-review.yml)). Both drive the same `skills/woostack-review/` scripts and prompts as the chat-host skill.

Drop this into the consumer repo at `.github/workflows/ai-review.yml`:

```yaml
name: AI PR Review
on:
  pull_request:
    types: [opened, reopened, ready_for_review]
  issue_comment:
    types: [created]

jobs:
  review:
    # Authorization gate. issue_comment fires in the base-repo context where
    # secrets are live, for ANY commenter, so restrict comment-triggered runs
    # to trusted actors. Without this, a fork contributor's comment can spend
    # your token (the GitHub "pwn-requests" pattern).
    if: >-
      github.event_name == 'pull_request' ||
      (github.event_name == 'issue_comment' &&
       github.event.issue.pull_request != null &&
       contains(fromJSON('["OWNER","MEMBER","COLLABORATOR"]'), github.event.comment.author_association))
    uses: howarewoo/woostack/.github/workflows/reusable-review.yml@main
    with:
      provider: anthropic
    secrets:
      anthropic_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

The `if:` gate matters: the `issue_comment` trigger runs in the base-repo context with secrets available to *any* commenter, so it's restricted to the repo owner, members, and collaborators. Drop it and a fork contributor's comment could trigger a run on your token. Past that, there's zero local setup in the consumer repo: the action ships its own prompts and scripts and installs the `react-doctor` / `impeccable` CLIs via `npx` at run time. The provider is pluggable (Anthropic, OpenAI, Google, OpenRouter); pin `@main` to a release tag once one is cut. PR comments like `/woostack-review`, `/woostack-review recheck`, `/woostack-review --fast` (or `--deep`), and `/woostack-review force` re-trigger it without leaving the PR. → [SKILL.md](skills/woostack-review/SKILL.md#companion-github-action)

## Contributing

The skill evolves here. Open a PR to update default frameworks, revise patterns, document gotchas, or refine the bootstrap procedure. See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

## Spec version

`2.0.0`. First spec-only release. The prior template lives in git history.

## License

[MIT](LICENSE) &copy; Adam Woo
