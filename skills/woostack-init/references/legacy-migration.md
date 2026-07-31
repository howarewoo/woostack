# One-way legacy development-record migration

`/woostack-init --migrate-legacy` is the sole routed owner of migration from tracked
`.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, and `.woostack/overnight/`
development records. Normal init and doctor only preserve and report these files. No other skill
creates, imports, deletes, or claims authority from them.

The migration is one bounded operation over an explicitly enumerated related record set. Run it
only after init's official Linear MCP preflight and repository-ownership checks succeed. The host's
official MCP is the only remote transport; Git is the recovery source. Never use a repository
adapter, token file, local development authority, or title match.

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
5. Derive and present exact active, historical, and blocked subsets before proposing any action.
   Any ambiguous, incomplete, unverified partial, unknown, or foreign record makes the whole set
   preservation-only: perform no new remote mutation and prove every source path retains its
   original working-tree SHA-256 and normalized Git identity before returning.

A set containing a partial record may resume only when its recovery receipt passes the complete
validation in section 2 and independent reads prove exactly one ownership-valid result for every
completed boundary. That verified partial boundary may perform only the recorded subsequent
missing operations for active records with the original identities. It may not replay a completed
mutation, skip a boundary, or delete any local source until the complete terminal receipt passes.

The historical-completed subset takes the Git-only path. Exact canonical PR attribution, verified
merge commit and ancestry, and recoverable Git blobs are its authority. Historical records perform
zero Linear mutation even when related active records are reconciled in the same operation or no
corresponding managed resource exists.

## 2. Persist and retrieve the recovery receipt

Before the first remote write, allocate one UUIDv4 client ID per intended project, issue, update,
and comment. Native relations have no client-ID envelope: identify each by its canonical
`<source-native-id, target-native-id, relation-type>` tuple and reconcile it against a complete
native relation listing.

Persist the recovery receipt outside the repository at
`${XDG_STATE_HOME:-$HOME/.local/state}/woostack/migrations/<repository-sha256>/<source-set-sha256>.json`.
Its portable handle is
`woostack-migration:v1:<repository-sha256>:<source-set-sha256>`. The initial invocation returns
both the handle and absolute receipt path. A resumed invocation must pass either value with
`--resume-receipt <handle-or-absolute-json-path>`; never discover a receipt by title or directory
scanning.

The versioned receipt contains only:

```text
schemaVersion, handle, canonicalRepository, repositorySha256, sourceSetSha256,
sourceByteLedger, classification, resourceClientIds, relationTuples,
completedBoundary, nextBoundary, mutationReceipts, approvalReceipts,
knowledgeProvenanceLedger, createdAt, updatedAt, payloadSha256
```

Write canonical JSON to a same-directory temporary file, flush the file, atomically rename it,
then flush the containing directory. `payloadSha256` covers every field except itself. On resume,
reject an unknown field or version, malformed handle, non-canonical repository, source-set or
payload digest mismatch, changed source bytes, invalid identity, regressed boundary, unrelated
approval, or receipt path outside the canonical user-state directory unless the user supplied that
exact absolute file. The payload is portable and contains no credential.

After loading a valid receipt, independently search for projects, issues, updates, and comments by
each recorded client ID with complete pagination, then direct-read the sole match. Reconcile each
relation from its canonical tuple and complete native relation set. Never match a title, ordinal,
issue key, local path, relation UUID, or mutation response.

For every discovered or created resource, independently verify the managed envelope, readable
content, configured workspace/team, canonical repository, role, native project membership, current
owner, and complete provenance back to the exact Git commit/path/SHA-256. A foreign repository,
wrong role or owner, missing native ID, incomplete pagination, partial read, duplicate match, or
content/provenance mismatch blocks the entire set without altering the observed resource.

Legacy `phase`, status text, or local approval prose is content only and never proves a human gate.
Before authoring `designApproved` or `specApproved`, independently read a current authenticated
approval receipt from the configured authority, verify its human actor, decision, approved content
or revision, workspace, team, and repository, and preserve that receipt in the managed readable
payload. Without both approval receipts, migrate only non-approved readable content, do not advance
the lifecycle, and preserve every local source path.

A timed-out or otherwise unknown mutation is not retryable. Preserve its client ID and receipt
boundary, rediscover it through complete independent reads, and resume only when exactly one
ownership-valid match proves the boundary completed. Zero, multiple, partial, or unknown matches
remain blocked; never allocate a replacement ID or replay a create.

## 3. Reconcile active managed state

For the active subset, create or update only missing managed state and persist the receipt after
every verified boundary. Preserve stable identities on every retry. After each mutation,
direct-read the native resource and independently re-list its owner, project membership, and
complete relevant relations. Build a source-to-managed ledger entry for every active file:

```text
<commit>:<path>@sha256:<source-sha256> -> linear://project/<client-uuid>
<commit>:<path>@sha256:<source-sha256> -> linear://issue/<client-uuid>
```

Active input requires the complete managed specification and issue graph, current ownership,
canonical relation tuples, and readable provenance. A boolean summary or mutation response is
never proof. Historical-completed records bypass this section and retain immutable Git blob and
verified PR provenance only.

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

Re-read the complete active resource subset by both stable client IDs and native IDs, and re-list
relations by canonical tuple. For the historical subset, re-read only the exact Git/GitHub merge
evidence and recovery blobs; absence of a Linear resource is valid. The terminal migration receipt
passes only when:

- every required active read is complete and mutually consistent;
- every historical record has exact immutable Git blob and PR provenance with zero Linear
  mutation;
- the source ledger covers every specification, plan, fix, and overnight path exactly once;
- every unsupported local knowledge store is explicitly enumerated and its approval-backed
  retain/export/delete disposition is satisfied, with no unenumerated legacy or knowledge path
  present; and
- `git show` still recovers every source byte at its recorded SHA-256.

Local deletion is one rollback-capable, all-or-nothing final boundary over every enumerated legacy
development-record path and every knowledge-store path with an approved **delete** disposition.
Retained and exported knowledge-store sources remain intact and outside that deletion set. With
every original file still intact, immediately repeat the applicable active managed reads or
historical Git/PR reads, relation reconciliation, disposition approvals, export read-backs, and
filtered Git recovery. If any read is stale, partial, unknown, or mismatched, delete nothing and
hash-verify all original source bytes.

Only after those checks pass, retain private byte-for-byte rollback copies and delete exactly the
approved deletion set. Immediately verify every deleted path is absent, recover each file through
Git's configured filters, and compare both its normalized object identity and platform checkout
SHA-256 with the preflight ledger. Re-hash every retained or exported knowledge-store source and
require its original SHA-256.

If any step fails after the first deletion, restore every missing legacy or delete-designated
knowledge path byte-for-byte from the rollback copies, verify all original SHA-256 values and
normalized Git identities, and retain the prior receipt boundary. If restoration cannot be proved,
stop with an explicit recovery error and preserve the rollback copies. Never delete directories
wholesale, delete unenumerated or non-delete-designated files, rewrite Git history, or treat a local
deletion list as evidence that deletion occurred.

Return every per-record classification; the exact active, historical, and blocked subsets; receipt
handle and path; stable client/native IDs; canonical relation tuples; complete read-back receipt
IDs; source ledgers; raw, normalized, and platform-checkout pre/post hashes; remote mutations
actually performed; and paths actually deleted. Blocked results include the reason, completed and
next boundaries, and unchanged per-path source hashes.
