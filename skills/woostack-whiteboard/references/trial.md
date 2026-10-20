# Whiteboard trial

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
5. Verify no source edits, experiments, external writes, or implementation workers appeared. In a
   disposable fixture, explicitly request a save to a named file; inspect that only the selected
   document changed. Approval of the design or saving must not start execution.

Exercise the no-renderer case in a host without diagram rendering: the plan should include a
readable text diagram and explain its relationships without installing tools. Give only the final
plan to a fresh read-only session and ask it to explain the requirements, decisions, acceptance,
and dependencies. Record missing context; do not implement the plan to test this handoff.

Record the source revision, host/model, invocation, meaningful corrections, repeated questions,
visual/text discrepancies, unresolved decisions, and observed writes. Label evidence separately:

- **Actual host:** the installed skill ran with a user in the named host.
- **Manual trace:** an instruction-path review only; it does not prove model behavior.
- **Deterministic helper:** parser, asset, or generator checks only; they do not prove collaboration.
- **Unrun:** name the missing capability or permission instead of claiming a pass.

Retirement of Ideate, Harden, or Plan is a separate change after reviewing trial evidence. In
particular, account for Plan's issue-publication capability before retiring it.
