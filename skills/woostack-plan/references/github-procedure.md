# GitHub publication procedure

This is Plan's only write path, and it runs only when the request authorized filing issues. The
[GitHub publication context](github-context.md) owns destination resolution and the existing
issues; the [GitHub profile](../../woostack-init/references/artifact-providers/github.md#configuration-and-scope)
owns native identities, relationship operations, and API semantics. Plan changes no source, branch,
worktree, commit, PR, review, merge, or issue lifecycle here.

## Before the first write

1. Confirm that the request authorized publication, that the destination is the one resolved from
   context, and that the content is appropriate for its actual visibility. Do not add a second
   approval event to a request to file issues; ask if visibility or a material decision conflicts
   with what the user requested.
2. Confirm each increment's content and that every command or path it names exists at the current
   tip or is created by that increment or one of its prerequisites. A named command that does not
   exist blocks the write.
3. Re-read the issues being reused or edited immediately before writing, and preserve everything
   the plan does not own: human paragraphs, comments, labels, assignees, history, and unrelated
   links.
4. For each new issue, preallocate a distinct UUID and retain it with the intended repository,
   title, and body before calling create. Include `<!-- woostack-issue-create:<UUID> -->` in that
   body's content; prove the marker absent from the complete open/closed scope before creating. If
   the intent cannot be retained across an uncertain response, stop rather than guess on resume.

## Order of operations

1. **Issues.** One issue per increment — reuse the exact existing issue where the context found
   one, create only what is missing, and write the increment's outcome, constraints, acceptance,
   and prerequisites into it.
2. **Relationships.** Add only the relationships the request asked for: a native sub-issue link
   into a parent or tracker issue, and `blocked-by` edges for declared prerequisites. Normalize a
   prerequisite as `[prerequisite, dependent]`, with both endpoints inside the exact repository.
   Write only declared edges — adjacency in the plan creates no edge — and never reparent,
   flatten, detach, or widen an existing issue.
3. **Read-back.** Independently read back every issue's actual content and identity, and each
   relationship from both sides. A mutation response is not a read-back, and a read-back that was
   not observed is not verification.
4. **Explicit Project.** An explicit `--project` selection adds the published issues to that
   Project and reads membership back. It never creates a Project and never changes Status,
   lifecycle, or acceptance.

## Uncertain outcomes

- A create whose response was lost is not re-created. Search the exact repository's open and closed
  issues to the end of the relevant query for the retained create identity. Bind only one issue whose
  independently read identity, title, body, and repository match the retained intent. Zero or
  multiple matches, missing retained intent, or mismatched content block recovery; title and plan
  content alone never establish ownership. Do not allocate a replacement or repeat the create.
- A link or membership write whose outcome is unknown is rediscovered from both sides before any
  retry.
- Keep every confirmed identity and the last verified boundary across a failure. Report the
  confirmed objects together with what is still missing, and never describe a partial publication
  as complete.
- An unchanged plan whose issues and relationships were already verified performs no writes.

## When a relationship capability is missing

If the host cannot write a requested native sub-issue or dependency link, keep the issues you
wrote and an explicit readable index — the parent or tracker body, or the published plan — that
enumerates them with their declared prerequisites. Report the missing relationships and say the
requested native graph is incomplete. That index helps a later reader find the work; it is never
evidence that the native links exist.
