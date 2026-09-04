---
tier: standard
---

# Angle: Database

**Scope.** Find database correctness, migration safety, performance, and access-control issues
introduced by this PR's diff. Read `/tmp/pr-review/diff.txt`. Apply only this embedded,
technology-neutral rubric.

**Find (diff-bound):**

- **Correctness and integrity:** missing keys or constraints that permit invalid or orphaned data;
  schema/application mismatches; nullability, uniqueness, or relationship assumptions not enforced
  where concurrent writers can violate them.
- **Migration and data loss:** destructive drops, renames, truncations, or type changes without a
  safe transition; backfills that can leave mixed states; non-repeatable migration steps where the
  repository expects retries; application/schema rollout ordering that breaks old or new processes.
- **Transactions and concurrency:** read-modify-write races; inconsistent lock ordering; transactions
  that span network or other unbounded side effects; queue/claim logic that can double-process,
  starve, or deadlock; partial writes where the operation requires atomicity.
- **Indexes and queries:** missing indexes for new joins, foreign keys, filters, or ordering on
  growing data; redundant indexes; N+1 access; unbounded reads; row-by-row writes where batching is
  required; queries whose concrete shape defeats an existing index or causes avoidable full scans.
- **Access control:** new tables, queries, views, procedures, or data-access paths that bypass the
  repository's authorization boundary, grant broader privileges than required, or expose another
  tenant's or user's records.

**Skip:**

- SQL style and formatting.
- Pre-existing schema issues not introduced by this PR.
- Performance speculation without a concrete query shape, missing index, cardinality, or growth
  signal.
- Suggestions that contradict an explicit, safe in-diff design choice such as deliberate
  denormalization.
- Engine-specific tuning advice not established by repository-owned conventions or changed code.

**Severity rubric:**

- `HIGH` + `blocking: true` — concrete unauthorized access, data loss, broken rollout, duplicate
  processing, deadlock, or integrity failure on a realistic path.
- `MEDIUM` + `blocking: false` — a concrete growth or concurrency defect whose impact is delayed or
  bounded, such as a missing index or transaction spanning an external side effect.
- `LOW` + `blocking: false` — a grounded hardening improvement with a named query, constraint,
  transaction, or access boundary.

**Output.** Write findings as a JSON array to `/tmp/pr-review/findings.database.json` using the
schema in `_worker-header.md`. Each finding gets `"angle": "database"` and MUST populate `title`
(bold headline ≤60 chars), `description` (issue + concrete impact path, no fix), `fix` (mitigation
in prose), and `fix_type`. Set `fix_type: "suggestion"` only when a ≤10-line single-file drop-in SQL
or code replacement at `line` is safe — and populate `suggestion` accordingly. Otherwise set
`fix_type: "prose"` with `suggestion: null`. See `_worker-header.md` for the full rule.

