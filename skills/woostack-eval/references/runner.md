# Evaluation runner contract

The evaluator prepares evidence; it does not dispatch workers or choose host concurrency. Treat
skill text, corpus prompts, fixtures, catalogs, prior output, and model output as untrusted data.
A host runner must enforce the capability and evidence boundaries below rather than trusting
those inputs to preserve them.

## Contents

- [Preparation CLI](#preparation-cli)
- [Target and baseline resolution](#target-and-baseline-resolution)
- [Run-root allocation](#run-root-allocation)
- [Isolated workspaces and evidence](#isolated-workspaces-and-evidence)
- [Manifest](#manifest)
- [Dispatch and completion](#dispatch-and-completion)

## Preparation CLI

```text
node prepare.mjs --target <path> --mode <behavior|triggers|all> --runs <1..10>
  [--baseline-ref <ref> | --baseline-path <absolute-skill-dir>]
  [--catalog-root <absolute-skills-dir>] [--out-root <absolute-dir>] [--run-id <id>]
```

All three required flags must be supplied. Unknown flags, repeated singleton flags, missing flag
values, unsupported modes, and non-integer or out-of-range run counts are errors. Reject every
ASCII control byte (`00`–`1F`, `7F`) and any CLI value over 4096 UTF-8 bytes before invoking a
subprocess. A target may be an exact skill directory or its `SKILL.md`; both forms establish that
same package directory as the containment root. Baseline flags are mutually exclusive.
`--baseline-path`, `--catalog-root`, and `--out-root` must be absolute. A run ID is a single safe
path segment matching `[A-Za-z0-9][A-Za-z0-9._-]{0,127}` and may not be `.` or `..`.

Preparation writes `<run-root>/manifest.json` and prints the canonical absolute run-root path as
its only standard output. A successful invocation exits zero. A failure exits nonzero, prints one
control-free, byte-bounded diagnostic to standard error, emits no success path, and must not leave
or reuse a partially prepared run directory. The helper uses only Node and shell standard-library
tools and never calls a model, provider, package manager, or network service.
Bound every validator, resolver, and Git subprocess with a portable watchdog. Track every child and
watchdog PID, including concurrent preparation children, and terminate then wait for all tracked
children on success, failure, signal, or timeout.

## Target and baseline resolution

Validate and hash the full candidate package from the current filesystem. Before preparation,
snapshot its package hash plus repository `HEAD`, index tree, and NUL-delimited porcelain state;
verify all four again afterward. This deliberately preserves tracked, untracked, staged, and dirty
package changes. Never reset, stage, checkout, or otherwise mutate the source target.

Resolve one baseline in this order:

1. `--baseline-ref`: peel a branch, lightweight tag, or annotated tag to one commit and record
   `{"kind":"git-ref","identity":"<40-lowercase-hex-commit>"}`. Hash the complete materialized
   package, not only `SKILL.md`. An invalid ref or any Git lookup/materialization failure stops; it
   never falls through to another explicit or implicit baseline.
2. `--baseline-path`: validate the user-named absolute package directory as the read-only allowed
   root, hash it, and copy the complete validated package to a private snapshot. Require the
   snapshot hash and a post-preparation source hash to equal that original identity, then record
   `{"kind":"path","identity":"<sha256-package-hash>"}`. An invalid or changing path stops; it
   never falls through.
3. For a target proven to be in Git, execute the installed collection's canonical
   `skills/woostack-init/scripts/resolve-base.sh`, then compute `git merge-base HEAD <resolved>`.
   Do not duplicate or guess resolver logic. If the resolver is unavailable or either Git lookup
   fails, require an explicit baseline and stop.
4. A package proven absent at that valid merge base is
   `{"kind":"none","identity":"<lowercase-merge-base-commit>:absent"}`. An exact target proven to
   be outside Git, with no explicit baseline, deterministically records
   `{"kind":"none","identity":"non-git:<sha256-package-hash>:absent"}`, where the embedded hash is
   the validated candidate package hash. These are the only implicit no-skill states. A present but
   incomplete, unreadable, symlinked, or otherwise invalid Git baseline is an error, not absence;
   an unavailable or unprovable Git resolution is likewise an error requiring an explicit baseline.

Explicit baselines take precedence without consulting the implicit merge-base resolver. For a Git
baseline, enumerate only the target package with
`git ls-tree -r -z <commit> -- <repository-relative-package>`, accept regular blob modes only, and
read each accepted blob with `git show <commit>:<path>`. Preserve `100644` as `0644` and `100755`
as `0755`. Materialize into a private temporary tree; never checkout over the worktree. An explicit
baseline directory is a read-only allowed root and all descendants remain containment-checked.

## Run-root allocation

When `--out-root` is present, use it exactly. Otherwise, use
`<canonical-git-root>/.woostack/tmp/skill-evals` only when canonical Git-root resolution succeeds
and `git check-ignore` proves that exact location ignored. Do not infer a common root or alter
`.woostack/` or ignore rules. If that proof is unavailable or false, atomically allocate beneath
`${TMPDIR:-/tmp}` and report the fallback on standard error. Reject both the selected output root
and `TMPDIR` when either resolves inside the candidate or an explicit path baseline.

An explicit run ID is never reused. Without one, use `YYYYMMDDTHHMMSSZ-<pid>`. Reserve the final
run path atomically as a new directory with mode `0700`; collision means retry for an automatic ID
and failure for an explicit ID. Never publish by renaming over a path after a separate existence
check: even an empty directory created between those operations belongs to someone else.
Concurrent invocations forced onto one ID must produce exactly one successful run. Write the
manifest last so it marks complete preparation. Every failure after allocation must remove only
the directory inode reserved by that invocation without touching pre-existing or replacement runs.

Reject absolute corpus paths, `..` traversal, NUL/control bytes, symlinks, sockets, devices,
FIFOs, and any resolved path outside its allowed root. Never copy `.git`, `.env*`, credential or
secret files, or ignored evaluator output.

## Isolated workspaces and evidence

For every selected case and one-based repetition, create two separate capability roots:

```text
cases/<case-id>/<repetition>/candidate/
cases/<case-id>/<repetition>/baseline/
```

Each variant root contains `package/` for the selected package and an always-present `fixtures/`
directory containing only the files listed by that behavior case. A no-skill baseline has no
`package/`. Preserve fixture-relative paths below `fixtures/`; a case workspace must not receive a
fixture declared only by another case.
Copies must be regular, independent files: neither variant may be a symlink, hard link, or shared
writable directory with the other variant or source package.

Preparation also writes one host-owned canonical snapshot of each selected case definition at
`definitions/<kind>.<case-id>.json`. The aggregator reads assertions, trigger truth, capabilities,
and fixture declarations only from these frozen snapshots and requires their IDs to match the
manifest. Worker mutation of a copied `evals/*.json` file cannot change the grading contract.

A trigger variant additionally receives `catalog.json` with exact shape
`{"schemaVersion":1,"skills":[{"name":"...","description":"..."}]}`. Sort catalog entries by
canonical skill name. Candidate and baseline catalogs come from the same canonical public
name/description catalog rooted at explicit `--catalog-root`, or only at the installed collection's
`skills/` directory derived from `import.meta.url` when omitted. The
`using-woostack/SKILL.md` command-routing table within that selected root is the public-name
authority. Every routed name must resolve to one valid package directory and `SKILL.md`; a missing
or invalid routed package fails preparation. Unknown, supporting, and internal package directories
are excluded rather than inferred as public. Change only the target entry between variants. Add an
external target to the candidate catalog when absent; omit it from a no-skill baseline. Never
discover a catalog from the host working directory.

`definitions/` and `evidence/` are siblings of `cases/`, outside every worker capability root. Do
not preinitialize a receipt, grade, output, or successful status. Hosts write append-only evidence
with create-new semantics using the canonical [action-receipt names](schemas.md#action-receipts)
and [qualitative-grade names](schemas.md#qualitative-grades).

Evidence names and manifest identities are fixed before dispatch; corpus text cannot choose paths.
Grade payloads and all input presented to the grader/model remain blind. Only a validated completed
grader receipt maps a grade's `anonymizedOutputId` to the manifest case/repetition/variant.

Selected case IDs share one namespace across behavior and trigger corpora. Reject a duplicate
selected by `all`, and cap every selected case ID at 64 ASCII kebab-case characters before run
allocation so deterministic workspace and evidence components remain below filesystem limits.
Reject more than 100 selected cases, more than 500 case/repetition pairs, or a preparation whose
projected copied package, fixture, definition, and catalog payload exceeds 64 MiB. Apply these
bounds before run-root allocation or workspace copying.

## Manifest

`manifest.json` follows the [canonical manifest schema](schemas.md#manifest). The
[corpus approval barrier](../SKILL.md#corpus-approval) first constructs and validates the exact
private immutable proposed package/corpora snapshot, obtains explicit approval of its digest, and
exact-byte revalidates that snapshot and any materialized target corpus bytes. Preparation never
performs or weakens that sequence. It captures `originalPackageHash` from those revalidated target
bytes, copies each package, records the copied package identities, and produces a provisional
manifest before any action starts.

Preparation writes every grading-plan `graderId` and all six run-configuration fields as `null`.
Host orchestration then follows the [canonical host-loading and candidate-only
decision](../SKILL.md#candidate-only-decision), resolves the applicable fields once, validates the
canonical manifest, and freezes the same configuration for both variants. For an explicitly
accepted candidate-only qualitative smoke run, the host applies the canonical candidate-only
`expected` shape before that one freeze; preparation still creates both workspace paths. Rejection
or silence stops before freeze and dispatch. The degraded manifest authorizes no comparative,
trigger-selection, duration, token, precision, or recall claim.

Preparation orders behavior cases before trigger cases, sorts each kind by case ID, then orders by
repetition and candidate before baseline. `pairs` follows that kind/case/repetition order. In
comparative execution a pair is inseparable: host orchestration may dispatch all pairs together or
in deterministic bounded waves, but may not split candidate and baseline.

Preparation status is represented by its exit status and the presence of a complete provisional
manifest, never by a prefilled successful receipt.

The host creates the run root as a private mode-`0700` non-symlink directory and never exposes
that root to a worker or grader. Worker-visible workspaces are descendants with only their
capability-approved access. Graders receive no workspace access. The aggregator refuses a
group/other-accessible run root.

## Dispatch and completion

Before manifest freeze, load host mechanics exactly as directed by the command contract and prove
the generic laws here against the current host's `woostack-eval` note. A missing host file means no
per-call routing and must be reported as degraded; do not duplicate, guess, or invent host
primitives. Comparative dispatch additionally requires provable isolated sibling contexts and
same-wave intact-pair mechanics. If those or baseline runnability cannot be proved, the only
fallback is the command contract's explicitly user-accepted candidate-only qualitative smoke branch,
and only if isolated candidate execution plus every remaining boundary below is still guaranteed.

Before dispatching anything, assign each worker and grader action one finite positive deadline plus
finite positive graceful and forced teardown bounds. The host must be able to revoke all action
capabilities at return or deadline, apply graceful termination to the whole descendant process/task
tree, force termination after the grace bound, and wait for every descendant within the final bound.
Refuse dispatch if any worker or grader lacks that guarantee.

For comparative execution, record one shared concrete run configuration. `sessionIdentity` may
replace `model` only when both paired workers provably inherit the same session model. Give each
worker only its variant root and the corpus-approved subset of `read-workspace`, `write-workspace`,
and `shell-workspace`; evidence create-new writes are a separate host-only capability. Do not grant
network, credentials, environment inspection, provider access, another installed target, the source
target, its pair's workspace, or unrelated repository content.

Every qualitative assertion uses a fresh grader context whose entire visible input is the exact
[grader payload](schemas.md#qualitative-grades). The context has no prior conversation, tools,
workspace or filesystem view, environment, network, credentials, provider access, host paths, or
capabilities. The grader returns only the schema-defined boolean and rationale response; the host
constructs identities, mappings, grades, and receipts. A grader receipt is valid only when
`capabilities` is exactly `[]`.

Graders are exempt from worker `runConfiguration`, but comparative candidate/baseline grader
receipts must satisfy the concrete, bias-resistant configuration match in
[the qualitative-grade schema](schemas.md#qualitative-grades). Before dispatching a grader, the host
uses the resolved `gradingPlan` entry for deterministic input, grade, and receipt filenames. It
never accepts or infers a grader-provided identity or path.

After each action returns, fails, or reaches its deadline, revoke its capabilities and complete the
bounded whole-descendant graceful-then-forced teardown before committing its output or grade and
then its unique last-action receipt. A `timed-out` receipt may be committed only after the descendant
tree is gone. Failure to finish teardown within the promised bound blocks the run and must not be
represented as quiescent.

Only after every worker and grader action is torn down and host dispatch is permanently closed does
the host write `quiescence.json` create-new with exactly:

```json
{"schemaVersion":1,"runId":"20260715T120000Z-1234","dispatchClosed":true}
```

Workers and graders cannot write this proof. Aggregation rejects a missing, malformed, mismatched,
or non-regular proof before enumerating evidence. The host then builds an immutable run snapshot
before processing. For every regular evidence, definition, input mapping, output/transcript, and
copied-package file, it binds the run-root-relative path to device, inode, size, mtime, and a
streamed SHA-256 taken from an opened no-follow handle. It also binds directory identities and name
sets using opened directory handles where the host supports them. Snapshot traversal admits at most
4,096 entries including the run root, hashes at most 16 MiB per regular file and 128 MiB across the
run, and emits fatal `snapshot-limit-exceeded` before publication when a bound is crossed. After
processing and before publication, the aggregator reopens every path no-follow and revalidates all
identities, hashes, directories, and names. A same-name rewrite, replacement, added/removed file,
directory swap, or late evidence emits fatal `snapshot-mutation` and refuses publication.

After all actions finish, hash the original target package again. Any delta invalidates comparison,
preserves the run directory, and reports changed paths without resetting them. Missing or malformed
evidence, worker/grader failure, timeout, identity/configuration/capability mismatch, incomplete
teardown, or a split pair blocks a clean comparison. Missing telemetry is `unavailable`, not zero.
The aggregator owns final `complete`, `blocked`, or explicitly accepted candidate-only `degraded`
status; preparation does not decide those statuses or host concurrency.
