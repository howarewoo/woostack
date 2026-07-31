# Linear development-record migration

This is the one-way, loss-safe procedure for retiring local `.woostack/specs/`, `plans/`, `fixes/`, and `overnight/` development records after Linear becomes authoritative. Migration is explicit: `/woostack-init --migrate`. Ordinary init and doctor only report the blocker.

## Safety invariant

No local development-record file is deleted until every record is classified, every active record has complete verified remote receipts, every affected memory or wisdom provenance value has a verified replacement, and the resulting repository changes are recoverable from Git. Any missing, malformed, partial, ambiguous, foreign, or conflicting evidence produces `localDeletions: []` for the whole run.

Migration never matches a remote resource by title and never treats a transport success as a receipt. It never imports historical records merely to remove local files.

## Inventory and classification

Inventory every non-sentinel file under `.woostack/specs/`, `plans/`, `fixes/`, and `overnight/` without changing it. Record its repository-relative path, Git blob ID, content digest, frontmatter identity, branch, PR references, and inbound memory or wisdom provenance.

Classify each joined record set as exactly one of:

- **active** — unfinished work with a current branch, open PR, or other verified execution evidence;
- **historical** — Git retains the exact blob and verified merged-PR plus acceptance evidence proves the work is complete;
- **ambiguous** — malformed joins, conflicting lifecycle evidence, closed work without acceptance, duplicate ownership, or any unresolved classification;
- **partial** — a prior migration created some remote identities but lacks a complete receipt set or provenance rewrite;
- **foreign** — a candidate remote resource fails the managed identity tuple, repository, workspace, team, or role check.

Historical records remain recoverable from Git and are not imported. Ambiguous and foreign records require explicit human classification or ownership repair before another run.

## Active-resource mapping and resume

Generate each managed client UUID before the first Linear mutation and persist it in the migration receipt. Map an active multi-PR feature to one managed feature project and ordered increment issues; map a bounded fix or change to one work-item issue. Preserve dependencies, acceptance criteria, branch and PR identity, and the original local paths.

After an unknown outcome or interrupted run, search only for the embedded client UUID, then verify the complete managed identity tuple and native relations. Resume with the exact verified project, issue, update, comment, and relation IDs already recorded. Zero or multiple ownership-valid matches blocks; never create a replacement or fall back to a title match.

## Receipt and provenance checkpoint

Aggregate one migration receipt containing:

- the inventory and classification for every local record set;
- original Git blob IDs and PR recovery evidence;
- every stable client UUID and verified native remote ID;
- independent read-back of managed metadata, repository, workspace, team, role, state, owner, and relations;
- the old and proposed new provenance for every affected memory or wisdom note; and
- `localDeletions`, which remains empty until all gates below pass.

Rewrite provenance only to the most specific verified `linear://project/<uuid>` or `linear://issue/<uuid>` identity. Preserve the original provenance in the receipt. Stage and verify all provenance rewrites together; an unresolved or foreign target blocks every deletion.

## Deletion gate and verification

Local deletion is all-or-nothing. It may proceed only when:

1. every record is active with complete remote receipts or historical with exact Git and merge/acceptance recovery proof;
2. no record is ambiguous, partial, or foreign;
3. every active resource and relation passes an independent MCP read-back;
4. every provenance rewrite resolves to the verified managed resource; and
5. the pre-delete receipt is durable and the original blobs are recoverable from Git.

Delete only the inventoried record files, never memory, wisdom, diagnostics, or sentinel files. Re-run inventory, provenance validation, and doctor afterward. The final handback names the receipt, exact remote identities, deleted paths, retained paths, and residual blockers. A failed post-delete check restores the files from their recorded Git blobs before reporting failure.
