# woostack feature-state conventions

These definitions are the source of truth for feature lifecycle ownership and joins across both
artifact backends, and for the `/woostack-status` board and `woostack-doctor` checks that consume
them.

## Shared cardinality

- Every feature has exactly one spec and one plan decomposition. The plan owns N independently
  shippable increment PRs.
- **Markdown:** `spec : plan : PRs = 1 : 1 : N`. The spec and plan are tracked files joined by
  reciprocal links.
- **Linear:** `managed project : managed spec document : managed increment issues : PRs =
  1 : 1 : N : N`. The project owns exactly one repository-marked spec document and one ordered
  managed issue per increment; each issue owns at most one implementation PR.

## Markdown lifecycle and joins

- Spec frontmatter owns design approval: `draft -> hardened -> approved`.
- Plan frontmatter owns implementation lifecycle after spec approval:
  `planning -> ready -> executing -> in-review -> done`.
- Retained Markdown artifacts may also carry terminal `abandoned`. The normal build spec-gate
  `Abandon` path instead closes the open PR and removes its temporary branch and worktree, so no
  spec or plan survives on which to author that state.
- Before a plan exists, `/woostack-status` displays the spec's `status:` and `branch:`.
  Once a plan resolves to the spec, the board displays the plan's `status:` and `branch:`.
- spec -> plan join: the plan carries YAML frontmatter followed by a `**Source:**` line, an
  Obsidian wikilink of the form `**Source:** [[specs/<basename>]]` — symmetric with the spec's
  `> **Plan:** [[plans/<basename>]]` callout, so the graph links both ways. The `source:`
  frontmatter property mirrors the same spec path. The `**Source:**` line remains the canonical
  join for `/woostack-status` and `woostack-doctor`; both readers also accept the legacy bare-path
  form `**Source:** .woostack/specs/<file>.md`. Slug-match is the final fallback.
- plan/issue -> PR join is backend-specific:
  - **Markdown:** every PR body carries the exact trailer line
    `Spec: .woostack/specs/<file>.md`. The board narrows candidates with
    `gh pr list --search`, then **exact-matches** the trailer value in each PR body to avoid
    fuzzy cross-matches. This spelling and path form are unchanged.
  - **Linear:** every implementation PR body ends with exactly one
    `Linear-Project: <uuid>` trailer followed by exactly one
    `Linear-Issue: <TEAM-NUMBER>` trailer. The values must identify one repository-owned
    managed issue that belongs to that project; missing API verification, missing or foreign
    issues, mismatched pairs, and duplicate trailers fail closed. The submitted branch and
    canonical repository PR URL are stored only in the managed issue metadata after successful
    Graphite submission and verified adapter read-back. This attribution proves the issue/PR
    join; it does not prove a merge and does not make the issue eligible for `done`.
    The atomic transition, evidence write, read-back classification, and retry boundary live in
    the [backend execution controller](../../woostack-execute/references/controller.md#linear-issue-cadence).
- Markdown plan frontmatter shape:
  ```yaml
  ---
  type: plan
  source: .woostack/specs/<file>.md
  status: planning
  branch: feature/<slug>
  ---

  **Source:** [[specs/<basename>]]
  ```
- Markdown feature states:
  - `draft` — spec written, not hardened
  - `hardened` — spec grilled, needs user approval
  - `approved` — spec gate cleared, no plan yet
  - `planning` — plan written, not yet hardened, 0 boxes done
  - `ready` — plan hardened, 0 boxes done, spec+plan PR should be opened before execution
  - `executing` — authored by `woostack-execute` for non-final increments; branch + commits,
    plan partial
  - `in-review` — increment PR open
  - `done` — authored by `woostack-execute` at the final increment (all boxes `[x]`, plan files);
    the board also derives/confirms it from artifacts (100% + all active PRs merged) and shows
    `in-review` while the final PR is still open; a closed-unmerged PR is workflow noise (only
    open + merged PRs count) and no longer blocks `done` once the plan is complete; a
    zero-checkbox plan has no progress signal, so the board trusts its authored `done` only when
    every active (open/merged) increment PR is merged (or no PR at all was discovered —
    closed included — and the branch has no active commits)
  - `abandoned` — intentionally stopped on a retained artifact; a terminal human decision never
    overridden by artifact-derived `done`. The build spec-gate cleanup path leaves no retained
    artifact and therefore authors no `abandoned` state.

## Linear lifecycle and joins

- The managed spec document's `designState` owns the complete design/execution handoff sequence:
  `draft -> hardened -> approved -> planning -> ready -> executionApproved -> executing ->
  inReview -> done`, plus terminal `abandoned`.
- The Linear project mirrors that lifecycle through configured project statuses, except
  `executionApproved`: while that spec-only approval marker is set, the project remains `ready`
  until execution begins.
- `ready -> planning` is the only backward transition and is allowed only for an explicit
  pre-execution replan with no increment branch or pull-request evidence. Any active state may
  transition to `abandoned`; `done` and `abandoned` are terminal.
- The canonical `baseBranch` + `baseCommitSha` pair may first be frozen only in `ready` with
  evidence proving no implementation branch or PR exists. It remains provisional during an
  evidence-free replan and becomes immutable at `executionApproved`.
- Each managed increment issue owns a stable identity, unique ordinal, dependency/Git-parent
  shape, issue lifecycle (`planned`, `executing`, `inReview`, `done`, or `blocked`), and its
  branch/PR evidence.
- project -> spec join: the managed metadata carries the exact Linear `projectId` and canonical
  repository identity; discovery requires exactly one matching managed spec document.
- project -> increments join: every managed increment carries the same `projectId`, repository
  identity, and stable increment identity. Native blocking relations must match metadata
  dependencies.
- increment -> PR join: the issue's managed branch and pull-request fields identify its one
  implementation PR. Linear mode creates no Markdown spec/plan file or docs-only PR.

`/woostack-status` derives truth from artifacts and flags drift instead of rewriting it:

- unknown `status:` values;
- missing, duplicate, or slug-fallback plans;
- missing `branch:` for execution phases;
- pre-PR head-state phases (`draft` / `hardened` / `approved` / `planning`) while PRs
  already exist (`ready` is exempt — its spec+plan PR is expected before execution);
- executing rows older than `status.staleDays` (config, default 14);
- two in-flight rows on the same branch.
