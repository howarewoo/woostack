---
type: fix
status: executing
branch: fix/omp-built-in-roles
---

# Fix: Use OMP built-in roles instead of generated agents

## 1. Root Cause

Woostack currently treats OMP as an agent-by-tier host because the older public `task` contract exposed an `agent` selector but no model selector. `skills/woostack-init/scripts/gen-omp-agents.sh` bridges that gap by reading `.woostack/config.json` `models.<tier>` values and generating `.omp/agents/woostack-{fast,standard,deep}.md`; init, doctor, host guidance, review fallback behavior, tests, and the docs site preserve that generated-agent lifecycle.

That compatibility layer is now the deficient behavior. The user requires OMP to own model selection through its built-in role configurations, and the published [OMP model-role contract](https://omp.sh/docs/roles) defines `slow`, `default`, and `smol` for deep reasoning, normal work, and cheap work. The published [OMP subagent contract](https://omp.sh/docs/subagents) also provides role-backed built-in worker configurations, so project-generated tier agents duplicate and override host-owned configuration. The current repository proves the unwanted behavior: `gen-omp-agents.sh` writes the three definitions from project model overrides, `skills/woostack-doctor/scripts/checks/omp-agents.sh` repairs them, and `.gitignore` hides them.

The deficiency is OMP-specific. Shared tier declarations and model configuration remain necessary for Claude Code, Codex, CI, Gemini, OpenRouter, and other hosts; deleting those cross-host contracts would exceed the request.

## 2. Proposed Fix

Cut OMP over to its built-in role-backed worker configurations with one fixed mapping: woostack `deep` uses OMP `slow`, `standard` uses OMP `default`, and `fast` uses OMP `smol`. OMP dispatch must not read `.woostack/config.json` model leaves, generate project agents, or walk project-configured model fallbacks. Model identity, provider fallback, credential rotation, and role configuration stay host-owned.

Delete the OMP agent generator and its tests, remove the init hook, delete the doctor missing/drift check and its catalog/test coverage, remove the generated-agent `.gitignore` rule, and rewrite every OMP host/callsite contract that ensures or selects `woostack-{fast,standard,deep}`. Preserve generic prompt `tier:` metadata, provider-specific model resolvers, shared configuration validation, and all non-OMP host behavior. Remove this repository's flat `models` block because it exists only to feed its generated OMP agents; keep the consumer template's shared `models` namespace for supported non-OMP overrides.

Update authored docs pages that describe OMP routing. Historical specs, plans, fixes, and memory records remain historical evidence rather than being rewritten. Existing local generated files are no longer selected or repaired; user-authored `.omp/agents/*` remain untouched.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing contract test**
  - Update `skills/woostack-init/scripts/tests/test-host-references.sh` to require the exact OMP mapping `deep → slow`, `standard → default`, `fast → smol` and role-backed built-in dispatch.
  - Assert that canonical and authored OMP documentation no longer references `gen-omp-agents.sh`, `woostack-fast`, `woostack-standard`, `woostack-deep`, agent-by-tier generation, or OMP consumption of `.woostack/config.json` model overrides.
  - Run the targeted contract test and capture the expected failure before changing implementation assets. Record the two unrelated pre-existing assertions if they still fail; the new role assertions must fail for the intended reason.

- [x] **Step 2: Apply the minimal fix**
  - Delete `skills/woostack-init/scripts/gen-omp-agents.sh` and `skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`; remove the OMP generator step from `skills/woostack-init/SKILL.md`.
  - Delete `skills/woostack-doctor/scripts/checks/omp-agents.sh` and `skills/woostack-doctor/scripts/tests/test-omp-agents.sh`; remove their row from `skills/woostack-doctor/references/checks.md`.
  - Remove the generated-agent rule from `.gitignore` and the OMP-only flat model selections from this repository's `.woostack/config.json` without changing shared consumer model schema support.
  - Rewrite `skills/using-woostack/references/hosts/omp.md` around host-owned built-in roles and update affected generic wording in `skills/using-woostack/references/model-tiers.md`, `skills/woostack-execute/references/subagent-driver.md`, `skills/woostack-commit/SKILL.md`, and `skills/woostack-review/SKILL.md`.
  - Keep OMP usage-limit recovery host-owned and remove woostack's OMP-specific fallback redispatch through `models.<tier>`; missing review receipts must still fail loudly.
  - Update `site/content/docs/harnesses/omp.mdx`, `site/content/docs/harnesses/index.mdx`, `site/content/docs/configuration.mdx`, and `site/content/docs/concepts/context-management.mdx` to match the canonical role mapping.

- [x] **Step 3: Verification**
  - Run the updated host-reference contract test plus the affected init and doctor script tests, excluding deleted test files.
  - Run review configuration/model tests to prove scalar, object, array, and provider-specific overrides still work for non-OMP hosts.
  - Search tracked source and authored docs for stale generator/generated-agent/OMP-model-override references; historical `.woostack/` artifacts are exempt.
  - Run `node --test site/scripts/gen-skills.test.mjs` and `pnpm -C site build` to verify generated skill pages and authored documentation remain valid.
