# Prototype quality

Use the relevant sections for interaction, platform, accessibility, and inspection decisions.
This reference supplies design checks, not another workflow, production-review requirement, or
permission to edit the target project. Scale checks to the question and reuse valid evidence.

## Compare against the baseline

For an existing product, investigate only the affected experience and its immediate dependencies,
not the whole repository. Read the relevant routes/entrypoints and owning components, state,
validation, permissions, side effects, cancellation and recovery behavior, existing tests/fixtures,
and reusable components/tokens. Record source revision and relevant local modifications where
available so the baseline does not imply a clean or different version. Use an existing preview if
accessible; never start or write to the target to fill an evidence gap. Label source facts, runtime
observations, and assumptions separately. Without runtime access, rendered and interaction claims
about the existing product remain unverified.

Keep a concise account of consequential behavior: what must be preserved, what intentionally changes,
what the prototype simulates, and what remains unresolved. Omitted behavior is not approved removal;
existing defects can be corrected when authorized. Trace only enough context to establish the change's
boundary, and carry unresolved consequential choices into the draft rather than deciding them through
mockup defaults. Greenfield work has no existing-product baseline to reconstruct.

Compare the existing product with the proposal throughout iteration so visual polish does not hide
lost behavior. Separately compare the previous and current prototype to assess each revision without
replacing the product baseline. Use matched states and sizes for meaningful visual comparisons when
available; capture screenshots selectively, not after every edit. Keep concise notes on consequential
behavior changes and exercise their affected paths, including relevant validation, permissions,
cancel, failure, and recovery. Screenshots do not prove those paths work. Reuse observations only
while their snapshot, state, environment, and affected behavior remain applicable; retrieve historical
captures only when they answer the current comparison question.

Carry baseline provenance and preserved/intentional differences into the handoff. Connect required
production acceptance to the owning surfaces and tests/fixtures actually discovered, separately from
checks exercised in the prototype. Where coverage is missing, describe the needed behavior check
without guessing a test path, command, or framework. This is acceptance context, not an implementation
plan or permission to run production checks.

## Follow the experience

Walk from entry through the primary task to an understandable result. Keep location, the next action,
and feedback apparent. Distinguish navigation from actions; account for back, cancel, edit, retry,
and recovery without avoidable loss of entered work. Choose only states that can change the design,
such as empty content, loading, no results, validation errors, failed saves, or success.

Use realistic synthetic text and data. Inspect long labels, dense content, expanded sections, and
relevant localization or directionality needs. Record consequential missing requirements rather than
quietly turning a convenient demo default into approved behavior. Demonstrate uncertainty with the
smallest useful prototype, not a production backend or exhaustive test suite.

## Preserve the platform

Use conventions of the intended surface rather than averaging web, mobile, and desktop behavior.
Consult current primary guidance when a live decision depends on it, such as
[Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
or [Android design guidance](https://developer.android.com/design/ui). Treat a design-system example
as an example, not a universal rule. Identify the intended platform and unsupported device-specific
behavior in the handoff; a browser simulation is not physical-device or native-control testing.

## Inspect accessible behavior

Use semantic controls with meaningful names, labels, and instructions. Exercise the relevant
keyboard path, visible focus, dialog entry/exit and focus return, validation feedback, and recovery.
Check contrast in actual rendered combinations, non-color state cues, usable targets, and supported
pointer/touch behavior. Motion should explain changes rather than obscure the task; inspect the
relevant reduced-motion behavior. An accessible component does not prove its composed screen works.

For precise requirements, name the applicable version, criterion, conformance level, exceptions,
and verification method from [WCAG](https://www.w3.org/TR/WCAG22/). Its
[Understanding documents](https://www.w3.org/WAI/WCAG22/Understanding/intro) are explanatory, not
additional normative requirements; techniques are examples, not mandatory implementations.
Do not invent a conformance target or treat platform advice as a WCAG requirement.

Text resizing and narrow-layout reflow are different observations. WCAG 2.2
[Resize Text](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html) addresses enlargement to
200% with stated exceptions; [Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html)
addresses an equivalent width of 320 CSS pixels for vertically scrolling content, also with
exceptions. Exercise applicable responsive variations rather than treating a desktop zoom check
as a mobile-layout exemption. Record actual viewport and zoom/text settings, clipping, lost controls,
and unexpected two-dimensional scrolling.

## Inspect visual craft

Judge hierarchy, typography, line lengths, grouping, alignment, spacing, density, surface treatment,
icons, and feedback against the brief and real content. Use deliberate choices appropriate to the
product, not repeated generic decoration or forced monochrome minimalism. For landing pages, inspect
the promise, supporting content, and action hierarchy; never fabricate testimonials or product claims.
Visual preference is not evidence of conversion, usability, or human authorship.

## Report what the evidence supports

| Evidence | What it can establish | What it cannot establish alone |
| --- | --- | --- |
| Source inspection | Intended structure and specified behavior | Rendered appearance or successful interaction |
| Screenshot/rendered inspection | Visible layout and state at that size | Keyboard access, motion, persistence, or all responsive states |
| Exercised browser interaction | The observed path in that environment | Native-device behavior, unexercised paths, or participant usability |
| Automated accessibility checks | The rules and scope actually checked | Complete accessibility conformance |
| Participant research | Observed task performance under the study conditions | Untested populations, contexts, or universal product success |

Keep findings reproducible: identify the snapshot, relevant size/input/state, expected and observed
behavior, and remaining limitation. Reading this guidance is not product evaluation or certification.
Carry necessary production acceptance into the handoff without running a later engineering review.
