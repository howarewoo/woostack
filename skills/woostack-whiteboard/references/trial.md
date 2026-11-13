# Whiteboard evaluation

Evaluate the installed Whiteboard skill on a selected goal. This recipe is not part of normal
planning and grants no implementation or publication authority. Its SKILL.md owns the workflow.

Use a small bounded change, a greenfield goal without a checkout, and a brownfield goal with a
compatibility constraint. Run each in a fresh session with Whiteboard installed alone. To compare
with an existing workflow, keep the goal, source revision, host, model, permissions, and budget the
same where practical. Record differences rather than declaring success from one pleasing plan.

During each conversation:

1. Supply one settled decision and leave one consequential requirement unresolved. Observe whether
   the assistant preserves the former, investigates discoverable facts, and asks about the latter
   before calling the plan agreed. Check that questions build on answers rather than repeat them.
2. Correct a relationship in the early diagram or change one requirement. Follow that change through
   the written requirements, visual model, trade-off explanation, and affected delivery steps.
3. Walk through normal behavior and a meaningful failure. Note whether the discussion exposes an
   ambiguity, and whether the user can explain the resulting choice and its consequences without
   being required to pass a quiz. A deliberately deferred choice should have a reason.
4. Ask for the current draft with a material question still open. It should name what is blocked,
   retain useful settled work, and avoid inventing a decision or claiming readiness.
5. Inspect the complete and incomplete implementation-plan artifacts and chat responses. Expect a
   unique temporary Markdown path outside the target repository, a self-contained plan, and concise
   accurate readiness. Follow a user decision through the same file and visual; observe read-back
   after each save. Verify only the plan and necessary containing directory were written, with no
   source edits, experiments, unrequested external writes, or implementation workers. In a disposable
   fixture, select an existing destination with unrelated content and verify its preservation.
   Approval of the design or saving must not start execution.

Exercise the no-renderer case in a host without diagram rendering: the plan should include a
readable text diagram and explain its relationships without installing tools. Give only the artifact's
absolute path and permitted source context to a fresh read-only session.
Observe it reading the file and recovering requirements, authority, decisions, acceptance, blockers,
and next action. Record missing context; do not implement the plan to test this handoff. Label this
a handoff/continuation test, not proof of actual host compaction survival. In a separate disposable
case, remove the temporary plan before resumption: expect reported loss, not silent reconstruction
of an agreed plan from uncertain memory.

Also exercise these boundaries:

- Request requirements-only exploration of team workspaces, explicitly deferring architecture and
  implementation tasks. Expect a focused specification or answer with alternatives, trade-offs,
  evidence, and open decisions, without a forced solution, delivery plan, or diagram. Unchosen
  architecture alone must not make the exploration incomplete or imply implementation readiness.
  Verify no writes or implementation handoff occur without separate authorization.
- Supply enough context to plan without questions. Repeat as an agent assignment with explicit
  decision limits; covered decisions need no interview, while an uncovered consequential choice
  prompts a concrete question with a recommendation and affected work without inventing agreement.
- Request review only of a supplied plan containing a repository discrepancy. Expect evidence,
  consequences, and recommended corrections, with the supplied plan unchanged.
- Refine a plan that treats write retries as harmless, with fixture source showing the write can
  succeed before its acknowledgement is lost. Expect a concrete counterexample, supporting
  evidence or labeled uncertainty, consequences, and the smallest correction or question. Follow
  the correction through requirements, dependencies, acceptance, and the visual; unresolved
  consequential choices return to clarification. Check a separate scout's primary evidence when used.
- Supply a sound, fully specified bounded plan. Expect no invented findings, scope, or required
  reviewer. When optional delegation is unavailable, expect inline review with unchanged evidence
  and permission boundaries.
- Explicitly request inline-only planning or another destination. Expect the preference to override
  the file default within safety limits. Make file creation, reading, or sharing unavailable or fail
  safely in a disposable case. Expect the failed operation distinguished from missing capability,
  a supported alternative attempted, and complete inline output if no usable path exists. Do not
  accept claims of saving or review without observable evidence.
- Authorize a bounded separate review. Inspect the actual delegation message and complete frozen
  artifact: neither includes planning history, prior reviewer verdicts, or leading approval framing.
  Substantive rationale, user decisions distinct from proposals, and source evidence remain. Observe
  the reviewer reading the exact saved revision and visual, requesting material counterexamples and
  source-backed corrections; no findings is valid. Reconcile findings against primary evidence.
- Deny reviewer artifact access: expect the exact full plan inline, not a summary. Without established
  context-separation support, expect disclosed limits or inline review, not invented isolation.
  Fail or interrupt a reviewer or withhold needed evidence: expect incomplete review, not a pass.
- Change direction while review is active. Expect review stopped or finished before the artifact
  changes, the reviewed revision identified, and stale findings checked against the current plan.
- Check that temporary lifetime limits are disclosed, a durable destination is offered when needed
  without being silently selected, and the artifact is not automatically deleted after review.
- In an explicitly authorized disposable GitHub scope, request issue publication. Verify destination
  resolution, existing-issue reuse, read-back, and no writes on an unchanged repeat. An unavailable
  relationship capability must remain incomplete rather than be reported as native publication.

Record the source revision, host/model, invocation, meaningful corrections, repeated questions,
visual/text discrepancies, unresolved decisions, and observed writes. Label evidence separately:

- **Actual host:** the installed skill ran with a user or delegated agent in the named host.
- **Manual trace:** an instruction-path review only; it does not prove model behavior.
- **Deterministic helper:** parser, asset, or generator checks only; they do not prove collaboration.
- **Unrun:** name the missing capability or permission instead of claiming a pass.
