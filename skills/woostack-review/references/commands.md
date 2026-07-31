# woostack-review commands

## Commands

- `/woostack-review [--issue <Linear issue URL|UUID>] [--project <Linear project URL|UUID>]` —
  Auto-detect an open PR from the current branch; without one, review the local diff. Explicit
  Linear context is local-host only and must pass the MCP gates below.
- `/woostack-review <PR#> [--issue <Linear issue URL|UUID>] [--project <Linear project URL|UUID>]`
  — Fetch that exact PR via `gh`, run the swarm, and post one native batched GitHub Review. When
  explicit IDs and an exact PR suffix are both present, every identity must agree.
- `/woostack-review --fast`, `/woostack-review fast` — One-run fast-tier override for the whole review (`FORCE_TIER = fast`).
- `/woostack-review --deep`, `/woostack-review deep` — One-run deep-tier override for the whole review (`FORCE_TIER = deep`).
- `/woostack-review --full` (or `@review --full` in a PR comment) — Force a complete re-review even when a prior SHA marker exists. Skips the incremental path described below.
- `woostack-review install` — Verify local deps (`gh`, `jq`, `node`) and pre-fetch `impeccable` + `react-doctor` (run once per repo).
- `woostack-review status` — Show the current PR's review status.

Once a local invocation resolves a PR number, retain that same PR through PR-mode reporting and
posting; do not fetch neighboring PRs from its stack. Review remains report-only: it prepares at
most one native review and never applies code fixes.

## Optional contract and Linear artifact context

A local review may use the active caller-approved goal, fix contract, specification, plan, or
acceptance criteria without any Linear artifact. The parent controller writes only that bounded
contract into `intent.md`; it never reconstructs scope from a branch, commit, PR title/body,
changed paths, recent activity, or current user.

Linear enriches that contract only when the caller supplies an exact issue/project URL or stable
UUID. An issue key, title, branch, changed path, PR trailer, recent item, fuzzy match, or current
user is not identity and never triggers discovery. Load the
[optional artifact contract](../../woostack-init/references/artifact-backends.md), discover official
host-exposed MCP read capabilities, resolve only the supplied resource, and independently read the
requested specification/fix/plan fields. Verify canonical repository association when claimed and
fully paginate relevant fields.

Missing MCP, authentication, complete pagination, unambiguous identity, or usable content omits
only the Linear contribution and continues with active-contract or diff-only advisory review unless
the caller explicitly required artifact-backed review. A PR requires no Linear trailer or artifact.

GitHub Actions cannot take these flags and has no parent conversation or Linear MCP channel. Its
comment triggers below always produce diff-only advisory evidence, even when the PR body contains
exact trailers. A later authenticated controller may reconcile optional artifact receipts.
Neither path accepts the work; the active workflow and responsible controller retain that authority.

### PR-comment triggers (issue #19)

When the companion GitHub Action is installed, the following comment commands re-trigger the review without leaving the PR:

| Comment | Effect |
|---|---|
| `/woostack-review` | Full re-review (sets `incremental=off`). Equivalent to `@review --full`. |
| `/woostack-review recheck` | Incremental review of new commits since the last marker. Same path as a `synchronize` event. |
| `/woostack-review force` | Bypass auto-skip (see *Auto-skip* below). Combinable: `/woostack-review force recheck`. |
| `/woostack-review --fast` / `/woostack-review fast` | Force a one-run fast-tier execution for this run. |
| `/woostack-review --deep` / `/woostack-review deep` | Force a one-run deep-tier execution for this run. |

The legacy `@review` trigger phrase still works; `/woostack-review` is an alias the example workflow's `issue_comment` `if:` recognizes.

### Auto-skip (bot PRs + release rollups)

`prefetch.sh` short-circuits the review with a single one-line PR comment when either condition holds (before fetching the diff, so token cost is ~zero):

- **PR author matches `authors_skip`.** Default list: `dependabot[bot]`, `renovate[bot]`, `github-actions[bot]`. Override with `review.authors_skip` in `.woostack/config.json`; explicit `"review": { "authors_skip": [] }` opts out entirely.
- **PR title matches `release_rollup_pattern`** (Python regex). Default: `^(staging|release|chore\(release\))`. Override with any string; explicit empty string opts out.

The skip comment carries a `<!-- woostack-review:skipped -->` marker; subsequent triggers on the same PR detect the marker and re-skip silently (no comment spam). To force a full review of a skipped PR, post `/woostack-review force`.

## Incremental Mode

By default (`incremental: auto` on the GitHub Action), every posted review carries a hidden watermark:

```
<!-- woostack-review:sha=<headRefOid> -->
```
On the next run, `prefetch.sh` (via `resolve-marker.sh`) scans **bot-authored** prior review bodies (the same `BOT_NAME_PATTERN` used elsewhere) for the marker — and, **on a local (not-in-CI) run, also a marker authored by the gh user running the review** (`gh api user`, matched case-insensitively). A CI collaborator cannot forge a marker (the self-trust clause is dead in CI, so only bots are honored), and a *different* local reviewer or any CI third-party still falls back to a full pass. This lets a local re-review trust the marker it wrote on the previous run instead of always re-reviewing in full. If a trusted marker is found, prefetch diffs `<last_sha>...HEAD` via the GitHub compare API instead of the full PR diff — only the new commits since the last pass are reviewed. Unresolved prior review threads (any author) are dumped to `$OUTDIR/prior-findings.json` and consumed by the posting stage as an **event floor**: any non-empty priors list keeps the new review at minimum `REQUEST_CHANGES`, a conservative gate so a stale open thread is never auto-resolved by a clean incremental pass.

Override paths:
- Action input `incremental: off` (workflow-level opt-out).
- A trigger comment containing `--full` (e.g. `@review --full`) — fixed-string match, regex-injection safe.
- Force-push that drops `<last_sha>` from the branch history — the compare API returns 404; prefetch emits a `::warning::` and falls back to the full diff for that run.

When the incremental diff has no new commits (i.e. `LAST_SHA == HEAD_SHA`, e.g. someone re-triggers without pushing), prefetch emits `skip=true` with reason `no new commits since last review (<last_sha>)`. Because a local run now trusts its own marker, this skip also fires on a **local** re-review with no new pushes (previously a local re-run always reviewed in full). To force a re-review of the same SHA, pass `--full` (or set `incremental: off`).

Marker semantics are state-light: the marker IS the state. There is no DB or workflow artifact retention beyond what GitHub already keeps in review history.

## Stack-aware review (`review.defer_markers`, issue #224)

woostack encourages PR-sized **stacked** increments, so an early increment often *intentionally*
defers integration to a later one. Reviewing the isolated diff would flag that deferred work as
"missing" — noise that trains authors to ignore the review gate.

Rather than fetch the other PRs in the stack to verify the deferral, woostack declares it inline.
When `woostack-execute` runs an increment that defers work, it writes a **deferral marker** at the named site in the file's comment syntax —
`woostack-defer(increment N): <reason>` — and the later increment removes it when it
wires the work (both steps are authored by [`woostack-plan`](../../woostack-plan/SKILL.md)). The marker
lives in the PR's own diff.

When `review.defer_markers` is `true` (the default), the **defender validator** scans the diff for
these markers; for a finding that asserts something is *missing / not-yet-wired / presented-before-
it-lands*, it checks whether a marker covers that gap. If so it sets `deferred_to: "<ref>"`;
`intersect-findings.sh` then forces the finding to a non-blocking **`Deferred to <ref>` nit**
(visible, auditable, event-neutral → `APPROVE`), independent of `severity_floor`. Guards: `security`
findings are never deferred; a finding about wrong code *present in this PR* is never deferred; a
bare `TODO` is never honored (only the `woostack-defer` token). Set `review.defer_markers: false`
to turn the feature off. Because the signal is in the diff already, the review fetches **no other
PRs** — the cost of declaring intent is paid once, upstream, at plan/execute time.
