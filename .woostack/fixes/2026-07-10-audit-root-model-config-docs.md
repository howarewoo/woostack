---
type: fix
status: in-review
branch: fix/audit-root-model-config-docs
---

# Fix: Align audit and documentation with root model tiers

## 1. Root Cause

The repository's canonical consumer configuration stores model tiers in the root `models` object. The init template, doctor checks, review loader, review tests, OMP agent generator, and shared model-tier reference all use `models.<tier>` or `models.<provider>.<tier>` beside consumer namespaces such as `review` and `audit`.

`woostack-audit` predates the root-model migration. Its loader still extracts only the `audit` object, accepts `audit.models`, and writes that nested object to its generated config. A root `models` object therefore disappears on the audit path. The audit skill documents the stale nested form because its configuration list treats `models` as an audit-local key.

The authored configuration page has related drift. It omits the `audit` namespace and audit settings, describes the three-key init template as having two keys, calls an example complete while omitting `audit`, and overstates review's responsibility for validating settings owned by other consumers. The memory reference also omits the template's `status` block from its configuration skeleton.

Focused probes confirmed the mismatch: root `models.openai.standard` produced an empty audit model object, while nested `audit.models.openai.standard` was copied. Existing focused suites passed because review, audit, OMP, doctor, and site generation each test their own surface without asserting the shared root-model contract across consumers.

Current tracked files affected:

- `skills/woostack-audit/scripts/load-audit-config.sh`
- `skills/woostack-audit/scripts/tests/test-load-audit-config.sh`
- `skills/woostack-audit/SKILL.md`
- `site/content/docs/configuration.mdx`
- `site/scripts/gen-skills.test.mjs`
- `skills/woostack-init/references/memory.md`

Generated `site/content/docs/skills/woostack-audit.mdx` must not be hand-edited or committed. It is regenerated from `skills/woostack-audit/SKILL.md`. Historical specs, plans, and fixes must remain unchanged because they accurately record the schema at the time.

## 2. Proposed Fix

Make the audit consumer follow the existing shared configuration contract instead of documenting a second model schema:

1. Update the audit loader to retain the parsed root object, read audit-specific settings from root `audit`, and read model tiers from root `models`.
2. Remove `models` from the audit-local key set. Reject `audit.models` with an actionable message that directs users to root `models`; do not add a compatibility shim.
3. Add audit-loader coverage for root provider tiers, flat root tiers, coexistence with audit settings, and rejection of nested `audit.models`.
4. Correct the audit skill to separate the `audit` namespace from shared root model overrides and link to the canonical model-tier reference.
5. Correct the authored configuration page so its namespace inventory, complete example, audit section, model consumers, template description, and validation ownership match the current parsers and init template.
6. Update the memory reference skeleton to include the template's `status.staleDays` setting while keeping `models` at the root.
7. Add a focused generated-documentation lockstep test that reads the real init template and checks the changed authored sources and generated audit page against the shared root-model contract.

This is a clean cutover. The fix must not move `models` under `review`, preserve `audit.models`, duplicate the canonical model-tier table, edit generated skill pages directly, or rewrite historical artifacts.

## 3. Implementation Plan

- [x] **Step 1: Reproduce the audit and documentation drift with failing tests**
  - Extend `skills/woostack-audit/scripts/tests/test-load-audit-config.sh` with cases proving that root provider and flat tiers survive audit config generation, root models coexist with audit settings, and nested `audit.models` fails with relocation guidance.
  - Add `model configuration docs follow the root models contract` to `site/scripts/gen-skills.test.mjs`. Read the real init template, parse the complete JSON example from `configuration.mdx`, render the audit skill through `parseFrontmatter` and `renderPage`, and assert that the public configuration page, rendered audit page, and memory reference agree on root `models`, the separate `audit` namespace, and all three scaffolded keys.
  - Run `bash skills/woostack-audit/scripts/tests/test-load-audit-config.sh` and `node --test site/scripts/gen-skills.test.mjs`; record the expected pre-fix failures.

- [x] **Step 2: Apply the minimal audit loader fix**
  - Preserve the full parsed root config in `skills/woostack-audit/scripts/load-audit-config.sh`.
  - Continue validating audit-specific settings from root `audit`, but source emitted model tiers from root `models`.
  - Remove `models` from audit-local valid keys and reject nested `audit.models` with an error that names the valid root location.
  - Re-run the audit loader test and confirm all new and existing cases pass.

- [x] **Step 3: Correct every current authored documentation source**
  - Update `skills/woostack-audit/SKILL.md` to list only audit-local settings under `audit` and link shared model overrides to `skills/using-woostack/references/model-tiers.md`.
  - Update `site/content/docs/configuration.mdx` to include the `audit` namespace and settings, show root `models` beside `audit`, name audit as a root-model consumer, match the real three-key scaffolded template, and describe validation by each owning skill.
  - Update `skills/woostack-init/references/memory.md` so its skeleton matches the init template, including `status.staleDays: 14`.
  - Do not edit generated per-skill MDX or historical `.woostack` records.

- [x] **Step 4: Verify runtime and documentation contracts**
  - Run `bash skills/woostack-audit/scripts/tests/test-load-audit-config.sh`.
  - Run `node --test site/scripts/gen-skills.test.mjs`.
  - Run `bash skills/woostack-review/scripts/tests/test-load-config-models-root.sh`, `bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`, `bash skills/woostack-doctor/scripts/tests/test-review-models-moved.sh`, and `bash skills/woostack-init/scripts/tests/test-omp-lockstep.sh`.
  - Run `pnpm -C site build` to regenerate per-skill pages and validate links, MDX, and the authored configuration page without committing generated pages.
  - Confirm the diff contains no hand-edited generated skill page and no changes to historical specs, plans, or fixes.
