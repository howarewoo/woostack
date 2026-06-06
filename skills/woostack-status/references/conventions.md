# woostack feature-state conventions

Canonical definitions for the `/woostack-status` board. Other skills link here;
they do not restate these rules (cross-link, do not duplicate).

## Invariant: spec : plan : PRs = 1 : 1 : N

- Every spec has exactly one plan. The plan owns N independently shippable
  increment PRs.
- spec -> plan join: the plan carries, in its first ~5 lines, a line of the exact
  form `**Source:** .woostack/specs/<file>.md`. Slug-match is the legacy fallback.
  Plans stay frontmatter-free.
- plan -> PR join: every PR body carries a trailer line
  `Spec: .woostack/specs/<file>.md` (written by woostack-commit). The board narrows
  candidates with `gh pr list --search`, then **exact-matches** the trailer against each PR
  body (`specs/<basename>`) — `gh --search` is fuzzy and would otherwise cross-match
  look-alike specs, so an untrailered or sibling PR never attaches to the wrong spec. When no
  trailered PR resolves, it falls back to the active `spec.branch:` head PR (marked partial).
- `spec.branch:` names the active increment's branch.
- An overnight run ([`woostack-execute-overnight`](../../woostack-execute-overnight/SKILL.md)) may
  produce **tree-stacked** increment PRs — multiple `## Track:`s branched off the common base, so a
  spec can have several independent increment branches rather than one linear chain. The
  `1 : 1 : N` count, the `**Source:**` join, and the `Spec:` PR trailer are unaffected, and this
  adds **no** new phase-enum value; a blocked/partial overnight run is visible via its
  `.woostack/overnight/` report.

## Phase enum (spec frontmatter `status:`)

`draft -> hardened -> approved -> planning -> executing -> in-review -> done`,
plus the terminal `abandoned`. The build loop authors every transition; the board
displays the authored value for head states and computes the execute/review/done
band from artifacts (truth table below).

| phase | meaning | authored at build step |
|---|---|---|
| draft | spec written, not hardened | 2 |
| hardened | grilled, awaiting approval gate | 3 |
| approved | gate cleared, no plan yet | 3 |
| planning | plan exists, 0 boxes done | 4 |
| executing | branch + commits, plan partial | 9 (execute) |
| in-review | an increment PR is open | 9 (execute) |
| done | plan 100% + all PRs merged, or trusted legacy authored `done` with no active branch commits/PR | post-merge |
| abandoned | shelved (terminal, hidden) | manual |

## Truth table (execute -> review -> done band)

- any increment PR open -> `in-review`
- plan partial, no open PR, branch has commits -> `executing`
- plan 100% + all increment PRs merged + >=1 merged -> `done`
- authored `done` + plan 100% + no discovered increment PR + no active branch commits -> `done`
  (trusts an explicit terminal assertion for legacy/untrailered features whose PRs can't be
  discovered)

A disagreeing authored value in this band is a FLAG, not displayed truth.

## Reconcile flags

0 or >=2 plans for a spec; `branch:` empty/`unknown` at phase >= executing;
unknown `status:` value; head-state phase while a PR already exists; executing
spec older than `status.staleDays` (config, default 14); two in-flight specs on
the same branch.
