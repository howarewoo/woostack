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
  `Spec: .woostack/specs/<file>.md` (written by woostack-commit). The board finds
  increment PRs with `gh pr list --state all --search "Spec: <path>"`.
- `spec.branch:` names the active increment's branch.

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
| executing | branch + commits, plan partial | 6 |
| in-review | an increment PR is open | 8 |
| done | plan 100% + all PRs merged | post-merge |
| abandoned | shelved (terminal, hidden) | manual |

## Truth table (execute -> review -> done band)

- any increment PR open -> `in-review`
- plan partial, no open PR, branch has commits -> `executing`
- plan 100% + all increment PRs merged + >=1 merged -> `done`

A disagreeing authored value in this band is a FLAG, not displayed truth.

## Reconcile flags

0 or >=2 plans for a spec; `branch:` empty/`unknown` at phase >= executing;
unknown `status:` value; head-state phase while a PR already exists; executing
spec older than `status.staleDays` (config, default 14); two in-flight specs on
the same branch.
