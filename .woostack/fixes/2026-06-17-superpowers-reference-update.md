---
type: fix
status: in-review
branch: fix/superpowers-reference-update
---

# Fix: Update superpowers reference in site docs

## 1. Root Cause
The current description of Superpowers (obra/superpowers) in `site/content/docs/index.mdx` does not mention the key reasons for migrating away from it: that it required an additional hardening step to create better plans, and it lacked a cross-agent memory layer.

## 2. Proposed Fix
Update `site/content/docs/index.mdx` at the superpowers list item to state that a reason we moved away from the framework was that it needed an additional hardening step to create better plans, and it lacked a cross-agent memory layer.

## 3. Implementation Plan
- [x] **Step 1: Reproduce with a failing test**
  - Verify that the outdated text is present in the site index page, and write a verification command to grep for the new required reasons (e.g. "hardening step" and "cross-agent memory").
- [x] **Step 2: Apply the minimal fix**
  - Update `site/content/docs/index.mdx` with the updated superpowers description.
- [x] **Step 3: Verification**
  - Verify that the new text is present in the index page using grep.
  - Run the site build script `pnpm -C site build` to confirm the site compiles successfully.
