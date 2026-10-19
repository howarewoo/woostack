# Adaptation and creation

Use repository-owned placement and dependencies under the bundled
[patterns](patterns.md). No other skill invocation, Git operation,
Woostack configuration, hosted registry or Git Stacks installation is necessary.

This skill ships no starter tree, component source, or frozen inventory. A catalog is never
copied or generated from embedded assets: its source is created in the target repository from
inspection, compatible reuse, and current upstream shadcn sourcing. Reusing or reproducing the
catalog of a previous target as a substitute scaffold is prohibited; prior summaries or
transcripts are not component inputs.

## Agree the coverage

Apply [compatibility](compatibility.md) before deciding anything. When the requester's
instruction, repository evidence, and existing design rules do not already determine them,
settle the material creation choices during creation: the catalog unit and repository-native
placement, which components, groups and states the catalog covers, and the styling baseline when
no design rules exist. Derive a focused coverage proposal from the repository's actual UI usage
and ordinary component needs; ask only focused questions the repository cannot answer. There is
no mandatory questionnaire, no deferred repository-answerable question, and no requirement to
mirror full upstream documentation coverage in one pass.

Record the agreed coverage in a coverage record the target owns — for example the catalog README
or a credentials-free coverage notes file in the catalog unit — with, per entry: identifier,
import path or owner, specimen location, source provenance (URL and revision/date of the current
upstream item, or the reused project control), and `coverage: upstream | extension | gap`.
Extensions are separate from upstream entries and are never counted as missing upstream
coverage; never present a focused agreed subset as exhaustive upstream coverage. The target may
edit this record and the catalog source later without this skill.

## Inspect, reuse, and choose placement

1. Inspect actual imports, props, composition, style setup and dependencies. Prefer the smallest
   supported integration: a matching existing catalog application or route is the first choice —
   extend it in place rather than creating a parallel catalog. Creation by this skill starts
   only where no reusable live catalog surface exists.
2. Before any directory creation, write, or generator invocation, apply the bundled
   [initial-scaffold target admission](scaffold.md)
   to the intended physical target and parent, including symlink, ownership and collision safety;
   its workspace-preservation boundary covers existing-repository destinations. This
   matters equally for isolated catalogs. Reading the guidance invokes neither another skill nor
   publication.

## Source from current upstream

3. For each newly needed control or example, source from the current upstream at creation time.
   Where the target (or the newly created catalog unit) has shadcn configuration, prefer the
   current Base UI-backed shadcn CLI over the live component pages and registry (see below).
   Elsewhere, fetch the current registry item or adapt the current component documentation
   example. Never source from a pinned/cached copy, a checked-in mirror, a Woostack checkout, Git
   Stacks, or source embedded in this skill, nor run CLI initialization over custom setup or use
   overwrite flags on existing UI.
4. Adapt sourced examples to the target's real public APIs, including state and composition
   differences; describe project adaptations as owned catalog callers, not upstream defaults.
   Record provenance in the coverage record. Sourced upstream items keep their upstream license
   terms: preserve the applicable copyright/permission notices at ingestion — a catalog-level
   notice entry or per-file header, whichever the target's convention dictates — and list
   it in the coverage record; a provenance URL or revision is not a license notice. Maintenance
   additions travel with the same notice preservation. Sourcing may need registry/CLI network
   access during creation; the finished catalog must run without that access, Woostack, or Git
   Stacks.

## Build only the necessary catalog layer

5. Create in the target only what a live internal catalog needs: the catalog unit/app surface,
   navigation and search chrome, theme handling, and live specimen pages rendering real
   interaction code. Choose the repository-native structure; do not add shared packages,
   generators, or adapters the catalog does not use, and no substitute scaffold, generator, or
   embedded source dump. Catalog chrome is a consumer of compatible project controls per
   [compatibility](compatibility.md); do not duplicate controls that exist there.
6. Respect project tokens, typography and design rules. Map semantic colors, theme selection,
   radii, focus and motion consistently in chrome and specimens, reusing real public stylesheets
   and configuration where compatible. Without project rules, retain the neutral shadcn Base UI
   baseline; do not impose Git Stacks, Quiet Workbench or any other imported identity. Specimens
   render live behavior only: no code snippets, copy controls, or separate usage-example docs.
7. Materialize selected dependency versions and the target package manager's lockfile under
   [dependency resolution, ownership and integrity](patterns.md#6-dependencies-resolution-ownership-and-integrity).
   An isolated catalog unit's own manifest owns React and UI runtime dependencies, not the
   product manifest. For incompatible or non-React products follow
   [compatibility](compatibility.md#choose-the-smallest-supported-integration): an isolated
   React catalog leaves the product's source, manifests and behavior unchanged.
8. Record the target's native development, build and verification commands (adapt names only
   where native conventions require it), then exercise the actual resulting commands. Explain
   ownership: the target edits catalog source without Woostack, Git Stacks, or remote component
   documentation at runtime. Complete and verify every required live specimen/state and the real
   navigation/interaction surface under [verification](verification.md). Source extraction is
   not completion; do not replace missing imports with mocks, disabled examples, generic
   placeholders or no-op fallbacks.

## Scoped updates are not regeneration

For an explicit add, repair or update, compare the requested surface, current owned source and
the target's coverage record before editing. Source any newly needed items from the current
upstream at that time. Use a focused patch at the existing owner, not whole-tree replacement.
Preserve custom specimen content, stable links and design rules. Report a conflict rather than
changing an incompatible shared API, silently rebranding tokens or overwriting edited
components. Refreshing provenance or coverage entries does not imply regenerating the rest of
the catalog.
