---
name: woostack-ideate
description: Use as the ideate phase of the woostack build loop — turn a feature idea into an approved design through collaborative dialogue, then stop. Explores intent, constraints, and approaches; presents a design and gets explicit approval. Writes no files and chains no skill; the caller (woostack-build) owns the spec and plan. Usable standalone to design before implementation.
---

# woostack-ideate

Turn a feature idea into a fully formed, approved design through natural collaborative
dialogue. This is woostack's own ideation phase — the first step of
[`woostack-build`](../woostack-build/SKILL.md). It keeps the discipline that makes
ideation worth doing and **stops at an approved design**: it writes no spec file and
invokes no downstream skill. The caller decides what to do with the design.

<HARD-GATE>
Do NOT take any implementation action — write code, scaffold, run an implementation skill,
or write a spec/plan file — until you have presented a design and the user has approved it.
This applies to EVERY request regardless of perceived simplicity. The design can be short,
but you MUST present it and get approval.
</HARD-GATE>

## Anti-pattern: "this is too simple to need a design"

Every change goes through this. A config tweak, a one-function utility, a copy change — all
of them. "Simple" work is where unexamined assumptions waste the most effort. Scale the
design to the work (a few sentences for a truly small change), but present it and get
approval before moving on.

## Terminal state: approved design, handed back

The skill ends the moment the user approves the design. At that point:

- **Write nothing.** Do not create a spec file, a plan, or any artifact. The approved design
  lives in the conversation.
- **Chain nothing.** Do not invoke `writing-plans`, `woostack-execute`, or any implementation
  skill yourself.
- **Hand back.** State that the design is approved and name the next step:
  - Inside `woostack-build`: its **step 2** captures this design as a markdown spec under
    `.woostack/specs/`. Return control there.
  - Standalone: tell the user the design is ready to capture as a spec; offer
    to hand off to `woostack-build` starting at **step 2**, and stop.

This boundary is the whole point of owning the phase: the caller owns the spec write and the
plan, so this skill must not.

## Process

Work the steps in order. Ask **one question per message** so you never overwhelm.

1. **Explore project context.** Read the relevant files, docs, and recent commits before
   asking anything. In an existing codebase, learn the current structure and follow its
   patterns rather than proposing greenfield shapes.
2. **Check scope first.** If the request bundles multiple independent subsystems ("a platform
   with chat, billing, and analytics"), flag it immediately. Don't refine details of
   something that needs decomposing first — help split it into independent pieces, note how
   they relate and in what order to build them, then ideate on the first piece through the
   normal flow. Each piece gets its own design → spec → plan → implementation cycle.
3. **Ask clarifying questions.** One at a time. Multiple-choice when you can; open-ended is
   fine. Aim at purpose, constraints, and success criteria — not implementation trivia.
4. **Propose 2-3 approaches.** Present them conversationally with trade-offs. Lead with your
   recommendation and say why.
5. **Present the design in sections.** Scale each section to its complexity — a sentence or
   two when straightforward, up to a few hundred words when nuanced. Cover architecture,
   components, data flow, error handling, and testing as the work warrants. Ask after each
   section whether it looks right; go back and clarify when something doesn't fit.
6. **Get explicit approval.** The HARD GATE clears only on a clear yes. Then hand back per
   the terminal-state rules above.

## Design for isolation and clarity

- Break the system into small units that each have one clear purpose, communicate through
  well-defined interfaces, and can be understood and tested on their own.
- For each unit, be able to answer: what does it do, how do you use it, what does it depend
  on? If a consumer can't understand a unit without reading its internals, or you can't
  change the internals without breaking consumers, the boundaries need work.
- Smaller, well-bounded units are also easier to implement reliably. A file that's growing
  large is usually a signal it's doing too much.

## Working in existing codebases

- Explore the current structure before proposing changes; follow existing patterns.
- Where existing code in the path of the work has real problems (a too-large file, tangled
  responsibilities, unclear boundaries), fold targeted improvements into the design — the way
  a good developer improves code they're already touching.
- Don't propose unrelated refactoring. Stay focused on what serves this goal.

## Visual treatment, on demand

This skill does not run a browser companion. When a question is genuinely visual — a layout,
wireframe, side-by-side comparison, or architecture diagram the user would grasp faster by
seeing than reading — offer to render it with
[`woostack-visualize`](../woostack-visualize/SKILL.md) (pick the audience that fits) and
continue. Keep conceptual and requirements questions in the terminal; a UI topic is not
automatically a visual question.

## Key principles

- **One question at a time.** Don't stack questions in a single message.
- **Multiple choice preferred.** Easier to answer than open-ended when the options are clear.
- **YAGNI ruthlessly.** Cut unnecessary features from every design.
- **Explore alternatives.** Always weigh 2-3 approaches before settling.
- **Incremental validation.** Present, get approval, then move on.
- **Be flexible.** Go back and clarify whenever something stops making sense.

## Hard constraints

- **Stop at an approved design.** Never write a spec/plan file or chain a downstream skill —
  the caller owns those. Handing back is the terminal state.
- **Respect the gate.** No implementation action of any kind before the user approves.
- **No bespoke visual server.** Defer visual treatment to `woostack-visualize`.
