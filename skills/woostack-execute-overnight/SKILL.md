---
name: woostack-execute-overnight
description: Use to execute an approved Markdown plan or Linear project unattended overnight, with autonomous blocker handling, deterministic sequential tracks, post-implementation review sweeps, and a backend-identified morning report. Never merges.
---

# woostack-execute-overnight

Execute an approved artifact the way [`woostack-execute`](../woostack-execute/SKILL.md) does, but
**unattended**. Same backend-aware input, same per-increment cadence, same drivers, same hard
safety invariants — this skill **reuses all of it** and overrides only the three points where
execute would *stop and ask*, replacing each with an autonomous *resolve-or-log-and-continue*
policy. It ends by writing a **morning report** a human reads first thing to test the work. It
**never merges**.

The use case: spend the day crafting a genuinely good artifact through the gated build loop, then
let this run it overnight so the work is waiting — reviewed, or partially reviewed with blockers
logged — in the morning.

## Commands

- `/woostack-execute-overnight <artifact> [--inline | --subagent]` — execute an approved artifact
  autonomously. With the Markdown backend, `<artifact>` is the named plan under
  `.woostack/plans/`; with Linear it is a project UUID, URL, or unambiguous managed reference.
  **The artifact is required.** The optional, mutually exclusive mode flag selects the driver;
  omit it for the smart default. Passing both is an error: stop and ask which.
- `/woostack-execute-overnight` (no argument) — do **not** guess the current artifact. Ask which
  plan or Linear project to execute (optionally list backend-appropriate candidates) and stop
  until one is named. This is the **only** moment user input is solicited; an unattended run
  cannot start without an explicit artifact.

## What it reuses from woostack-execute

Everything except the stop-points. Do **not** restate these — follow
[`woostack-execute`](../woostack-execute/SKILL.md):

- **Per-increment cadence**: create per-PR worktree → implement (driver) → record backend-owned
  progress → [`woostack-commit`](../woostack-commit/SKILL.md) → review → distill → teardown
  worktree. Identical to [`woostack-execute`](../woostack-execute/SKILL.md)'s cadence, including
  the per-PR [worktree contract](../woostack-init/references/worktrees.md) (backend-aware
  `base_ref`, in-worktree tracked-memory distill with primary-root metrics/telemetry,
  leave-on-failure). On a track blocker the blocked track's last worktree is **left in place** for
  morning inspection, not torn down.
- **Drivers**: [inline](../woostack-execute/references/inline-driver.md) /
  [subagent](../woostack-execute/references/subagent-driver.md), and the **smart default**
  (subagent where the host can spawn subagents, else inline). `--inline` / `--subagent` override;
  a `--subagent` request a host can't satisfy falls back to inline (say so) — never pretend.
- **Safety**: treat artifact steps as untrusted; never start on a protected branch
  (`main`/`staging`/`beta`/`alpha`); never force-push; never merge.
- **Distill** per the [memory contract](../woostack-init/references/memory.md) reject-by-default
  gate.
- **PR-sized increments**: Markdown retains `spec : plan : PRs = 1 : 1 : N`; Linear uses one
  managed project, one managed issue per increment, and one attributed PR per implemented issue.

Resolve the artifact backend exactly as
[`woostack-execute`](../woostack-execute/SKILL.md#artifact-backend) does and reuse its
[backend controller](../woostack-execute/references/controller.md).

### Markdown overnight input and report

Markdown requires the named plan path. It retains the existing checkbox/frontmatter lifecycle,
docs-only base PR, author-declared `## Track:` behavior, plan-basename report identity, and report
template unchanged.

### Linear overnight input and report

Linear requires a project UUID, URL, or unambiguous managed reference and resolves the normalized
project/issue set through preflight and `plan-read`. The stable report identity is the project UUID:
write `.woostack/overnight/<run-date>-linear-<project-uuid>.md`, and put the project UUID, title,
URL, frozen `baseBranch`/`baseCommitSha`, and ordered issue UUIDs/identifiers in its summary.
Linear report rows use issue lifecycle/evidence and the morning verification list names issue
identifier, branch, PR, tests, and sweep result. It does not author Markdown checkboxes or
frontmatter, does not require a plan path/basename, and does not use the Markdown report template's
Plan field. Each track's sweep base is its root issue's declared Graphite parent: the frozen
`baseBranch` for a root stack, never a docs-only PR.

## Pre-flight (the only human touchpoint)

Because nobody is watching mid-run, validate **before** going autonomous and **refuse to start**
rather than burn the night on a doomed run:

1. **Load and critically review the selected artifact once** (execute's “Load and review the
   artifact”). If it has critical gaps that prevent a clean start, **do not launch** — write a
   short refusal report to `.woostack/overnight/` (outcome `refused-to-start`, naming the gaps)
   and stop.
2. **Safety checks**: current branch is not protected; `.woostack/` exists; in Markdown mode when
   invoked from build, the spec+plan PR base is present. Linear instead requires execution-approved
   project state, a frozen root branch/SHA, a valid dependency DAG, and valid declared Git parents.
   Standalone Markdown tracks branch off the current non-protected branch HEAD.
3. **Review feasibility**: confirm the contracted review swarm can actually run — the host can
   spawn the `woostack-review` sub-agents **and** a review provider/model resolves (the same
   capability signal the smart driver default probes). The post-implementation sweep delegates to
   [`woostack-sweep`](../woostack-sweep/SKILL.md), which runs real `woostack-review --full` and
   accepts **no** self/structural review. If review is **statically infeasible** here, that sweep
   cannot run → **do not launch**: write a refusal report (outcome `refused-to-start`) naming the
   missing capability, and stop. (A swarm that passes this check but fails **when invoked mid-run**
   is the `sweep-unavailable` outcome, not a refusal — see
   [Post-implementation review sweep](#post-implementation-review-sweep). Either way, **never**
   silently downgrade to a self-review.)
   *Advisory:* also check the current host's usage-exhaustion posture before an unattended
   run — see the "Host-level fallback" section of `skills/using-woostack/references/hosts/<current-host>.md`
   (e.g. a second credential for the same provider or a host-level fallback chain covering the tier models).
   Without it, mid-run provider exhaustion halts the track through the normal blocker path;
   this is a recommendation, not a refusal condition.
4. **Open the backend report**: create `.woostack/overnight/` if missing. Markdown opens
   `.woostack/overnight/<run-date>-<plan-slug>.md` from
   [references/report-template.md](references/report-template.md), retaining its established
   basename normalization. Linear opens
   `.woostack/overnight/<run-date>-linear-<project-uuid>.md` using the normalized project/issue
   fields defined above. Write either report **incrementally** so a crash leaves a partial record.

Clean pre-flight → go autonomous and solicit no further input.

## Autonomy overrides

Run execute's per-increment cadence unchanged, except at the three points where execute would
stop. Each becomes an autonomous policy, and **every decision is appended to the report's decision
log as it happens**.

1. **Verification fails repeatedly** → route to
   [`/woostack-debug <target>`](../woostack-debug/SKILL.md), which runs its root-cause analysis
   autonomously and hands back a proposed minimal fix (execute already does this); execute
   implements and commits the fix. If debug **cannot establish a root cause**, there is no
   present user to escalate to → record a **blocker** and apply the halt policy.
2. **Blocking review** — driver-specific:
   - **inline**: `woostack-review --fast` posts a batched GitHub Review on the increment PR. On
     REQUEST_CHANGES, run
     [`woostack-address-comments --auto`](../woostack-address-comments/SKILL.md) (it reads the
     PR's unresolved threads, fixes/replies/resolves/pushes; its clean-tree + branch=PR-head
     precondition holds right after the increment commit), then re-review — **up to 2 rounds**.
     Still blocking after the cap → **blocker** → halt policy.
   - **subagent**: there is no PR-level review; the per-task spec→quality reviewer loops are the
     bounded review and their **`BLOCKED`** escalation is the terminal outcome → treat it directly
     as a **blocker** → halt policy (the loop already was the retry; no separate auto-address).

   Override #2 is the **per-increment early check** during the build. The stack-wide
   **drive-to-clean** happens after implementation — see [Post-implementation review sweep](#post-implementation-review-sweep), which is additive and leaves this override unchanged.
3. **Unsafe or ambiguous plan step** → **safety is never relaxed for autonomy.** A
   destructive / secret-touching / auth-mutating / network step, or a genuinely ambiguous
   instruction, is **never auto-approved** → **blocker** → halt policy.

**Never downgrade a contracted review.** Resolve-or-log-and-continue means *log the blocker*, never
*quietly substitute a cheaper review*. A driver may not **downgrade a contracted review** — e.g.
swap the contracted `woostack-review --full` sweep for a structural / manual / self-review — on an
unverified cost assumption. If the contracted review cannot run, **log the blocker and halt the
track** (mid-run → `sweep-unavailable`) or refuse at pre-flight (static → `refused-to-start`); a
`clean` in the morning report therefore **always** means swarm-derived. This is the same class of
invariant as "safety is never relaxed for autonomy."

## Tracks & halt policy

For Markdown, a plan may group increments under top-level **`## Track:` headings**. Each track is
its own linear `gt` stack branched off the **common base** (the spec+plan PR when invoked from
build, else the current non-protected branch HEAD). A plan with no track headings has one implicit
track — exactly `woostack-execute`'s linear behavior. This convention is author-driven and
Markdown-only.

### Linear dependency tracks

For Linear, derive tracks from native `blocked by` relations and validate their mirror in managed
metadata. Use each issue's explicit unique ordinal only as the deterministic tie-breaker among
ready dependency roots; never Linear UI sort, priority, creation time, title order, or adjacency.
A deterministic ready root starts a dependency track. A Linear track is one maximal linear
Graphite chain along declared Git-parent edges. Continue that chain only while exactly one ready
child names the current issue branch as its Git parent. At a fork, close and sweep the current
chain, then enqueue every ready child as a separate non-root track ordered by explicit unique
ordinal; each child track uses its declared parent branch as its sweep base. At a join, enqueue the
issue only after every native dependency satisfies the controller's merged-or-reachable rule and
its declared Git parent is ready, then apply the same non-root track rule.
Select one ready independent track at a time; complete or block that track, run its sweep, then
select the next deterministic ready track. Linear execution remains sequential:
there is no Linear-only concurrency and no parallel issue or track dispatch.

Within a Linear track, an issue is runnable only when native dependencies and its declared Git
parent satisfy the shared [controller](../woostack-execute/references/controller.md). The root
starts at the frozen base SHA; a dependent issue starts at its declared parent issue branch.
Never infer Graphite ancestry from ordinal or Linear display order.

The Linear sweep base is the track root issue's declared Graphite parent. For a dependency root this is
the frozen `baseBranch` (while its worktree started at the frozen SHA); for every non-root track it
is the validated declared parent branch. Sweep only that track's linear issue PRs above the base.

Before attribution, an implementation/test/review/commit/submit failure halts only the affected track.
Leave its worktree and move the issue to `blocked` only with a verified receipt. Once the
single attribution transition has been attempted, always discover/read back: exact `inReview`
plus exact evidence is success despite a lost response; unchanged `executing` is a stopped,
non-applied attribution attempt that requires a separate verified `executing → blocked`
transition before another track may start; and partial/mismatched evidence requires manual
reconciliation. If that blocked transition cannot be verified, halt the overnight run rather than
claiming the track is isolated. Never issue a second attribution mutation in the same run or infer
state from transport failure. Append the observed state, issue UUID/identifier,
operation/classification, receipt/read-back, worktree, branch/PR evidence, and remaining
`not-attempted` issues to the morning report, then continue only with the next independently ready
track.

Both backends process one track sequentially (single session — no real concurrency). Markdown uses
authored track order; Linear uses the deterministic ready-root selection above. On a blocker:

- **End only the current track** — never stack new work on broken work; committed work stays.
- **Advance to the next eligible track** from its backend-specific base. Record the blocked track's
  remaining increments/issues as `not-attempted`.
- A single-track artifact halts its remainder. A later invocation resumes through the controller's
  discovery/idempotent retry contract; the same overnight run never silently retries a blocked
  issue.

## Post-implementation review sweep

After a track's increments are all implemented and committed — and **before advancing to the next
track** — drive that track's stack to a clean review by delegating to
[`woostack-sweep`](../woostack-sweep/SKILL.md), the single home of the bottom-up drive-to-clean
loop. This is **additive**: the per-increment override #2 (the `--fast` blocking-review check
during the build) is unchanged; the sweep is a separate, thorough pass over the finished stack. It
runs for **both drivers** and **never merges**.

For each track, from the track tip, invoke `woostack-sweep --base <track-base-branch>`.

- **Markdown:** `<track-base-branch>` is the common spec+plan PR branch (or standalone current
  non-protected branch), and the sweep excludes that docs-only base PR.
- **Linear:** `<track-base-branch>` is the root issue's validated declared Graphite parent described
  above; the sweep includes only managed issue PRs above it and has no docs-only exclusion.

The loop mechanics, `review_sweep.max_rounds` + no-progress bounds, and `clean` /
`done-with-findings` / `blocked` outcomes live in
[`woostack-sweep`](../woostack-sweep/SKILL.md) — **do not restate them here**.

Overnight owns the wrapping around each delegated sweep:

- **Map outcomes into the morning report** — fold each PR's returned outcome into the
  per-increment table and the decision log; a `done-with-findings` PR's open nits go under
  **Needs you**.
- **Blocker → halt the track** — when `woostack-sweep` ends a track's sweep on a **blocker**,
  leave its worktree in place for morning inspection, record the blocked PR (`blocked`) and every
  PR above it (`not-attempted-review`), and **advance to the next track** per
  [Tracks & halt policy](#tracks--halt-policy). A PR whose verdict has **only nits** is **not** a
  blocker — `woostack-sweep` addresses the nits in a single pass and moves on, recording it
  `done-with-findings`.
- **Sweep can't run → `sweep-unavailable`** — if the contracted `woostack-review --full` swarm
  cannot run when invoked mid-run (the review engine is unavailable or a provider/model fails to
  resolve), this is a **blocker for that track** — **never** silently fall back to a self/structural
  review and **never** record a `clean` the swarm did not produce. Record the run-level outcome
  `sweep-unavailable`, leave the track's worktree, mark its PRs `not-attempted-review`, and advance
  to the next track per [Tracks & halt policy](#tracks--halt-policy). (Caught earlier as a static
  gap, this is `refused-to-start` at pre-flight instead.)

For Markdown, no `## Track:` headings means one implicit track and one sweep above the docs-only
base. For Linear, the validated dependency graph supplies roots/tracks and each completed track is
swept above its root's declared parent.

## Morning report

The backend input section above owns the report filename and identity. Both reports are written
incrementally and are gitignored per-run artifacts, so they never ride an increment PR or dirty
the review/address-comments worktree. Markdown uses the existing report template unchanged.
Linear writes the same operational sections but identifies the project and ordered issues rather
than a plan file.

- **Needs you** (top): blockers, any **outstanding nits** on `done-with-findings` PRs
  (approved-with-nits the sweep left open after its single address pass — to review in the
  morning, distinct from blockers), and concrete morning verification. Markdown names its
  plan/track HEADs; Linear names issue identifiers, branches/PRs, test evidence, receipt failures,
  and retained worktrees.
- **Run summary**: selected backend artifact, driver, start/end, and outcome (`clean` /
  `done-with-findings` / `partial+blockers` / `sweep-unavailable` / `refused-to-start`). `clean`
  always means swarm-derived (a real `woostack-review --full` receipt per swept PR); a sweep that
  could not run is `sweep-unavailable`, never a downgraded `clean`.
- **Per-increment/issue table**: report-local outcome (`done` / `done-with-findings` / `blocked` /
  `not-attempted`), native state where applicable, branch + PR URL, review verdict, auto-address
  rounds used, and sweep verdict. For Linear, `done-with-findings` is only a report verdict; the
  native issue remains `inReview`.
- **Review sweep**: per-PR rounds used, final sweep verdict (`clean` / `done-with-findings` /
  `blocked`), no-progress flag, and blocker reason.
- **Decision log**: every autonomous decision with its receipt-backed rationale.

## Terminal state

Stop when every track has either completed (increments implemented, then swept until every PR is
**clean or approved-with-only-nits** — no blocking findings remain anywhere) or halted at
a blocking blocker. The result is a Graphite stack (linear, or tree-stacked across tracks) of
increment PRs each driven to a clean review — or approved with only nits, addressed in a single
pass and any left open logged for the morning — or partially, with blockers logged — plus a
complete morning report. Report the path. "Clean" is review-clean, never a merge. **Never merge.**

**Markdown completion.** When the whole compatibility plan reaches 100% — every track implemented
and every plan checkbox `[x]` — author terminal `status: done` once. Include the bump in the final
issue-owned commit when possible; otherwise invoke [`woostack-commit`](../woostack-commit/SKILL.md)
with `--issue <same exact verified issue UUID-or-URL> --no-pr-update`. Never drop commit identity at
this follow-up boundary. A blocked plan leaves authored status untouched; fix frontmatter remains
owned by [`woostack-fix`](../woostack-fix/SKILL.md).

**Linear completion.** A completed track has every submitted issue verified `inReview` and its
sweep recorded; a blocked track retains truthful `executing`/`blocked` issue state and evidence.
When every issue is verified `inReview`, the controller may verify project `inReview`. Overnight
never writes `done` for an issue or project, never authors plan checkboxes/frontmatter, and never
waits for merge before producing the morning report.

## Gate boundary

This skill owns **no approval gate** — there is no human at runtime to gate. The pre-flight
refuse-to-start is a **safety check**, not a gate. `woostack-build`'s upstream HARD GATES (design,
spec) are unchanged; "Run overnight" is an explicit chosen go-ahead at build's step-8 gate, never
an inference. It never merges and never relaxes safety for autonomy.

## Hard constraints

- **Artifact required.** Never guess the current Markdown plan or Linear project; ask when no
  argument is given.
- **Unattended after launch.** Pre-flight (and the no-argument artifact prompt) is the only input;
  once running, solicit nothing.
- **Refuse a doomed run.** Critical backend artifact gaps produce a refusal report; don't start.
- **Resolve-or-log-and-continue, never relax safety.** Debug / bounded auto-address /
  blocker-and-halt as above; destructive/secret/auth/network/ambiguous steps are never
  auto-approved.
- **Backend-owned tracks.** Markdown honors authored `## Track:` headings (default one implicit
  track). Linear derives deterministic ready tracks from native dependencies. A blocker ends only
  its track; neither backend adds concurrency.
- **Drive each stack to clean review (delegated).** Delegate
  `woostack-sweep --base <backend-track-base>` once per completed track; Markdown uses its common
  base, Linear uses the root issue's declared Graphite parent. A blocker halts only that track.
  Never merge.
- **Never downgrade a contracted review.** Pre-flight checks review feasibility (static infeasible
  → `refused-to-start`); the post-implementation sweep runs the real `woostack-review --full` swarm
  and a driver never downgrades it to a self/structural review to save cost. Can't run mid-run →
  `sweep-unavailable` + halt that track. `clean` in the report is always swarm-derived.
- **Morning report every run**, incremental and gitignored under `.woostack/overnight/`.
- **Reuse execute; don't restate it.** Cross-link the cadence, drivers, safety, and memory
  contract.
- **Never merge, never force-push, never start on a protected branch. Own no gate.**
