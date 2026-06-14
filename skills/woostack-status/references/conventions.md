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
- spec -> plan join: the plan carries YAML frontmatter followed by a `**Source:**` line of the
  exact form `**Source:** .woostack/specs/<file>.md`. The `source:` frontmatter property must
  match the same spec path for Obsidian, but the `**Source:**` line remains the canonical join
  for `/woostack-status`, `woostack-doctor`, and legacy compatibility. Slug-match is the legacy
  fallback.
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

  **Source:** .woostack/specs/<file>.md
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
- head-state phases while PRs already exist;
- executing rows older than `status.staleDays` (config, default 14);
- two in-flight rows on the same branch.
