---
name: skill-test-negative-regression-guard-not-redundant
type: convention
scope: skills/**/scripts/tests/*.sh
tags: tests, regression-guard, assert-not-contains, simplify, redundancy, false-positive
hook: An assert_not_contains pinning a specific removed marker/token (e.g. a stale woostack-defer(...) marker) is a deliberate regression guard; a broader structural check does not make it "redundant" — don't flag it for removal or delete it to satisfy a simplify finding.
updated: 2026-07-12
source: pr-482
---
woostack skill tests are cheap `grep` / `assert` guards over skill markdown. A targeted
`assert_not_contains "$skill" '<specific-removed-token>'` (e.g. a stale `woostack-defer(increment N)`
marker that a later increment was supposed to delete) is a **regression guard**: it pins the exact
absence a prior change established and localizes the failure to that one contract if the token ever
creeps back.

A broader assertion (an overall skill-count check, a routing-row equality, a structural
well-formedness check) does **not** subsume it — those pass whether or not the specific stale token
is present. So a simplify / tests finding that calls the explicit negative assertion "redundant,
subsumed by broader checks" is a **false positive**: accept it, keep the guard. Belt-and-suspenders
coverage over documentation contracts is intentional, not clutter.

Related: [[skill-test-assert-ascii-token]] and [[grep-assertion-single-physical-line]] cover how to
*author* these grep guards (ASCII token, single physical line); this note covers *keeping* an
explicit negative guard against a review that would prune it.
