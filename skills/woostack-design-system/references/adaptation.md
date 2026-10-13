# Adaptation and recreation

Use repository-owned placement and dependencies under canonical Execute
[patterns](../../woostack-execute/references/patterns.md). No Execute invocation, Git operation,
Woostack configuration, hosted registry or Git Stacks installation is necessary.

## Versioned installed inputs

Read the installed [template instructions](../templates/README.md) and canonical
[baseline inventory](../templates/src/inventory.json.template). Application and configuration
sources are non-runnable `.template` assets. Resolve this directory relative to the installed
skill's `SKILL.md`; do not assume a checkout, a host-specific absolute path, or network access to
Woostack source. Preserve shipped license notices and baseline source revision/provenance.

Use the [shadcn component documentation](https://ui.shadcn.com/docs/components) as the canonical
upstream component guidance rather than maintaining a copied documentation inventory. The shipped
inventory owns versioned baseline IDs, specimen/import requirements and source provenance for
reproducible coverage; it is not a mirror of the upstream documentation. Do not repeat its coverage
in a second assertion list or shrink it to easy components. Keep project extensions separately
identified and never count extensions as missing upstream coverage. The shipped assets are a minimal
catalog scaffold, not a copied shadcn UI library. Obtain newly needed controls through the current
shadcn CLI's Base UI approach; reference-owned API adaptations are not advertised as upstream
defaults. CLI sourcing requires network access during creation, not at catalog runtime.

## Recreate safely

1. Inspect target placement, existing catalogs and UI using [compatibility](compatibility.md).
   If an existing catalog has no explicit maintenance request, report without writes and do not
   proceed. For creation, choose the actual catalog owner and record public components/tokens to
   reuse before copying anything.
   Before any directory creation, write or generator invocation, apply canonical
   [initial-scaffold target admission](../../woostack-execute/SKILL.md#initial-project-scaffold)
   to the intended physical target and parent, including symlink, ownership and collision safety;
   existing-repository destinations use that guidance's workspace-preservation boundary. This
   matters equally for isolated catalogs. Reading the guidance invokes neither Execute nor publication.
2. Read the installed template tree and destination files. Create only authorized missing files.
   Copy the tree into the selected catalog unit, stripping only each terminal `.template` suffix;
   preserve directory structure and source contents. There are no token-substitution placeholders.
   Copy supporting notices/instructions where needed for target ownership. Never overwrite an
   existing destination. The scaffold supplies catalog-specific source, not bundled component
   implementations; do not treat copying it as a runnable completed catalog.
3. Adapt public import locations, alias/build configuration, manifest name, paths and documented
   commands to native project conventions. The starter imports UI through `@/components/ui/*`;
   this is a starter location, not a mandated new package or project API. For compatible UI,
   rewrite specimens and chrome to real exported APIs, including state/composition differences.
   Keep the copyable adoption example and live specimen derived from the same source after editing.
   Determine missing controls from the canonical inventory and actual catalog imports after
   mapping compatible project components. Follow the installed template instructions: the shipped
   `components.json.template` already configures neutral Base UI (`base-nova`), so do not run CLI
   initialization over the instantiated scaffold. After selecting/installing dependencies, use the
   current shadcn CLI to add only missing inventory-selected components. Derive registry selections
   from the inventory's `entries[].registryItem`, filtering nulls and deduplicating; null entries are
   owned catalog helpers/foundations, not missing registry items. For a wholly new catalog, the
   configured scaffold supports the package-manager equivalent of:

   ```sh
   npm exec -- shadcn add --yes <inventory-derived missing registry items>
   ```

   Resolve the CLI selection from the authoritative registry; this example is a command shape, not
   a pinned dependency. Do not execute the angle-bracket text literally or duplicate the inventory
   into a handwritten component list. Inspect CLI help/configuration and planned destinations first;
   never run initialization over custom configuration or use overwrite flags on existing UI.
   For a fully compatible UI owner, reuse its existing setup without CLI initialization. For partial
   reuse, add only genuinely missing controls; if CLI cannot preserve an existing owner, generate in
   a disposable staging unit and integrate only authorized missing source/dependencies deliberately.
   Inspect generated public APIs and adapt catalog callers to the selected source rather than
   assuming the CLI output still matches the versioned specimens. Record CLI/source selections and
   preserve upstream notices. Do not fetch Git Stacks as a component installation dependency.
4. Preserve project design rules and tokens. Map semantic colors, theme selection, typography,
   spacing, radii, focus and motion consistently in chrome and specimens. Reuse real public
   stylesheets and configuration where compatible. Without project rules, retain the neutral
   shadcn baseline. Remove remaining Git branding/domain assumptions without replacing them with
   a new imposed identity. Include colors/tokens, typography, typeset content and iconography.
5. Inspect the template manifest and actual source imports; apply canonical
   [dependency resolution, ownership and integrity](../../woostack-execute/references/patterns.md#6-dependencies-resolution-ownership-and-integrity).
   Materialize exact selections and the target package manager's lockfile; a template range is
   not registry evidence. Do not install app dependencies in the skill distribution. An isolated
   catalog's own manifest owns React and UI runtime dependencies, not the product manifest.
6. Retain template/baseline version and upstream URLs/revision in the owned catalog. Record which
   public UI imports are project adaptations versus newly created upstream-based controls, any
   genuine compatibility pins, extension provenance, and the target's native development, build
   and verification commands. Explain ownership: targets can edit catalog source without Woostack
   or Git Stacks at runtime. The starter supplies `dev`, `build` and `verify` scripts; adjust only
   where native conventions require it, then exercise the actual resulting commands.
7. Complete and verify every required live specimen/state and the real navigation/interaction
   surface under [verification](verification.md). Source extraction is not completion. Do not
   replace missing imports with mocks, disabled examples, generic placeholders or no-op fallbacks.

## Scoped updates are not regeneration

For an explicit add, repair or update, compare the requested surface, current owned source and
relevant versioned assets before editing. Use a focused patch at the existing owner, not whole-tree
replacement. Preserve custom specimen content, stable links and design rules. Report a conflict
rather than changing an incompatible shared API, silently rebranding tokens or overwriting edited
components. Updating template provenance does not imply migrating the whole baseline.
