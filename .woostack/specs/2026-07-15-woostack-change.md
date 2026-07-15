---
name: woostack-change
type: spec
status: approved
date: 2026-07-15
branch: feature/woostack-change
links:
---

# `/woostack-change` — Design Spec

> Artifact: `.woostack/specs/2026-07-15-woostack-change.md`. This Markdown file is the source of truth. Render with the build skill's `spec-template.html` only as a presentation target.

> `status:` follows the owning-artifact contract in [`skills/woostack-status/references/conventions.md`](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-15-woostack-change]]

## 1. Problem

The user explicitly requested a public skill for quick, small changes that are not fixes and should not require the full build loop. The current routing surface offers `/woostack-build` for features and `/woostack-fix` for bugs, hotfixes, refactors, and enhancements. `/woostack-fix` requires diagnosis and a persisted fix plan even when there is no fault to diagnose; `/woostack-build` requires design, separate spec and plan artifacts, three gates, and a stacked PR shape. Neither is a good semantic or procedural fit for a bounded non-bug change that can ship as one reviewable PR.

The repository's own command documentation confirms this gap: `README.md` currently permits code changes only through bootstrap, build, or fix, while the routing table has no direct, gate-free one-PR authoring command for non-bug enhancements.

## 2. Goal

Add `/woostack-change <goal>` as a public skill for non-bug enhancements and refactors that can be understood, implemented, verified, reviewed, and shipped in one reviewable PR without a persisted spec or plan and without an approval gate.

The command must remain safe despite being quick: isolate writes in a dedicated worktree, state intent before editing, follow the canonical TDD or concrete-verification rule, smoke-test the changed path, perform task-scoped inline compliance and quality review, submit one PR, and tear down only after verified closeout.

## 3. Non-goals

- Replacing `/woostack-fix` for bugs, regressions, production faults, or work requiring root-cause diagnosis.
- Replacing `/woostack-bootstrap` for greenfield project creation.
- Replacing `/woostack-build` for work that needs multiple independently reviewable PRs.
- Creating `.woostack/changes/`, spec, plan, lifecycle, resume, or status-board artifacts.
- Adding an approval gate, a full review swarm, overnight execution, stacked increments, or merge behavior.
- Weakening validation, security, accessibility, error handling, or data-loss safeguards merely to keep the diff small.

## 4. Approach

Create `skills/woostack-change/SKILL.md` as a standalone public command with this fixed flow:

1. Inspect repository context and classify the request before any write.
2. Route bugs to `/woostack-fix`, greenfield work to `/woostack-bootstrap`, and work that cannot remain one reviewable PR to `/woostack-build`.
3. For qualifying work, resolve the base branch and create `change/<slug>` at `.woostack/worktrees/change-<slug>`, tracked in Graphite against the resolved base.
4. State a concise execution intent in the conversation; this is informative, not an approval stop.
5. Implement the bounded change in the worktree. New observable behavior follows the canonical [`woostack-tdd`](../../skills/woostack-tdd/SKILL.md) kernel; documentation, configuration, and no-runner work uses an exact concrete verification.
6. Smoke-test the changed path, then run task-scoped inline specification-compliance and code-quality checks against the current diff. Emit an explicit `PASS` or `BLOCKED` review receipt naming the reviewed diff state; resolve every blocking finding before closeout.
7. Invoke [`woostack-commit`](../../skills/woostack-commit/SKILL.md) to commit, push, and open or update the one PR.
8. Confirm the PR exists, then remove the worktree. Never merge.

If scope grows beyond one PR after work starts, or verification/review/commit/submit fails, stop truthfully and preserve the worktree. Report the blocker and exact worktree path; never silently downgrade checks or delete recoverable work.

## 5. Components & data flow

- **`skills/woostack-change/SKILL.md`** owns classification, worktree lifecycle, direct implementation, verification, inline review, commit delegation, and closeout.
- **`skills/using-woostack/SKILL.md`** routes explicit and intent-equivalent quick non-bug one-PR requests to the new skill.
- **Existing authorities** remain single-source and are linked rather than copied: update the consumer list and lifecycle examples in `skills/woostack-init/references/worktrees.md`; update `skills/woostack-commit/SKILL.md` so its branch-shape guard accepts the caller-created `change/*` worktree without creating another branch; then link worktree/base mechanics, TDD in `skills/woostack-tdd/SKILL.md`, commit/PR mechanics, and least-code guidance in bootstrap `patterns.md §10`.
- **Public-surface bookkeeping** updates every known reader identified by the repository's `lockstep-edit-sites` wisdom: `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `skills/using-woostack/SKILL.md`, and `skills/woostack-bootstrap/references/development.md`.
- **Authored docs-site framing** updates the getting-started workflow and worktree pages whose current claims exclude the new path. The per-skill reference page remains generated from `SKILL.md`.
- **Verification** structurally checks that the new skill exists, routing and public counts agree, required safety barriers are present, and the docs site builds.

Request data flows only through the conversation and Git worktree. No new persistent woostack artifact schema or status lifecycle is introduced.

## 6. Error handling

- Missing or ambiguous goal: ask one focused question before classification; do not guess the target.
- Bug/regression/incident evidence: stop this command before writes and route to `/woostack-fix`.
- Greenfield request: route to `/woostack-bootstrap`.
- Multi-PR scope identified before writes: route to `/woostack-build`.
- Scope expansion after writes: stop; preserve and report the worktree rather than forcing an oversized PR or silently splitting into unmanaged branches.
- Existing branch/worktree collision, dirty or unexpected worktree state, or base-resolution failure: stop before editing and report the conflict.
- Missing test runner: use a concrete command with an exact expected result; never claim TDD ran.
- Failed smoke test, verification, missing review receipt, or `BLOCKED` inline-review finding: do not submit or tear down; report evidence and the worktree path.
- Failed or unverified commit, push, or PR creation: preserve the worktree and report the failure. PR existence is required before teardown.
- No failure path may fall back to `/woostack-build` or `/woostack-fix` after implementation automatically; routing after writes requires an explicit handoff with preserved work.

## 7. Acceptance criteria

- **AC1 — Public command discovery and routing**
  - happy: installation/adoption docs and `using-woostack` expose `/woostack-change <goal>` and route intent-equivalent bounded non-bug one-PR work to it.
  - error: bug, greenfield, and multi-PR requests are explicitly rejected by this skill and routed to fix, bootstrap, and build respectively before writes.
  - edge: a request with ambiguous scope asks one focused question rather than selecting a workflow by assumption.
- **AC2 — Gate-free isolated execution**
  - happy: a qualifying change creates and uses `change/<slug>` in `.woostack/worktrees/change-<slug>`, states intent, and proceeds without an approval gate or persistent spec/plan/change artifact.
  - error: base, branch, worktree, or Graphite tracking failure stops before edits and preserves any recoverable state.
  - edge: scope that expands after editing stops with the worktree preserved and does not auto-create a stack.
- **AC3 — Verification and review safety**
  - happy: new behavior uses the TDD kernel; no-runner work names and executes a concrete verification; every run smoke-tests the changed path and records a task-scoped inline compliance and quality review receipt for the current diff.
  - error: failing verification or blocking review prevents submission and teardown and is reported with evidence.
  - edge: purely documentary/configuration work does not fabricate a test runner or meaningless failing test.
- **AC4 — One-PR closeout**
  - happy: `woostack-commit` commits and submits exactly one `change/<slug>` PR; verified PR existence permits worktree teardown; the handback includes PR URL and verification evidence.
  - error: commit, push, submission, or PR read-back failure leaves the worktree intact and reports its path.
  - edge: the skill never merges and never creates a second PR or lifecycle-only closeout commit.
- **AC5 — Public-surface lockstep**
  - happy: every public count/list/routing/adoption site and affected authored docs page includes the new command consistently.
  - error: a structural verification fails when the skill directory exists but a required public-surface site is missing or the count disagrees.
  - edge: internal `woostack-ideate`, `woostack-harden`, and unregistered `woostack-ask` remain outside the registered public count.

## 8. Testing

This repository has no application test runner. Use committed structural shell verification consistent with existing skill tests to pin the command's required routing, scope barriers, no-gate/no-artifact contract, one-PR closeout, worktree path, and public-surface count/list sites. Run `bash -n` on any added or changed shell test, execute that focused test, and run `pnpm -C site build` because authored documentation and generated per-skill references change.

Smoke-test command discovery by reading the installed skill metadata/routing surface exactly as a consumer would and confirming `/woostack-change` resolves to the new skill.

## 9. Open questions

None. The approved design fixed the command name, scope, no-gate policy, worktree and one-PR lifecycle, verification standard, inline review depth, failure preservation, and routing boundaries.
