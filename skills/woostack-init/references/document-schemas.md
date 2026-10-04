# Document schemas

Use the applicable formats below when authoring project guidance. These are document contracts,
not dependencies on another skill's interview, approval process, configuration, or sidecars.
Keep Woostack Init's evidence-first authoring workflow and requested write scope.

## Sources and versions

| Document | Canonical format | Verified baseline |
| --- | --- | --- |
| `PRODUCT.md` | [Impeccable product record](https://github.com/pbakaus/impeccable/blob/main/.agent/skills/impeccable/reference/init.md#step-4-write-productmd) | `impeccable:product-schema 1` |
| Visual `DESIGN.md` | [DESIGN.md specification](https://github.com/google-labs-code/design.md/blob/main/docs/spec.md) | `alpha` |
| `AGENTS.md` | [AGENTS.md convention](https://agents.md/) | Unversioned Markdown; no required fields |

The product baseline was checked against Impeccable revision
`6b9d0ffa3a9a884fc95928d2d2d896b0befa5d3e`; the design baseline against the linked specification.
Use an available installed canonical reference when it is newer. When asked for the latest format,
resolve the current upstream source before changing a schema marker or structure. If that source is
unreachable, disclose that latest compatibility is unverified and use the verified baseline only
where applicable. Never derive a schema version from a package version or downgrade an unfamiliar
newer marker. Report that conversion as unresolved; continue unrelated authorized document work.

Preserve existing authoritative paths, useful custom sections, frontmatter, scoped instructions,
and safe symlink relationships. Reconcile old headings with the applicable record rather than
appending a second specification. Do not stamp a file merely to silence a legacy warning: first
bring the requested content into the format. Missing facts remain explicit decisions or omissions,
not template filler. No extra skill installation, configuration, or generated token file is required.

## PRODUCT.md

Use the product-record marker immediately below the title:

```markdown
# Product

<!-- impeccable:product-schema 1 -->
```

Use these canonical `##` headings where relevant, retaining useful project-specific content:

| Heading | Evidence to record |
| --- | --- |
| Platform | Exactly one bare, unquoted value on its own line: `web`, `ios`, `android`, or `adaptive`. Put explanations in Operating Context, not on the platform line. Mobile web is `web`; a wrapper alone does not establish a native UI. |
| Stack | Confirmed greenfield stack choice or an explicitly delegated choice and rationale. Omit when an existing codebase already answers it. |
| Users | Confirmed audiences, their situation, and jobs. |
| Product Purpose | What the product does, why it exists, and agreed success criteria. |
| Positioning | A confirmed differentiator, not a generic promotional claim. |
| Operating Context | Actual workflows, environments, tools, and materials. |
| Capabilities and Constraints | Functionality, scope, non-goals, constraints, terminology, and marked open decisions. |
| Brand Commitments | Binding existing identity, voice, assets, or references; omit absent commitments. |
| Evidence on Hand | Real content, data, demonstrations, or assets with paths; note material absences that must not be fabricated. |
| Product Principles | Three to five durable strategic principles when supported by confirmed facts; no invented principles to meet a count. |
| Accessibility & Inclusion | Established product-specific user needs or required standards; omit when none are established. |

Omit irrelevant sections. Keep current scope distinct from future direction. Visual recipes and
workflow settings belong outside the product record; confirmed brand constraints belong here.

For a CLI, API, or skills library, do not mislabel the whole product `web` because it contains a
website. Omit an inapplicable Platform section and explain the applicability limit in the report.
Do not create a competing UI product record unless that scoped document was requested.

## DESIGN.md

Apply the visual format to a visual-design-system document, not an architecture document that
happens to share its name. Preserve an established system-design meaning and its canonical sources.
If a separate scoped visual record is needed, propose its owner rather than silently repurposing the
root document or creating another authority.

For a visual record, use these `##` sections in order, omitting inapplicable ones:

1. Overview (also accepted: Brand & Style)
2. Colors
3. Typography
4. Layout (also accepted: Layout & Spacing)
5. Elevation & Depth (also accepted: Elevation)
6. Shapes
7. Components
8. Do's and Don'ts

An optional document title is allowed. Avoid duplicate section headings; preserve useful unknown
sections. Record only observed or explicitly agreed tokens, components, and rationale.

YAML frontmatter is optional. When present, it starts the file between `---` delimiters and requires
`name`. Its optional `version` is currently `alpha`, not a numeric package version. Optional groups
are `colors`, `typography`, `rounded`, `spacing`, and `components`; metadata also allows
`description` and `omitted` (section names or objects with `section` and optional `reason`).

Use existing token names and values rather than inventing a default palette or scale:

- Colors accept any valid CSS color string; preserve existing formats. Hex is the specification's
  recommended default, not a migration requirement.
- Dimensions use `px`, `em`, or `rem`. Spacing also accepts numbers.
- Typography supports `fontFamily`, `fontSize`, numeric `fontWeight`, `lineHeight` (dimension or
  number), `letterSpacing`, `fontFeature`, and `fontVariation`.
- Component color properties accept colors, `typography` accepts a typography value, and `rounded`,
  `padding`, `size`, `height`, and `width` each accept one dimension. Token references use a single
  `{path.to.token}` value, never concatenated references. Composite references such as
  `{typography.body}` are allowed within components; other references target primitive values.
  Keep multi-value padding in source/prose instead of inventing a single schema dimension.

Tokens are normative; prose explains application rather than duplicating competing values.
Preserve extensions. Keep values not representable by the current token schema, such as responsive
expressions, in their canonical source and linked prose rather than coercing them into false tokens.
Do not add frontmatter merely to claim schema adoption when a prose-only record is sufficient.

## AGENTS.md

Keep ordinary Markdown with headings suited to the repository. There is no schema version marker,
required frontmatter, or mandatory heading inventory. Use actual commands and working directories,
verification conditions, boundaries, pitfalls, and contextual links. Preserve the repository and
host's instruction precedence and the scope of existing nested instructions. The operational and
Woostack-adoption rules remain in [document responsibilities](../SKILL.md#document-responsibilities).
