# Maintainer skill evaluation

This directory contains Woostack's internal evaluation workflow and deterministic support tooling.
It is publicly inspectable so contributors can audit corpora, schemas, methodology, and reports, but
it is operated by maintainers and is not part of the consumer skill collection.

## Distribution boundary

- Default consumer installation discovers packages only under `skills/`; this directory is outside
  that root.
- `using-woostack` has no evaluator routing row and the documentation site does not generate an
  evaluator skill page.
- Consumers do not need evaluation corpora, baseline machinery, evidence aggregation, runner host
  contracts, Docker Sandbox, or model-provider setup to use Woostack.
- The deterministic package validator required by installed review workflows remains under
  `skills/using-woostack/scripts/`; packaged consumer workflows do not require this directory at
  runtime.

## Maintainer workflow

Load [`SKILL.md`](SKILL.md) explicitly from a trusted maintainer checkout. The scripts validate
packages and corpora, prepare frozen candidate/baseline workspaces, aggregate supervisor-owned
evidence, and render reports.

Model-backed execution is fail-closed until the isolated runner tracked in
[#560](https://github.com/howarewoo/woostack/issues/560) is configured. Ordinary subagents, OMP
`task` workers, and same-session context separation are not security boundaries and must not be used
as substitutes.

## Verification

```bash
bash tooling/evals/scripts/tests/run-tests.sh
node --test tooling/evals/scripts/tests/test-public-boundary.test.mjs
pnpm -C site test
pnpm -C site build
```
