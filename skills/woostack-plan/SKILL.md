---
name: woostack-plan
description: Turn a goal or partial issue into a coherent plan of reviewable increments, and file GitHub issues when the request asks for it. Read-only otherwise; never implements or merges.
---

# woostack-plan

`woostack-plan` is the complete planning workflow and the only skill that publishes GitHub issues
directly. It inspects the relevant source, settles the decisions that actually change the outcome,
produces a coherent plan of reviewable increments, and files that plan as issues when the request
asks for it. An ordinary goal or a partial issue is enough input: no template, no prior phase, and
no extra approval event are required. Plan never implements, executes, or merges.

## Command

```text
/woostack-plan <goal-or-partial-issue>
/woostack-plan <goal-or-partial-issue> --project <exact canonical GitHub Project URL>
```

`--project` is the one explicit destination selector, for a plan the user wants tracked in an
existing Project. Without it, the destination comes from the request and the actual context.

## Workflow

1. **Resolve the request and relevant context.** Read the goal or partial issue, the current
   checkout and its remote, and any issue or Project the user named. Planning-only can proceed
   without a GitHub destination. Before publication, resolve one authorized repository and
   destination; if more than one is plausible, ask instead of choosing. Never select by title,
   recent activity, repository convention, or an unchosen configured default. The
   [GitHub publication context](references/github-context.md) owns that resolution.
2. **Inspect the relevant source.** Read the bounded files, tests, configuration, and documentation
   that bear on the change, plus the issues already open for it. Verified schemas, interfaces,
   commands, and existing conventions are observations you can build on. A handful of relevant
   files answer most questions; a full-repository reread before every decision is waste, not
   diligence.
   While reading, check whether existing behavior, reuse, or a safe deletion already covers the
   request before proposing additions, under the
   [least-code doctrine](../woostack-bootstrap/references/patterns.md#7-least-code--comments).
3. **Identify meaningful unresolved decisions.** Ask only about decisions that change the outcome:
   product behavior, breaking compatibility, security or data boundaries, irreversible effects,
   cost, and scope. Fill in routine technical details consistent with the requested outcome, and say
   which ones you filled in. Never invent an approval ceremony, never re-ask a decision the user
   already made, and never silently override an explicit user choice.
4. **Produce a coherent plan.** The fewest independently reviewable increments that deliver the
   outcome, each meant to become one PR. A goal that fits one PR is a one-issue plan. Report the
   plan in the conversation; the user decides what happens next.
5. **File the issues when the request asks for it.** "File issues", "create GitHub issues", and
   "publish this plan" are the publication authorization themselves — do not require a separate
   approval event. A planning-only request writes nothing and returns the plan. The
   [GitHub publication procedure](references/github-procedure.md) owns the writes and the read-back.

## What an issue carries

Each issue states the outcome it delivers, the constraints that matter, what is out of scope, the
acceptance and verification expectations that define done, and its real prerequisites. That is the
floor, not a fixed template: no task keys, ordinals, marker blocks, parent-selection policy, or
required section order. Name repository files, symbols, and interfaces the increment touches so a
fresh reader can find them, and link the constraints that already have an owner instead of copying
them:

- an increment that crosses an application boundary follows the
  [application-boundary adapters rule](../woostack-bootstrap/references/patterns.md#3-application-boundary-adapters);
- an increment that adds or strengthens tests states the observable contract and points at the
  [Execute testing guidance](../woostack-execute/references/tdd.md).

Verify any command or path you name before putting it in an issue — it must exist in the repository
or be created by that increment or one of its prerequisites. Planning records expectations; it does
not run them or claim they pass.

## Publishing and read-back

Publication reuses the existing issue for an increment when there is one, creates the missing
issues, and adds only the relationships the request asked for. After every write, read the affected
issues back independently and confirm their actual content and their actual relationships; the
mutation response alone proves nothing. A create whose response was lost is rediscovered by exact
identity in the exact repository, never by creating a second copy blind.

Use the host's authorized GitHub capability — native tools when suitable, host-authenticated `gh`
otherwise — under the [GitHub profile](../woostack-init/references/artifact-providers/github.md#configuration-and-scope).
Never read credentials, forward tokens, or add a custom transport.

If the host cannot create a native sub-issue or dependency link, keep the issues you wrote and a
readable index of them with their declared prerequisites, and report the missing relationships. An
explicitly required native graph that was not created is incomplete, and Plan says so instead of
calling it published. An explicit Project selection adds membership for the published issues; it
never creates a Project, and no Status, lifecycle, or acceptance change happens without its own
request.

## Boundaries

Planning stays read-only except for the issue publication the request authorized. Plan edits no
implementation source, creates no branch, worktree, commit, or PR, dispatches no Execute or
Orchestrate work, and merges nothing. It preserves human content, existing issue identity, and
unrelated issues, labels, and history: it edits the parts of an issue that carry the plan and leaves
the rest alone. It never closes, reopens, or reassigns anything, and it never claims implementation,
delivery, passing checks, product acceptance, or merge.

## Return

Return the plan — increments, outcomes, constraints, acceptance, and real prerequisites — with the
repository and destination you resolved, the source you inspected, the decisions you filled in, and
any question still open. After a publication, add the actual issue URLs, what you reused versus
created, the read-back result, the relationships you wrote, and anything still missing. An
orchestration hint, when the user wants one, is a separate suggestion:

```text
/woostack-orchestrate --issue <verified canonical issue or tracker URL>
/woostack-orchestrate --project <verified canonical Project URL>
```

The hint is not a dispatch. Orchestrate does its own reading and ordering from the issues it finds.
