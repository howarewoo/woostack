---
type: fix
status: in-review
branch: fix/linear-metadata-normalization
---

# Fix: Accept Linear-normalized managed metadata

## 1. Root Cause

Linear inserts one blank line between the managed metadata header and canonical JSON and one blank line between the JSON and closer when it stores a document. The local serializer currently emits the compact form without those blank lines.

The failure is reproducible by piping Linear's returned representation into `linear-metadata.py parse`: the compact representation succeeds, while the normalized representation exits 1 with `linear metadata error: managed metadata block is malformed`. In `skills/woostack-init/scripts/artifacts/linear-metadata.py`, `HEADER_RE` consumes the header newline, then `managed_section` removes only the final newline before the closer and rejects the remaining newlines at lines 220–249. The canonical JSON itself is valid and unchanged.

The failure propagates through `find_spec` in `skills/woostack-init/scripts/artifacts/linear.sh`: document discovery parses every managed document, so `feature-create` cannot discover the document it just created. Parser tolerance alone would still leave the operation unverified because `feature-create` and `spec-write` compare the compact expected document and Linear-normalized read-back byte-for-byte at lines 795–797 and 875–876. The focused metadata suite currently passes 145 tests because its fixtures contain only the compact representation; no fixture models Linear's returned content.

## 2. Proposed Fix

Teach `managed_section` to accept exactly the two valid managed-body layouts with either LF or CRLF line endings: compact canonical JSON and Linear's representation with one blank line on each side of the canonical JSON. Continue rejecting asymmetric or extra padding, embedded newlines, non-canonical JSON, duplicate blocks, malformed blocks, unsupported schemas, and foreign ownership.

Make the existing metadata serializer emit Linear's normalized representation. `prepare_spec` must canonicalize both newly appended metadata and valid pre-existing compact metadata before a document create or update; `command_replace` must preserve every byte outside the managed block while writing the normalized block. The expected document then matches Linear's stable read-back format, so the existing raw `cmp` remains the strict verification boundary for body text, terminal newlines, and all content outside the block. This is smaller and stricter than introducing a second semantic document-comparison path.

Update the Linear document fixture to the exact blank-line representation returned by Linear so the resource-level create path proves discovery and verified read-back against the real API shape. No broad whitespace normalization, dependency, or public lifecycle change is required.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing tests**
  - Add metadata parser cases using the exact LF and CRLF Linear-normalized blocks and require canonical parsed JSON.
  - Add negative cases for asymmetric or excessive blank-line padding so tolerance remains limited to the observed API representation.
  - Change the managed document fixture to Linear's returned representation and confirm the existing `feature-create` success scenario fails before implementation.
  - Add serializer regressions proving compact input is emitted in the normalized form while every byte outside the managed block remains unchanged.
- [x] **Step 2: Apply the minimal fix**
  - Update `managed_section` in `skills/woostack-init/scripts/artifacts/linear-metadata.py` to recognize only compact and Linear-normalized managed JSON bodies while preserving canonical JSON and duplicate/ownership validation.
  - Make `command_replace` emit the normalized managed-block layout without changing content outside that block.
  - Make `prepare_spec` in `skills/woostack-init/scripts/artifacts/linear.sh` serialize both new and pre-existing valid metadata into the normalized layout before document mutations.
- [x] **Step 3: Verification**
  - Run `bash skills/woostack-init/scripts/tests/test-linear-metadata.sh`.
  - Run `bash skills/woostack-init/scripts/tests/test-linear-resources.sh`.
  - Confirm the exact Linear-normalized fixture produces `verified: true`, while duplicate/foreign/non-canonical metadata, changed spec body text, and terminal-newline mismatches still fail closed.
