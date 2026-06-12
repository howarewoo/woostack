---
name: skill-test-assert-ascii-token
type: convention
scope: skills/**/scripts/tests/*.sh
tags: tests, grep, assertions, encoding, ascii, unicode
hook: Grep-based skill tests should assert an ASCII token, not a unicode literal (e.g. a → arrow); keep the readable unicode in the prose and assert on an ASCII phrase that lives in the same text.
updated: 2026-06-05
source: .woostack/plans/2026-06-05-address-comments-fix-plan-gate.md
---
woostack skills are documentation; their `scripts/tests/*.sh` guards are `rg -F`/`grep`
presence-checks over the prose. When the prose contains a readable unicode glyph (an em-dash,
a `→` arrow, smart quotes), do **not** make that glyph the assertion token. A unicode literal
embedded in a shell assertion is fragile to encoding and copy-paste, and obscures the contract
the test means to pin.

Instead: keep the readable unicode in the prose, and assert on an **ASCII phrase that already
appears in the same passage**. Example from the address-comments fix-plan gate — the prose keeps
the heading `**override→FIX follow-up:**`, but the regression test asserts `bounded confirm`
(an ASCII phrase in that same paragraph) rather than `override→FIX`.

Rule of thumb when adding a grep assertion: pick the most stable ASCII substring that uniquely
identifies the contract, and confirm it is genuinely present (not a near-match) before relying
on it. See [[skill-description-colon-space]] for the related "tests are cheap guards over skill
markdown" pattern.
