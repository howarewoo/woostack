# Technical documentation

Use this reference when the authorized work includes user-facing technical documentation, either
on its own or alongside code. Read it before planning the documentation changes. Apply the three
phases within the active workflow's scope, consultation, verification, and delivery rules; this
reference creates no separate workflow, approval, plan artifact, or publication authority.

## Planning

1. **Identify the reader and purpose.** Establish the audience, assumed knowledge, prerequisites,
   and what the reader should be able to do, find, or understand. Choose the page's primary purpose:

   | Type | Reader need | Shape |
   | --- | --- | --- |
   | Tutorial | Learn by doing | A complete lesson with a chosen path and visible progress. |
   | How-to guide | Complete a known task | An ordered procedure from stated prerequisites to a useful result. |
   | Reference | Look up an exact fact | Consistent entries for inputs, outputs, defaults, constraints, and behavior. |
   | Explanation | Understand a topic | Supported context, reasons, tradeoffs, and relationships. |

   Navigation pages may connect these types. Preserve required document schemas and existing
   information architecture; apply the writing rules where they serve the page's purpose.
2. **Read the technical evidence.** Inspect the relevant implementation, configuration, commands,
   existing documentation, and confirmed decisions. Identify the authoritative source for claims.
   Keep implemented behavior, agreed future direction, and unresolved questions distinct. Source
   code can establish behavior; it does not establish historical rationale by itself.
3. **Define the smallest useful change.** Select the existing pages or sections to update, outline
   the information order, and identify examples and links needed. Reuse settled decisions. Keep
   planning proportional to the task and within the active workflow's consultation rules.
4. **Choose acceptance evidence.** Decide which claims need source checks, which examples or reader
   paths need a safe walkthrough, and which existing link, format, or rendering checks apply.
   Resolve material gaps before writing claims that depend on them.

## Implementation

Apply these rules to the requested pages, adapting them to the selected type:

1. **Lead with the reader's goal.** State what the page enables and when it applies. Make titles
   and openings specific enough for the reader to recognize that they are in the right place.
2. **Follow the reader's questions.** Put necessary information in the order it becomes useful.
   In a task guide, give the shortest complete common path early, with setup before dependent steps.
3. **Use concrete examples.** Prefer small, realistic inputs and reuse one scenario through a
   tutorial. Include imports, setup, defined values, and working directories needed to use a code
   example. Clearly mark placeholders and intentionally partial snippets.
4. **Make results visible.** Show or describe meaningful outputs, confirmations, saved locations,
   and timing so readers can recognize success. Use checkpoints where they resolve uncertainty.
5. **Explain decisions.** Recommend a default where a choice is necessary and state when an
   alternative applies. Connect the recommendation to an observable consequence or supported
   tradeoff; teach reasoning the reader can reuse.
6. **Select useful technical detail.** Include a detail when it helps someone act, choose, predict
   behavior, or diagnose a problem. Preserve relevant defaults, permissions, limits, side effects,
   and conditions. Simplifying prose must preserve the product's actual behavior.
7. **Write plainly and precisely.** Use active voice, concrete verbs, and familiar words. Address
   the reader directly. Keep terminology consistent and match interface labels, commands, and API
   names exactly. Define unfamiliar terms when needed; remove filler and unsupported claims.
8. **Introduce one idea at a time.** Give each paragraph or step one main job. Establish basic
   behavior before adding variation, and explain how successive ideas connect.
9. **Keep the main path focused.** Use descriptive headings, numbered steps for sequences, bullets
   for parallel items, and tables for comparisons. Link to deeper explanations, alternatives, and
   reference material. Preserve canonical ownership rather than duplicating facts across pages.
10. **Place conditions at the point of use.** Put requirements and consequential caveats before or
    beside the affected instruction. State the triggering condition and the action to take; keep
    unrelated exceptions out of the main path.
11. **Cover common failures.** Use recognizable symptoms as troubleshooting headings. Explain how
    to check the likely cause, recover, and recognize the corrected result. Include the common
    failure path where it helps readers use the feature.

Edit authoritative content rather than generated output. Preserve useful existing material and
limit restructuring to the requested scope. Do not force a tutorial, running example, or generic
page template onto reference entries, explanations, project records, or agent instructions.

## Verification

12. **Verify as the intended reader.** Review from the stated starting point using only the
    documented prerequisites. Check that the reader can find the needed information, understand
    important conditions, recognize success, and recover from the common failure.

- Check technical claims, terminology, defaults, options, and example results against the current
  source. Distinguish observed results from illustrative examples and commands only inspected.
- Run changed examples or walk through a task where useful, safe, and authorized. Documentation
  work grants no permission for destructive actions, external writes, credentials, deployment, or
  unrelated setup. Report unavailable evidence and its effect on acceptance accurately.
- Check changed paths, links, anchors, and applicable schemas. Select existing checks under the
  active workflow and repository policy; ordinary prose edits need no new test harness or automatic
  production build. Use a rendering or build check when the change can affect that surface.
- Read the changed prose for clarity, information order, consistency, and unnecessary repetition.
  A build or link check alone does not establish factual accuracy or reader usability. Report the
  checks actually performed and unresolved criteria through the active workflow.

The writing principles draw on [Thinking in React](https://react.dev/learn/thinking-in-react),
[You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect), and
[Zod's Basic usage](https://zod.dev/basics). These are background examples, not runtime dependencies.
