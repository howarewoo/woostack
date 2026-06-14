# woostack feature-state conventions

These definitions are the source of truth for the `/woostack-status` board and the
`woostack-doctor` spec-plan checks.

- `spec : plan : PRs = 1 : 1 : N`
- Every spec has exactly one plan. The plan owns N independently shippable increment PRs.
- Spec frontmatter owns design approval only: `draft -> hardened -> approved`, plus terminal
  `abandoned`.
- Plan frontmatter owns implementation lifecycle after spec approval:
  `planning -> ready -> executing -> in-review -> done`, plus terminal `abandoned`.
- Before a plan exists, `/woostack-status` displays the spec's `status:` and `branch:`.
  Once a plan resolves to the spec, the board displays the plan's `status:` and `branch:`.
- spec -> plan join: the plan carries YAML frontmatter followed by a `**Source:**` line, an
  Obsidian wikilink of the form `**Source:** [[specs/<basename>]]` — symmetric with the spec's
  `> **Plan:** [[plans/<basename>]]` callout, so the graph links both ways. The `source:`
  frontmatter property mirrors the same spec path. The `**Source:**` line remains the canonical
  join for `/woostack-status` and `woostack-doctor`; both readers also accept the legacy bare-path
  form `**Source:** .woostack/specs/<file>.md`. Slug-match is the final fallback.
- plan -> PR join: every PR body carries a trailer line `Spec: .woostack/specs/<file>.md`.
  The board narrows candidates with `gh pr list --search`, then **exact-matches** the trailer
  value in each PR body to avoid fuzzy cross-matches.
- Plan frontmatter shape:
  ```yaml
  ---
  type: plan
  source: .woostack/specs/<file>.md
  status: planning
  branch: feature/<slug>
  ---

  **Source:** [[specs/<basename>]]
  ```
- Feature states:
  - `draft` — spec written, not hardened
  - `hardened` — spec grilled, needs user approval
  - `approved` — spec gate cleared, no plan yet
  - `planning` — plan written, not yet hardened, 0 boxes done
  - `ready` — plan hardened, 0 boxes done, spec+plan PR should be opened before execution
  - `executing` — branch + commits, plan partial
  - `in-review` — increment PR open
  - `done` — 100% + all PRs merged
  - `abandoned` — intentionally stopped

`/woostack-status` derives truth from artifacts and flags drift instead of rewriting it:

- unknown `status:` values;
- missing, duplicate, or slug-fallback plans;
- missing `branch:` for execution phases;
- pre-PR head-state phases (`draft` / `hardened` / `approved` / `planning`) while PRs
  already exist (`ready` is exempt — its spec+plan PR is expected before execution);
- executing rows older than `status.staleDays` (config, default 14);
- two in-flight rows on the same branch.
