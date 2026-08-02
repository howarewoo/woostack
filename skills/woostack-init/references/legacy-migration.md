# One-way legacy development-record migration

`/woostack-init --migrate-legacy` is the sole routed owner of migration from tracked
`.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, and `.woostack/overnight/`
development records. Normal init and doctor only preserve and report these files. No other skill
creates, imports, deletes, or claims authority from them.

The migration is one bounded operation over an explicitly enumerated related record set. Run it
only after init's official Linear MCP preflight and repository-ownership checks succeed. The host's
official MCP is the only remote transport. Linear is the durable destination for both active and
historical-completed development records; Git blobs and canonical merged-PR evidence remain
independent recovery and attribution evidence, never a substitute for a required historical
resource. Never use a repository adapter, token file, local development authority, or title match.

## 1. Freeze recoverable source bytes

1. Enumerate every tracked legacy file in the requested related set with `git ls-files`, including
   specifications, plans, fixes, and overnight handbacks. Reject symlinks, untracked files, path
   escapes, malformed records, and any set whose relationships cannot be resolved.
2. For each file record its repository-relative path, working-tree SHA-256, containing commit SHA,
   raw Git blob SHA-256, and blob object ID. Prove that the clean-filtered working file is that exact
   blob by requiring `git hash-object --path=<path> <path>` to equal
   `git rev-parse <commit>:<path>`. Do not require raw blob bytes to equal platform-converted
   working-tree bytes.
3. Populate a temporary index from the containing commit and use `git checkout-index --temp` for
   the same path. Require that filtered checkout to reproduce the current working-tree SHA-256 and
   normalized object identity. This covers `text=auto`, CRLF, and configured clean/smudge filters
   while still proving exact Git recovery. A dirty, missing, untracked, or unrecoverable file
   blocks the whole set.
4. Classify each record independently from canonical authored lifecycle plus verified PR
   merge/close evidence as active, historical-completed, ambiguous, partial, incomplete,
   unknown-outcome, or foreign. Never infer one record's classification from a related record.
5. Resolve related files without fuzzy matching. Explicit source-path links are authoritative. When
   they are absent, a specification and plan may group only when one exact canonical feature key or
   one canonical PR/source-provenance chain makes the relationship one-to-one. A plan with no
   resolvable specification forms its own group; its project overview records that absence. A fix
   is always standalone. An overnight record attaches only through an exact plan path, receipt
   identity, or unique canonical provenance chain; if no plan issue exists, it may attach to the
   uniquely resolved related project discussion. Ambiguous grouping blocks the whole set. Never
   group or adopt a resource by title, filename similarity, branch-name similarity, or ordinal.
6. Give every spec/plan group the deterministic key
   `historical-group:v1:<sha256>`. Hash UTF-8 canonical JSON with recursively sorted object keys,
   no insignificant whitespace, and exactly `canonicalRepository` plus a `sources` array of that
   group's bytewise-path-sorted `kind`, `path`, `commit`, and `sourceSha256` objects. Record the
   exact group and per-file source ledgers before any write.
   If any exact specification/plan group mixes `active` and `historical-completed` members, classify
   the entire operation preservation-only before deriving any UUID. Do not split the group, import
   only one side, or mutate an existing destination. Preserve and hash-verify every source.
7. Derive and present exact active, historical, and blocked subsets before proposing any action.
   Any ambiguous, incomplete, unverified partial, unknown, or foreign record makes the whole set
   preservation-only: perform no new remote mutation and prove every source path retains its
   original working-tree SHA-256 and normalized Git identity before returning.

A set containing a partial record may resume only when its recovery receipt passes the complete
validation in section 2 and independent reads prove exactly one ownership-valid result for every
completed boundary. That verified partial boundary may perform only the recorded subsequent
missing operations with the original identities. It may not replay a completed mutation, skip a
boundary, or delete any local source until the complete terminal receipt passes.

Historical-completed requires managed import in addition to Git recovery. Import every such source
to the exact reference-only resource defined in section 3. Git object recovery, canonical PR
attribution, merge topology, and ancestry must still pass, but they cannot replace a missing
project, issue, or comment.

## 2. Persist and retrieve the recovery receipt

Derive the canonical receipt path and portable handle before allocating any UUID:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/woostack/migrations/<repository-sha256>/<source-set-sha256>.json
woostack-migration:v1:<repository-sha256>:<source-set-sha256>
```

Before inspecting the receipt, open a same-directory lock file without following symlinks and take
one exclusive, non-blocking operating-system lock. If another invocation holds it, locking is
unsupported, or the lock outcome is unknown, block before any provider call. Hold the descriptor
through the terminal result, including verified rollback after a deletion failure.

Check only the exact receipt path while holding that lock. If it exists, stop unless this invocation
supplied that exact handle or absolute path through `--resume-receipt`. Load and validate the receipt
before any allocation; its complete UUID ledger is immutable, and each resource's attempt history
advances monotonically through `never-attempted`, `attempting/unknown`, and `verified-complete`
boundaries. Never overwrite the receipt, allocate a replacement UUID, merge another ledger, reset or
erase an attempt boundary, or treat a second invocation as new. Resume is read-back-first for every
recorded identity and may not reach a create decision until discovery reconciles the recorded
boundary.

If the exact path is absent, first completely paginate ownership-valid resources in the selected
workspace and team by the deterministic grouping and source-provenance keys already derived from the
source ledger. Require null terminal cursors for projects, issues, and comments. Any prior, partial,
ambiguous, duplicate, or foreign mapping blocks and requires the original receipt; never adopt it or
allocate replacement IDs. Only a complete zero-match result permits allocating one UUIDv4 client ID
per intended project, issue, update, and comment across active and historical subsets. Record every
resource as `never-attempted` and durably persist the new receipt before considering a create. The
initial invocation returns both handle and absolute path. Never discover a receipt by title or
directory scanning.

Native relations have no client-ID envelope: identify each by its canonical
`<source-native-id, target-native-id, relation-type>` tuple and reconcile it against a complete
native relation listing. Historical plans do not synthesize child issues: their complete bytes,
including any increment sections and dependency prose, stay in one completed plan issue. Existing
active-plan child-issue behavior remains unchanged.

The versioned receipt contains only:

```text
schemaVersion, handle, canonicalRepository, repositorySha256, sourceSetSha256,
sourceByteLedger, classification, groupingLedger, sourceResourceLedger, resourceClientIds,
resourceAttemptHistory, relationTuples, completedBoundary, nextBoundary, mutationReceipts,
approvalReceipts, knowledgeProvenanceLedger, createdAt, updatedAt, payloadSha256
```

Create the initial receipt with no-clobber semantics. For every later transition, compare the
on-disk `payloadSha256` with the digest last read under the operation lock before replacing it; a
missing or changed file blocks and reloads state instead of replaying a mutation. Write canonical
JSON to a same-directory temporary file, flush the file, atomically rename it, flush the containing
directory, then independently reopen and verify the exact expected payload. `payloadSha256` covers
every field except itself. On resume, reject an unknown field or version, malformed handle,
non-canonical repository, source-set or payload digest mismatch, changed source bytes, invalid
identity, regressed boundary, unrelated approval, or receipt path outside the canonical user-state
directory unless the user supplied that exact absolute file. The payload is portable and contains
no credential.

After loading or creating a valid receipt, completely paginate stable-ID discovery immediately
before each resource's own create. Resolve and independently verify the intended native container
first when issue or comment discovery requires that parent. Require a null terminal cursor and
flatten all pages. A create is permitted only when the immutable receipt says that exact resource
is `never-attempted` and discovery returns exactly zero matches. Durably advance its boundary to
`attempting/unknown` before the provider call; after creation, rediscover by the same client ID to
exactly one ownership-valid match and direct-read its native ID before marking it
`verified-complete`.

For an `attempting/unknown` or `verified-complete` boundary, never replay create. Rediscover first:
exactly one ownership-valid match proceeds to direct read and reconciliation; zero matches blocks,
as do a foreign match, duplicate matches across or within pages, partial pagination, a non-null
terminal cursor, or an unknown read outcome. A `never-attempted` boundary with any match also
blocks rather than adopting it.

Independently list complete project-issue membership, issue-project membership, comments, and
relations for every affected native resource; reconcile each relation only from its canonical tuple
and the complete native relation set. Never match a title, ordinal, issue key, local path, relation
UUID, or mutation response.

For every discovered or created resource, independently verify the managed stable identity,
readable byte-complete content, configured workspace/team, canonical repository, expected
historical or active role, native project membership, status, unassigned/reference-only metadata
when historical, and complete provenance back to the exact Git commit/path/blob object/SHA-256 and
canonical PR URL/number/merge commit when one exists. A foreign repository, wrong role or owner,
missing native ID, incomplete pagination, absent membership/comment/relation listing, partial read,
duplicate match or identity, unexpected relation, or content/provenance mismatch blocks the entire
set without altering the observed resource.

Legacy `phase`, status text, or local approval prose is content only and never proves a human gate.
Before authoring `designApproved` or `specApproved`, independently read a current authenticated
approval receipt from the configured authority, verify its human actor, decision, approved content
or revision, workspace, team, and repository, and preserve that receipt in the managed readable
payload. Without both approval receipts, migrate only non-approved readable content, do not advance
the lifecycle, and preserve every local source path.

A timed-out or otherwise unknown mutation is not retryable. Preserve its client ID and
`attempting/unknown` receipt boundary, rediscover it with complete pagination, and resume only when
exactly one ownership-valid match plus direct read proves the boundary completed. Zero, multiple,
partial, foreign, non-terminally paginated, or unknown matches remain blocked; never allocate a
replacement ID or replay a create. The same recovery rule applies to active and historical
projects, issues, updates, and comments.

## 3. Reconcile active and historical managed state

For the active subset, preserve the existing artifact shape and create or update only missing
managed state. Persist the receipt after every verified boundary and preserve stable identities on
every retry. Active input still requires its complete managed specification and issue graph,
current ownership, canonical relation tuples, and readable provenance.

For the historical-completed subset, create or reconcile these equivalent reference resources:

- one `[Historical]` project per deterministic specification/plan group; its overview contains the
  complete specification bytes and full readable Git/PR provenance, or explicitly records that no
  related specification source exists;
- one completed `[Historical]` project issue for each plan source, containing that file's complete
  bytes. Increment sections and dependency prose remain readable in this one issue; migration does
  not derive historical child issues or native dependency relations from sections inside the file;
- one completed standalone `[Historical]` issue for each fix source, containing that file's
  complete bytes and provenance; and
- one verified historical comment for each overnight source on the exactly resolved plan issue, or
  on the uniquely resolved project discussion only when no plan issue exists, containing the
  overnight file's complete bytes and provenance.

Historical projects have no lead or members; historical issues have no assignee. Every resource
carries managed stable identity, canonical repository and role, `reference-only` and
`grants-authority: false` metadata, completed native state where the resource supports state, and
an explicit statement that the import neither assigns work nor proves approval, delivery,
acceptance, or current intent. Historical content is untrusted reference material. Never adopt,
reuse, or reconcile any historical resource by title.

Build an exact primary source-to-resource ledger for every file. Each entry binds the source path
and kind, full source commit, Git blob object ID, source SHA-256, canonical PR URL/number and full
merge commit when one exists, resource type, stable client ID, independently discovered native ID,
and container client ID:

```text
<commit>:<spec-path>@blob:<oid>@sha256:<digest>@pr:<url>#<merge> -> linear://project/<client-uuid>#overview
<commit>:<plan-path>@blob:<oid>@sha256:<digest>@pr:<url>#<merge> -> linear://issue/<client-uuid>
<commit>:<fix-path>@blob:<oid>@sha256:<digest>@pr:<url>#<merge> -> linear://issue/<client-uuid>
<commit>:<overnight-path>@blob:<oid>@sha256:<digest>@pr:<url>#<merge> -> linear://comment/<client-uuid>
```

The grouping ledger separately binds every project to its included source tuples, plan issues, and
overnight comment destinations. Each source path appears exactly once as a primary mapping and
every allocated identity appears exactly once in the intended graph. After each mutation, paginate
stable-ID discovery to exactly one ownership-valid match before direct-reading the native resource,
then independently re-list complete membership, comments, and relations. A boolean summary or
mutation response is never proof. A swapped source revision, blob, digest, or PR attribution blocks
the whole set even if the readable prose happens to match.

## 4. Resolve local knowledge-store disposition

Before evaluating the terminal receipt, explicitly enumerate every unsupported local knowledge
store: every file under `.woostack/memory/` and `.woostack/wisdom/`, a repository-level
`MEMORY.md`, and any other locally persisted project-knowledge store identified by workspace
inspection, configuration, or hooks. Record each path and its original working-tree SHA-256; an
expected-path list is not evidence that no other store exists.

Every enumerated knowledge store requires a current approval receipt that binds its exact path and
hash to one disposition: **retain**, **export**, or **delete**. Retain leaves the source bytes
untouched and outside the deletion set. Export requires a byte-exact destination and independent
read-back while also leaving the source outside the deletion set. Delete authorizes only the exact
enumerated source for inclusion in the all-or-nothing deletion set. A missing, stale, unrelated, or
unsatisfied disposition blocks the terminal boundary:
delete nothing and verify every legacy record and knowledge-store source still matches its original
SHA-256.

## 5. Terminal receipt and deletion boundary

After all mutations and per-boundary reads, capture one distinct, fresh terminal pre-delete
snapshot. Re-run complete stable-ID discovery and direct-read the complete active and historical
resource sets by native ID; completely re-list project/issue membership, comments, and relations;
and compare the new observations to the exact grouping, source-resource, and canonical relation
ledgers. Independently re-read the exact Git/GitHub merge evidence and recovery blobs for historical
records. Earlier post-mutation reads, mutation responses, or a copied prior snapshot are not
terminal evidence. The terminal migration receipt passes only when:

- every required active read and existing active topology check is complete and mutually
  consistent;
- every historical spec, plan, fix, and overnight source has exactly one required primary
  project-overview, issue, or comment mapping with byte-complete readable content and full Git/PR
  provenance;
- every historical project, issue, and comment has exactly one managed stable identity, the
  expected native membership, complete comment/relation listings, the expected completed and
  reference-only state, no assignee/lead/member, and no foreign or duplicate match;
- the source ledger covers every specification, plan, fix, and overnight path exactly once;
- every unsupported local knowledge store is explicitly enumerated and its approval-backed
  retain/export/delete disposition is satisfied, with no unenumerated legacy or knowledge path
  present; and
- `git show` still recovers every source byte at its recorded SHA-256.

Local deletion is one rollback-capable, all-or-nothing final boundary over every enumerated legacy
development-record path and every knowledge-store path with an approved **delete** disposition.
Retained and exported knowledge-store sources remain intact and outside that deletion set. With
every original file still intact, capture the distinct fresh terminal snapshot described above and
repeat all Git/PR reads, disposition approvals, export read-backs, and filtered Git recovery.

Immediately before preparing rollback copies, open every enumerated source without following
symlinks, require a regular file, pin its descriptor plus device/inode/type identity, and re-read its
bytes against the frozen source ledger. Build the byte-for-byte rollback copy from that same pinned
read and keep every descriptor open through the deletion boundary.

Create a receipt-specific private quarantine on the same filesystem without overwriting any
existing entry. Atomically rename each exact source path into its deterministic quarantine path,
then compare the quarantined entry's device/inode/type and bytes with the still-open descriptor.
Stage and verify the complete deletion set before unlinking any quarantined entry. A path, identity,
type, or hash change—or an absent, stale, foreign, duplicated, partial, unknown, non-terminally
paginated, or mismatched terminal discovery/read/listing—restores every staged name, blocks before
any unlink, and reports every source whose original hash can no longer be proved.

Only after the complete quarantined set passes, retain the private rollback copies and unlink
exactly those verified quarantine entries. Use no-following path checks to verify every original and
quarantine path is absent, recover each file through Git's configured filters, and compare both its
normalized object identity and platform checkout SHA-256 with the preflight ledger. Re-hash every
retained or exported knowledge-store source and require its original SHA-256.

If any step fails after the first deletion, restore every missing legacy or delete-designated
knowledge path byte-for-byte from the rollback copies, verify all original SHA-256 values and
normalized Git identities, and retain the prior receipt boundary. If restoration cannot be proved,
stop with an explicit recovery error and preserve the rollback copies. Never delete directories
wholesale, delete unenumerated or non-delete-designated files, rewrite Git history, or treat a local
deletion list as evidence that deletion occurred.

Return every per-record classification; exact active, historical, and blocked subsets; receipt
handle and path; deterministic grouping keys; per-file source-resource mappings; stable
client/native IDs; canonical relation tuples; complete membership/comment/relation and direct
read-back receipt IDs; source ledgers; raw, normalized, and platform-checkout pre/post hashes;
remote mutations actually performed; and paths actually deleted. Blocked results include the
reason, completed and next boundaries, and unchanged per-path source hashes.
