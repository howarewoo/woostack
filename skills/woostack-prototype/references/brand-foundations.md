# Brand foundations for prototypes

Read when establishing a visual direction, translating supplied branding into UI, or resolving a
material mismatch with existing foundations. Reuse established decisions for small refinements.
This reference does not authorize a rebrand, canonical token changes, or design-system maintenance.

## Start with what exists

Inspect approved identity, logos, typography, assets, tokens, components, themes, and representative
screens read-only. Separate authoritative sources from observed inconsistencies and proposals.
Preserve useful platform conventions and the product's meaning, not just its colors.

Where the brief leaves identity open, propose a few principles tied to audience, task, content,
and product character. Prefer coherent hierarchy and deliberate choices over generic AI styling;
clean and modern does not mean every product must be minimal or monochrome. Explore alternatives
only when they resolve a real choice. Material brand changes require the appropriate decision.

## Translate identity into a small foundation

| Layer | Prototype decision | Handoff evidence |
| --- | --- | --- |
| Identity | Appropriate logo, typography, imagery, and voice | Approved sources, proposed exceptions, and asset provenance |
| UI roles | Text/surface/action/feedback colors, spacing, shape, elevation, and motion | Existing token mappings or clearly proposed local choices |
| Components | Structure, content, relevant states, and interaction | Production component mappings and known approximations |

Keep system feedback distinguishable when brand colors resemble error or success colors. Consider
supported themes and actual text/background combinations. Pilot the smallest foundation on the
representative flow; do not build an exhaustive catalog or cross-channel brand kit.

Use existing token names and component APIs when practical. Primitive, semantic, and component layers
are optional organization, not a required hierarchy in the
[Design Tokens Community Group format](https://www.designtokens.org/tr/2025.10/format/).
That specification concerns exchange; it does not require adopting token tooling for a prototype.
Prototype-local decisions must not be presented as changes already made to the product's system.

## Make the reference reproducible

Record the assets or authorized retrieval references, their sources and relevant usage restrictions,
component/token mappings, supported modes, and important responsive behavior. Inspect the actual
rendering; identify fallback fonts, substitute imagery, or approximate components rather than claiming
fidelity that was not observed. Do not redistribute restricted assets, private source, or credentials.

Keep the approved snapshot distinguishable from later variants. Durable ownership, contribution
processes, releases, migrations, and implementation maintenance belong to separate product work,
not this prototype's deliverable.
