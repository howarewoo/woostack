---
name: test-fixture-must-exercise-transformation
type: gotcha
scope: skills/woostack-review/prompts/angles/**, skills/**/scripts/tests/*.sh
tags: tests, fixtures, regression-blind, mutation-sensitivity, review-angle
hook: A test whose fixture is neutral to the transformation under test is regression-blind — it stays green even if that transformation is deleted. Fixtures must exercise the behavior the test exists to defend; the tests review angle names this (MEDIUM).
updated: 2026-07-14
source: [[fixes/2026-07-14-tests-regression-blind-fixtures]]
---
A real assertion is not automatically a real test. If the fixture value is invariant under
the specific transformation the test exists to defend, the assertion passes whether or not
that transformation runs — it is regression-blind. Canonical trap: asserting an HTML-escaper's
output on a URL with no escapable characters (dropping the escape call keeps every assertion
green), or a formatter on already-formatted input.

Guard when authoring a test: pick a fixture that would change under the transformation, so a
regression flips the assertion red. Guard when reviewing: this is distinct from "cannot fail"
(the assertion is real) and from "missing edge cases" (framed as add-more-coverage) — it is a
named MEDIUM finding in the tests angle, "the assertion that is present does not defend the
behavior."

Note: a strong model surfaces the neutral fixture on its own via "missing edge cases on new
branches"; the explicit rubric item mainly pins the correct framing + severity across weaker
model tiers. Related: [[skill-test-negative-regression-guard-not-redundant]] keeps an explicit
negative guard a simplify pass would prune.
