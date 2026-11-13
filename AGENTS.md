# AGENTS.md

- Skills must work independently. For skill composition or application-boundary changes, follow
  [editing conventions](CONTRIBUTING.md#editing-conventions).
- Edit shared assets in `shared/`, then run `node shared/sync.mjs` and commit the generated
  skill-local copies together. [The mapping](shared/mapping.json) owns their destinations.
- Public skill names and paths are installed interfaces. Moving, renaming, or retiring one
  requires explicit approval; approved retirements remove its references without compatibility aliases.
- Retained runs, drafts, and retired provider records are historical user data: never migrate or
  mutate them. For publication or retained-data changes, read the
  [artifact contract](shared/references/artifact-backends.md).
- Keep `.claude/CLAUDE.md` as a symlink to this file. Docs changes also follow
  [apps/docs/AGENTS.md](apps/docs/AGENTS.md).

## Validation

- Prose: inspect changed claims, links, and anchors. Skill behavior: trace the changed instruction
  path. Neither requires a full build just because a `SKILL.md` changed.
- Shared assets: regenerate and run `node shared/sync.mjs --check`; use the existing
  `apps/docs/scripts/skill-assets.test.mjs` and `shared-sync.test.mjs` suites for asset/layout changes.
  Parser or generator changes use `apps/docs/scripts/gen-skills.test.mjs`. Run suites with `node --test`.
- App or rendering changes: run applicable checks; `pnpm build --filter=docs` is required when
  narrower checks do not cover production-build risk. Install needed dependencies from the root
  with `pnpm install --frozen-lockfile`; never link `node_modules` from another checkout.
- Material Whiteboard, Execute, Deliver, or Orchestrate changes require the relevant
  [workflow smoke recipe](skills/using-woostack/references/workflow-smoke.md).

Explicit acceptance checks still apply. Helper tests do not prove that a model followed a workflow;
report actual checks and unverified outcomes separately.

## Delivery

Use a topic branch from `main` or an approved stack predecessor and submit a draft PR with
[the template](.github/pull_request_template.md). For Git/PR operations, follow
[delivery](shared/references/delivery.md) and [source control](shared/references/source-control.md).
Existing readiness stays unchanged unless requested. Merging, auto-merge, and merge queues are human-only.
