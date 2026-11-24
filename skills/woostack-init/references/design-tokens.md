# Design systems and tokens

Use when visual or interaction guidance is in scope, within Init's consultation and document-only
boundary. Token definitions in selected guidance may be authored or updated; changes to application
token files/consumers, generators, dependencies, or components remain implementation recommendations.
Preserve adequate guidance and an architecture-focused `DESIGN.md`; a project with no UI needs no tokens.

## Establish the source of truth

Inspect existing theme/token files, styles, component libraries, representative screens, approved
design references, and any catalog or design-tool exports. Identify authored sources, generated
outputs, consumers, supported platforms/modes, and actual synchronization commands. Ask only about
unresolved intent. Separate implemented choices, approved future direction, and proposals.

Keep one authored source for each token decision. Reuse an adequate CSS theme, typed theme object,
library, or token file; link it from `DESIGN.md` instead of maintaining a second table of raw values.
If `DESIGN.md` owns structured tokens, state how code consumes or derives from them and identify
any unimplemented connection. Do not present documented values as implemented tokens.

When no system exists, propose a small concrete set of names, values, and roles based on the agreed
visual direction. Confirm it through Init's consultation, record approved values as planned, and
leave unresolved choices explicit. Avoid a stock palette or arbitrary scale presented as extracted
fact. Existing library tokens can satisfy the contract without being copied locally.

Use the [visual document format](document-schemas.md#designmd) when applicable. Consider
[DTCG](https://www.designtokens.org/tr/2025.10/format/) for tool interchange or multiple platform
outputs, not as a prerequisite. Its stable 2025.10 JSON format is distinct from DESIGN.md YAML.
Verify installed tooling support before conversion; [Style Dictionary documents limits](https://styledictionary.com/info/dtcg/).
Do not introduce a generator or format migration merely to write guidance.

## Choose useful tokens

Preserve established names. Use semantic roles for decisions that vary by purpose or theme:
`color.action.primary.background` describes intent; a blue swatch alone does not.
Reuse a small primitive palette/scale where useful. Components consume semantic roles; introduce
component tokens only when a component needs an independent customization contract. A shared
spacing scale can be used directly without an alias for every gap. Equal values do not establish
equal roles, so do not merge tokens solely because their current values match.

Cover the families the actual interface needs; this is a coverage review, not a mandatory inventory:

| Family | Decisions to capture or link |
| --- | --- |
| Color | Canvas and surface layers; text/icons; borders; actions/links; selected, disabled, focus, and feedback roles. Pair foregrounds with their intended backgrounds, including text on actions. |
| Typography | Font families/fallbacks; text roles with size, weight, line height, and tracking where needed. |
| Spacing and layout | A coherent spacing scale, recurring gaps/insets, content widths, and responsive/container rules. Keep fluid expressions in a source that supports them. |
| Size and shape | Control and icon sizes, interaction targets, radii, and border widths. |
| Depth | Surface/elevation relationships, shadows, backdrops, and stacking order when overlays exist. |
| Motion | Purpose-based durations/easing and reduced-motion behavior when animation exists. |
| Domain-specific | Chart palettes, density, multiple brands, or other specialized decisions only where used. |

Make each authored token's name, type/unit, value or alias, purpose, and applicable mode discoverable.
Prefer aliases for shared decisions; preserve intentional local values such as zero, percentages,
and one-off calculations. Avoid unused tokens or a separate token for every component property.

Keep semantic names and roles stable across supported themes, with resolved values for every used
role. Record defaults, overrides, and how a mode is selected; naming groups `light` and `dark` does
not implement switching. Share intent across web/native platforms while documenting unit and
output mappings. Do not invent dark mode, density variants, or native outputs.

## Explain application in DESIGN.md

Keep the record concise: product character and concrete visual constraints; links to authoritative
tokens, components, and approved references; token usage and foreground/background pairings;
responsive behavior; and the maintenance path. Preserve rationale that code cannot establish.
Follow the applicable schema without forcing unsupported values into it or duplicating component APIs.

Document relevant default, hover, pressed, keyboard-focus, selected, disabled, invalid, and loading
states, plus empty/error behavior. States need deliberate behavior, not necessarily distinct tokens.
Include keyboard interaction, visible focus, text scaling, and reduced motion where relevant.
Tokens alone do not specify layout, hierarchy, content, or interaction; link representative examples
and the existing catalog.

## Maintain and verify

Record this maintenance path for design changes; Init performs only authorized guidance edits and
reports any required application work separately:

1. Reuse an existing role before adding a token. Add one for a repeated decision, necessary theme
   variation, or deliberate component contract. Preserve meaningful distinctions and remove stale
   guidance rather than appending another catalogue.
2. Edit the authored source, then update affected consumers, derived outputs, examples, and relevant
   guidance together. Record only existing regeneration commands. For renames/removals, find callers;
   update them directly unless real consumer commitments require deprecation or migration support.
3. Use existing validation to check types/units, missing or cyclic aliases, name/output collisions,
   mode coverage, and generated drift. Inspect touched styles for bypasses of an existing shared
   role; a blanket ban on literal values is unnecessary. Do not install tooling to validate prose.
4. When UI verification is authorized, inspect representative components/screens in supported modes
   and important states. Check actual foreground/background pairs, visible focus, target sizes,
   text scaling/reflow, and reduced motion. A valid token file does not prove accessible rendering.
   For a WCAG AA web target, verify [text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
   (4.5:1, or 3:1 for qualifying large text) and [meaningful non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast)
   (3:1 against adjacent colors), applying each criterion's scope and exceptions.
5. Distinguish source inspection, executed validation, and rendered observations. Report gaps without
   claiming implementation or accessibility compliance from prose. A rerun with unchanged evidence
   and scope should leave adequate guidance unchanged.

Design references: [Atlassian](https://atlassian.design/foundations/tokens/design-tokens),
[Primer](https://primer.style/product/primitives/token-names/), and
[Carbon](https://www.carbondesignsystem.com/building-blocks/foundations/themes/overview). No library is required.
