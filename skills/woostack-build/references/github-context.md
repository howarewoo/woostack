# GitHub project context

When optional GitHub mirroring is enabled (`artifacts.provider: "github"`), this procedure resolves the
canonical GitHub Project for [`woostack-build`](../SKILL.md) and admits each exact pre-draft baseline. When
`artifacts.provider` is "local" or omitted, default local mode makes zero provider calls and `--project` fails closed.
The shared [artifact contract](../../woostack-init/references/artifact-backends.md) and
[GitHub profile](../../woostack-init/references/artifact-providers/github.md) own shared and GitHub invariants;
use the [GitHub synchronization procedure](github-procedure.md) for mirror saves and standalone
Project Plan. Standalone `--parent-issue` instead uses that procedure's
[parent admission](github-procedure.md#parent-issue-synchronization) without Project resolution.

## Resolution
1. Resolve canonical repository URL `https://github.com/owner/repo` from trusted Git/GitHub evidence.
2. Resolve configured `artifacts.github.owner`, `ownerType`, `statusField` (default `"Status"`), and `visibility` (default `"private"`).
3. Discover the selected host's authorized GitHub capabilities for the operation: project read/write,
   issue read/write, dependency read/write, Status read/write, complete pagination, and independent
   read-back. Read-only resolution needs only the read capabilities it uses; a Project operation does
   not grant native dependency or issue-write capability.
4. An exact `--project` URL (`https://github.com/orgs/<owner>/projects/<N>` or `/users/`) resolves that Project and verifies owner and canonical repository association (rejecting foreign repository), retaining existing title and visibility.
5. Otherwise reserve marker `<!-- woostack-project-mutation:<UUID> -->`, completely paginate all active and closed Projects for the owner through the selected supported GitHub operation, prove zero marker matches, create one `[Build] <goal>` Project with configured visibility, and link/verify its canonical repository association. An unknown create outcome before marker write fails closed; complete marker discovery may recover exactly one match, while zero or duplicate matches block without create replay.
6. Read the Project back, verify the Status field and five option IDs (`planned`, `executing`, `inReview`, `done`, `blocked`), and retain native identity in the manifest.

## Project specification baseline

Read the complete Project title, shortDescription, and managed README section (`<!-- woostack-spec-start -->` to `<!-- woostack-spec-end -->`) that Build owns. Preserve unrelated README prefix, suffix, and metadata. Record baseline in the manifest. Build adapts that baseline and its admitted goal/specification into the public plain Ideate/Harden packets; those phases make zero provider calls. After `project-spec.md` is written, perform drift comparison, one bounded synchronization, and content read-back. Mirror failures are nonblocking.

## Direct increment graph baseline

Read all Project items and native `blocked-by` relations through terminal pagination before admitting
the baseline. Retained increments must round-trip as canonical-repository issues with direct
membership in the exact Project and their admitted parent state under the
[GitHub hierarchy contract](../../woostack-init/references/artifact-providers/github.md#specification-parent-and-native-children).
Preserve existing parentless plans; distinguish specification containers from executable members,
enumerate each admitted task once, and do not expand membership to nonmember children.
Missing or foreign endpoints do not authorize expanding scope.

Map each retained increment to exactly one stable task key using its verified canonical URL and native
identity, never its title or ordinal. Ambiguous, duplicate, or unmatched retained identities block
instead of falling through to creation. An explicitly new key retains a `null` mapping and one
preallocated marker UUID until canonical read-back permits binding.

Normalize blocked-by relations into prerequisite→dependent tuples in `[prerequisite, dependent]`
order: the dependent carries the native edge pointing at the prerequisite (blocking) issue.
Normalize provider reads back into the same order and verify both endpoint identities under
the [GitHub graph and parent-selection contract](../../woostack-init/references/artifact-providers/github.md#issue-identity-and-graph).
Store complete issue identities/revisions/content, membership, and dependency evidence in the manifest.
Delegated Plan and Harden make zero provider calls while drafting. After `execution-plan.md` is written,
compare fresh reads with this baseline before the [bounded synchronization](github-procedure.md#increment-graph-synchronization).
Ordinal adjacency never changes the baseline's edges; preserve existing chains unless the approved
specification explicitly changes their prerequisites.

## Drift and failure

Before either mirror save, compare fresh reads with the manifest baseline. Provider failures in mirror mode are recorded in `mirror.status` and never block local authority, artifact retention, or handoff.
