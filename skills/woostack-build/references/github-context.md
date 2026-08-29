# GitHub project context

When optional GitHub mirroring is enabled (`artifacts.provider: "github"`), this procedure resolves the
canonical GitHub Project for [`woostack-build`](../SKILL.md) and admits each exact pre-draft baseline. When
`artifacts.provider` is "local" or omitted, default local mode makes zero provider calls and `--project` fails closed.
The shared [artifact contract](../../woostack-init/references/artifact-backends.md) and
[GitHub profile](../../woostack-init/references/artifact-providers/github.md) own shared and GitHub invariants;
use the [GitHub synchronization procedure](github-procedure.md) for mirror saves and standalone Plan.

## Resolution
1. Resolve canonical repository URL `https://github.com/owner/repo` from trusted Git/GitHub evidence.
2. Resolve configured `artifacts.github.owner`, `ownerType`, `statusField` (default `"Status"`), and `visibility` (default `"private"`).
3. Preflight host-authenticated `gh` capabilities (`projectRead`, `projectWrite`, `issueRead`, `issueWrite`, `dependencyRead`, `dependencyWrite`, `statusFieldRead`, `statusFieldWrite`, `pagination`, `independentReadBack`).
4. An exact `--project` URL (`https://github.com/orgs/<owner>/projects/<N>` or `/users/`) resolves that Project and verifies owner and canonical repository association (rejecting foreign repository), retaining existing title and visibility.
5. Otherwise reserve marker `<!-- woostack-project-mutation:<UUID> -->`, paginate all active and closed Projects for the owner via `gh api graphql`, prove zero marker matches, create one `[Build] <goal>` Project with configured visibility, and link/verify its canonical repository association. An unknown create outcome before marker write fails closed; complete marker discovery may recover exactly one match, while zero or duplicate matches block without create replay.
6. Read the Project back, verify the Status field and five option IDs (`planned`, `executing`, `inReview`, `done`, `blocked`), and retain native identity in the manifest.

## Project specification baseline

Read the complete Project title, shortDescription, and managed README section (`<!-- woostack-spec-start -->` to `<!-- woostack-spec-end -->`) that Build owns. Preserve unrelated README prefix, suffix, and metadata outside the markers. Record baseline in the manifest. Ideate and Harden make zero provider calls while drafting. After `project-spec.md` is written, perform drift comparison, one bounded synchronization, and content read-back. Mirror failures are nonblocking.

## Direct increment graph baseline

When GitHub mirroring is enabled, select current Project issues in the canonical repository having `parent = null` and a canonical URL (`https://github.com/owner/repo/issues/<N>`). When creating an issue, preallocate UUID, embed `<!-- woostack-issue-mutation:<UUID> -->` in the complete body contract, paginate canonical repo issues to prove zero marker matches, create with `parent = null`, read back the issue and persist the bind-once mapping, add directly as a Project item and read back `planned` status, and finally create and read back native dependencies before advancing.
Read native dependencies via `gh api graphql` and normalize `blocked-by` relations into predecessor→successor tuples ($N-1$ edges: `ordinal k-1` blocks `ordinal k`). Preflight runs before relation writes. Delegated Plan/Harden make zero provider calls while drafting. After `execution-plan.md` is written, perform drift comparison, bounded synchronization, stable-key mapping, and graph read-back; mirror failures are nonblocking.

## Drift and failure

Before either mirror save, compare fresh reads with the manifest baseline. Provider failures in mirror mode are recorded in `mirror.status` and never block local authority, artifact retention, or handoff.
