# GitHub publication context

This file owns how Plan finds its destination and what it must know about GitHub before it plans
or publishes. The [GitHub profile](../../woostack-init/references/artifact-providers/github.md#configuration-and-scope)
owns identities, native relationship operations, and API semantics; the
[GitHub publication procedure](github-procedure.md) owns the writes and the read-back.

## Resolving the destination

1. Establish `https://github.com/<owner>/<repo>` from the request and the actual context: the
   checkout's remote, a repository or issue the user named, an explicitly selected Project. Trusted
   Git and GitHub evidence only. Never choose by title, recent activity, search ranking, or an
   unrelated configured owner.
2. The destination follows the request. A goal in the current repository publishes there. An exact
   issue URL the user gave is either the destination or an existing increment, whichever the
   request says. An explicit `--project` URL is that Project, used as given.
3. Two plausible destinations, a foreign repository, an inaccessible one, or a Project the user
   did not name is a question for the user, not a guess. Ask before the first write; a
   planning-only request never needs the answer.
4. Preflight only the capabilities the request needs: issue read and write to file issues, plus
   native sub-issue and dependency read and write only when the request asks for those
   relationships. Prove each through the authorized capability. Issue-write access alone does not
   prove relation access; an unknown capability blocks only the operation that needs it.

## The issues that already exist

Read the issues that bear on the plan: those the user linked or the request names, the tracker or
parent issue a request continues, and a bounded search of the repository's own issues for the
topic. Paginate each query to its terminal page — a partial page is not an answer, and a read
error is not an empty result.

- Map increments to existing issues by exact identity — canonical URL, issue number, native ID —
  never by a similar title. One increment maps to one issue.
- Reuse keeps the issue's number, history, comments, labels, assignees, and links. Change only the
  parts that carry plan content; preserve the human writing around them. Material disagreement
  between the existing content and the plan is surfaced to the user, not overwritten.
- An existing native parent, sub-issue, or dependency link is evidence to record, not something to
  recreate. A link that contradicts the plan is a question for the user, not a repair.

## Evidence and limits

- State which repository and GitHub facts you observed and which are your inference. A repository
  fact never answers a user-owned decision.
- No local run, manifest, provider, Project configuration, or writable checkout is required to
  plan or to file issues. Retained records and earlier issues are
  [historical user data](../../woostack-init/references/artifact-backends.md#retained-data-and-retirement):
  read them as evidence, never migrate, adopt, or rewrite them.
- Never report a published issue or a written relationship as verified without the observed
  read-back that proves it.
