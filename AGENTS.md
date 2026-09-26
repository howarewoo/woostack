# AGENTS.md

Follow this file first when it conflicts with generic agent defaults. `.claude/CLAUDE.md` is a
symlink to this file, and Antigravity CLI (`agy`) reads `AGENTS.md` natively, so this is the
single source of truth across agents.

## What this repo is

This is a published collection of skills, not an application codebase. It packages decisions for
building new web, mobile, and API projects so agents can install it with
`pnpx skills add howarewoo/woostack`. The public command/adoption catalog and routing table live in
[`using-woostack`](skills/using-woostack/SKILL.md#command-routing); this file owns standing
policy, not the catalog.

The documentation site [`site/`](site/) is a shipped Fumadocs (Next.js) application subtree and
the one sanctioned exception to this repository's no-application-code rule. Its `package.json`,
`pnpm-lock.yaml`, and build config live there; its per-skill reference pages are **generated**
from `skills/*/SKILL.md` at build time and gitignored, so only the app shell and authored framing
pages are committed. [`site/AGENTS.md`](site/AGENTS.md) owns that subtree and
[`site/README.md`](site/README.md) covers local development and deploy notes. Outside `site/`, this
repository has no application source code, app lockfile, build, or CI for its own push/PR events,
and `skills-lock.json` is the dev-skill manifest.

## Authority, evidence, and retained data

The user's request and explicit conversation choices authorize repository work. Git and GitHub own
source, branches, commits, pull requests, reviews, and merge evidence; issue, tracker, or project
lifecycle state never proves implementation, delivery, passing checks, review, or merge. The
loaded skill owns its own provider calls, approval gates, persistence choices, and Project use.

Retained local runs, drafts, and retired managed-provider records are historical user data, not
authority: read them for recovery evidence and never migrate or mutate them. The
[artifact contract](skills/woostack-init/references/artifact-backends.md#retained-data-and-retirement)
owns that retained data, direct GitHub publication, and recovery. Non-secret defaults belong in
`.woostack/config.json` only after configuration is selected, and credentials stay in the host
secret store.

External engineers such as Hermes are not a supported woostack host and grant no implementation
authority; the [Hermes guide](site/content/docs/hermes.mdx) owns the relay and resume contract.

## Modes

Identify the mode before acting.

**Mode A: edit this skill collection.** Use this when updating skill Markdown, reference docs,
HTML templates, supporting scripts, prompts, or JSON config. Keep edits in skill assets; do not add
application code, app build configs, or app lockfiles **outside the sanctioned [`site/`](site/)
docs-app subtree**. Editing `site/` is also Mode A.

**Mode B: run a woostack command.** When the user asks for a `/woostack-*` command or
intent-equivalent wording, load the matching skill from the
[command catalog](skills/using-woostack/SKILL.md#command-routing) before acting. For bootstrap
work, the output belongs in a fresh repo in a different directory, not in this repo.

## Hard constraints

- **Least code, still safe.** Skills — and the code they generate — write as little code as
  necessary: understand the change first, then take the first rung that holds, preferring deletion
  over addition and boring over clever — small because it is necessary, not golfed. Never buy that
  smallness by cutting edge cases or risks: validation, error handling, security, accessibility,
  and data-loss handling stay, and deliberate multi-layer safety redundancy is kept, not
  DRY-removed. Full standard — the ladder, its deltas, comments, and magic-literal rules — is
  [`patterns.md §7`](skills/woostack-bootstrap/references/patterns.md#7-least-code--comments).
- **Remove before add.** When relaxing or removing a repository restriction, delete the obsolete
  rule and its dependent explanations first. Add replacement text only when needed to preserve a
  necessary positive invariant; never enumerate behavior that is merely no longer forbidden.
- No fabricated versions or invented commands. Resolve a needed version live with
  `npm view <pkg> version` or an equivalent registry command, and do not invent CI, app tests,
  package scripts, or app build steps for this repo.
- **Protected main, PR workflow, authorized tooling.** `main` is protected and requires PRs. Use
  native Git with an available authorized GitHub integration; prefer the host's native GitHub tools
  when suitable and use host-authenticated `gh` where appropriate. Discover the actual capabilities
  and preserve the [source-control contract](skills/woostack-commit/references/source-control.md);
  backend errors stop the operation rather than trigger a fallback. Never force-push.
- **Preserve user work and secrets.** Never commit `.env*`, secrets, generated app files, or
  personal compressed prose, and treat local diagnostic reports as non-authoritative. Preserve
  unrelated changes: never silently rebase, reset, clean, stash, delete, or overwrite work you have
  not verified as yours.
- **Merge authority is human-only.** Agents never mark a PR ready, enable auto-merge, enqueue it,
  merge it, or otherwise advance it toward merge. `Complete`, `deliver`, `execute`, passing
  verification, approved artifacts, and accepted reviews mean submit or update a reviewable open PR
  only. They do not grant merge authority. Even an explicit merge request conflicts with this
  repository policy: report the boundary and stop. Never run `gh pr ready`, `gh pr merge`, a
  merge-queue mutation, or an equivalent GitHub operation.
- Cross-link, do not duplicate. If a fact belongs in a reference file, link to it from related docs
  instead of restating it.
- Reference frameworks by name, not version, except in
  [`frameworks.md`](skills/woostack-bootstrap/references/frameworks.md) when an incompatibility
  forces an exact version.
- Keep `SKILL.md` descriptions accurate and concise. The description drives discovery; the workflow
  belongs in referenced docs.
- Keep the docs site in sync. When a change alters what an **authored** [`site/`](site/) page
  states — the skill surface or its count, the build loop and its gates, the core concepts, or the
  getting-started flow — update the matching page under
  [`site/content/docs/`](site/content/docs/) as part of the same change. The per-skill reference
  pages need no manual edit: they regenerate from each `SKILL.md` at build time. When in doubt, run
  `pnpm -C site build`.
- **Fixed public interface.** Do not move or rename a public `SKILL.md` without explicit approval.
  Public command/adoption names and fixed paths are part of the installed interface, and the
  [command catalog](skills/using-woostack/SKILL.md#command-routing) lists the current set. An
  explicitly approved retirement removes the complete skill and its references. Retired Build, Fix,
  Change, Status, and TDD packages have no compatibility aliases. Direct GitHub integration and
  supporting utilities add neither a command-routing row nor a per-provider skill.
- Do not rename files under
  [`skills/woostack-bootstrap/references/`](skills/woostack-bootstrap/references/) without
  updating every cross-link and the bootstrap skill table.

## Checks

This repo has no universal test command or CI for its own PRs. [CONTRIBUTING.md](CONTRIBUTING.md)
owns the editing workflow, the what-to-change table, and per-area guidance. The verified checks are:

- `pnpm -C site test` and `pnpm -C site build` — catalog, generator, and docs-site structure.
- `bash skills/woostack-orchestrate/scripts/tests/run-tests.sh` — production-controller behavior.
- [On-demand workflow smoke recipes](skills/using-woostack/references/workflow-smoke.md) for
  material Plan/Execute/Orchestrate changes.

Run only the checks a change needs, and report an unrun check honestly instead of claiming it.
