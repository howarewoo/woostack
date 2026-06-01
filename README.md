# woostack

**An installable collection of opinionated skills that encode my software-development process (bootstrap, build, review, iterate) for both new and existing codebases.**

This is a public representation of how I build software, packaged so any AI coding agent can follow the same loop. It covers the life of a change end to end: scaffold a project (greenfield), drive a feature, review it, and address the feedback (brownfield, since those work in any existing repo, not just one woostack created). The scope grows over time toward the rest of the loop. A commit utility for good messages and other day-to-day tools are on the way.

Not a template. It's the decisions and workflow an agent follows. For greenfield, that's the frameworks, architecture, infrastructure, and patterns to scaffold, resolved at the latest versions every time. For brownfield, it's the gated build → review → iterate loop applied to whatever repo you're in.

- [Why a skill instead of a template?](#why-a-skill-instead-of-a-template)
- [Install](#install)
- [How it works](#how-it-works): what each command does
- [Quickstart](#quickstart): greenfield and brownfield entry points
- [Concepts](#concepts): artifacts, branching, the review swarm
- [Default stack](#default-stack)
- [What it defines](#what-it-defines)
- [Cloud / CI review](#cloud--ci-review)

## Why a skill instead of a template?

Templates rot. Dependencies drift, breaking changes pile up, and every new project starts from a snapshot that was already stale by the time you cloned it. Coding agents are good enough now that scaffolding from scratch is cheap. What's expensive is *deciding* what to scaffold. This skill holds those decisions so the agent doesn't re-litigate them every time someone wants a new project.

## Install

```bash
pnpx skills add howarewoo/woostack
```

This installs the woostack **collection** (skills: woostack-bootstrap, woostack-build, woostack-review, woostack-address-comments) into your agent's skill directory and records it in `skills-lock.json`. Works in any agent that respects the `skills` convention: Claude Code, Cursor, Codex, Aider, and others.

> **pnpm is the recommended package manager.** Commands in this repo use `pnpx` (and `pnpm`) over `npx` / `npm`. If you only have npm, `npx skills add howarewoo/woostack` works too, but woostack-bootstrapped projects use a pnpm catalog, so pnpm is the path of least friction.

## How it works

Each command is a skill with its own gated procedure. Together they cover the life of a change: scaffold, build, review, iterate. Run a command by name in your agent (e.g. `/woostack-build add password reset`); the agent loads that skill's `SKILL.md` and follows it. Only `bootstrap` is greenfield-specific. `build`, `review`, and `address-comments` operate on any repo, whether woostack scaffolded it or not.

### `/woostack-bootstrap <goal>`: scaffold a new monorepo

Walks you through the [decision catalog](skills/woostack-bootstrap/references/decisions.md) and gets explicit sign-off on every relevant choice, then scaffolds a web/mobile/API monorepo. Versions are resolved **live** at scaffold time (`npm view <pkg> version`), never hard-coded, and cross-checked against a known-gotchas list. After scaffolding it verifies the project boots: `pnpm install && typecheck && build && test && dev`. → [SKILL.md](skills/woostack-bootstrap/SKILL.md)

### `/woostack-build <goal>`: feature loop, idea to PR

A fixed, gated chain that drives one feature from idea to implementation:

```
brainstorm → HTML spec → grill → plan → execute (TDD) → offer PR
```

It sequences proven sub-skills (superpowers brainstorming/writing-plans/executing-plans + grill-me) and inherits their approval gates rather than adding its own. Specs are written as self-contained HTML, plans as markdown, both under `.woostack/`. Work is steered toward reviewable PRs (soft target ≤500 LOC), one increment per cycle. It ends by *offering* a PR. It never merges. → [SKILL.md](skills/woostack-build/SKILL.md)

### `/woostack-review [PR#]`: parallel review swarm

Detects relevant review angles for the diff (bugs and security always on; SEO, design, react, database, tests, api, types, i18n, docs and more conditionally), fans out one sub-agent per angle in parallel, then runs an adversarial **Skeptical Validator** (a prosecutor pass and a defender pass) to cut false positives before anything is posted. With a PR number it posts a single batched native GitHub review; with no PR it reviews the local diff and prints findings. Host-agnostic: it falls back to a sequential loop on agents without parallel sub-agents. → [SKILL.md](skills/woostack-review/SKILL.md)

### `/woostack-address-comments [PR#]`: work the review threads

Walks every unresolved review thread on a PR, recommends a verdict per thread (fix / push back / clarify), then, once you approve the batch, applies fixes, replies, resolves, and pushes. Accept-by-design dismissals are recorded to `.woostack/memory.md` so future reviews don't re-raise them. Never merges. A thin delegator to the review skill's `address` verb. → [SKILL.md](skills/woostack-address-comments/SKILL.md)

### Growing scope

The collection tracks more of my day-to-day loop as it matures. Planned next: a commit utility that writes well-documented, conventional commit messages, plus other small tools that smooth the edges between the steps above.

## Quickstart

Install once, then pick the entry point that matches where you are.

**Greenfield: start a new project**

```bash
pnpx skills add howarewoo/woostack          # install the collection into your agent

/woostack-bootstrap a habit-tracker with web + mobile + API   # scaffolds a fresh repo; walks you through decisions first
/woostack-build add streak tracking with a weekly reset       # build a feature in the new repo
/woostack-review 42                                            # review the PR build opened
/woostack-address-comments 42                                 # iterate on the review's findings
```

**Brownfield: work in an existing repo.** Skip `bootstrap` and run the loop in place.

```bash
pnpx skills add howarewoo/woostack          # install once

/woostack-build add CSV export to the reports page   # feature loop in your current repo
/woostack-review 1337                                 # review the PR
/woostack-address-comments 1337                       # iterate
```

Review and address-comments need the GitHub CLI (`gh`) authenticated for any step that touches a PR.

## Concepts

**Artifacts live under `.woostack/`.** Each project the skills touch keeps its working artifacts there: HTML specs in `.woostack/specs/`, markdown plans in `.woostack/plans/`, and review config + memory in `.woostack/config.json` and `.woostack/memory.md`. `.woostack/metrics.json` is per-clone and gitignored. See [development.md](skills/woostack-bootstrap/references/development.md).

**Branching model.** Bootstrapped projects use `main` (production) ← `staging` (integration) ← `feature/*` (one change, one PR). Feature branches cut from `staging` and PR back into it; `staging` merges to `main` on a release cadence. → [development.md](skills/woostack-bootstrap/references/development.md)

**The review swarm + skeptical validation.** Review isn't a single agent reading a diff. It's `detect → fan-out (one sub-agent per angle) → merge → skeptical validator → post`. The validator runs as a prosecutor (find reasons each finding is real) and a defender (find reasons to drop it), and only findings that survive both get posted, which keeps the output low-noise. The chat-host swarm and the cloud GitHub Action run the *same* scripts and prompts. → [SKILL.md](skills/woostack-review/SKILL.md#architecture)

**woostack-review is first-party here.** It lives at `skills/woostack-review/`; the standalone `howarewoo/woo-review` repo is deprecated.

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

The `if:` gate matters: the `issue_comment` trigger runs in the base-repo context with secrets available to *any* commenter, so it's restricted to the repo owner, members, and collaborators. Drop it and a fork contributor's comment could trigger a run on your token. Past that, there's zero local setup in the consumer repo: the action ships its own prompts and scripts and installs the `react-doctor` / `impeccable` CLIs via `npx` at run time. The provider is pluggable (Anthropic, OpenAI, Google, OpenRouter); pin `@main` to a release tag once one is cut. PR comments like `/woostack-review`, `/woostack-review recheck`, and `/woostack-review force` re-trigger it without leaving the PR. → [SKILL.md](skills/woostack-review/SKILL.md#companion-github-action)

## Contributing

The skill evolves here. Open a PR to update default frameworks, revise patterns, document gotchas, or refine the bootstrap procedure. See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

## Spec version

`2.0.0`. First spec-only release. The prior template lives in git history.

## License

[MIT](LICENSE) &copy; Adam Woo
