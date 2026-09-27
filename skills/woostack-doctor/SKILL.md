---
name: woostack-doctor
description: Diagnose and, after approval, repair a repository's local `.woostack/` workspace health with canonical GitHub policy validation.
---

# woostack-doctor

Diagnose — and, with explicit approval, repair — the health of a repository's `.woostack/`
workspace. Doctor is local integrity and convention checking; it never creates a workspace,
publishes planning artifacts, reconciles a feature board, or repairs remote resources.

It has two layers:

- The headless [`scripts/doctor.sh`](scripts/doctor.sh) engine is provider-free. Every check is
  static: it reads no credentials and makes no network call.
- The interactive repair layer proposes local auto-fixes, mutates nothing before approval, routes
  approved tracked repairs through [`woostack-execute`](../woostack-execute/SKILL.md) in an isolated
  task worktree, and performs only safe filesystem repairs owned by a check. Remote and retained data
  are report-only. OMP agent selection is host-owned; Doctor never inspects, creates, repairs, or
  removes project agent definitions.

## Commands

- `/woostack-doctor [path]` — diagnose the workspace, then offer a gated repair changeset for
  auto-fixable local findings.
- `/woostack-doctor [path] --check` — diagnose only, print GitHub-style annotations, and exit
  nonzero only when an `error` finding exists. It mutates nothing.

The engine depends on [`woostack-init`](../woostack-init/SKILL.md) for the shipped template and
canonical resolver.

## Procedure

1. Capture the requested target without statting, reading, canonicalizing, or invoking Git before
   the workflow has admitted it.
2. Resolve the effective tracked plus primary-checkout local policy through
   `woostack-init/scripts/config/resolve-config.sh`. Doctor consumes that authoritative validation;
   it does not duplicate the GitHub schema.
3. Run static checks for configuration, diagnostics, ignore drift, OMP session naming, worktree
   hygiene, and retained data. OMP agent selection is host-owned; Doctor never inspects, creates,
   repairs, or removes project agent definitions. Legacy provider settings and mirror-era manifests
   are preserved and produce actionable retirement guidance only; they never select a destination,
   recreate a wrapper, or block unrelated local diagnosis.
4. If there is no `.woostack/`, stop and point the user to [`woostack-init`](../woostack-init/SKILL.md).
   Doctor never scaffolds.
5. Propose a changeset grouped by finding code, path, and exact local change. Provider, legacy, and
   retained-data findings are report-only.
6. **HARD GATE — approval.** Silence is not approval. Apply only the explicitly approved local
   auto-fix findings. Route tracked repairs through `woostack-execute` in its isolated task worktree
   before any file mutation; safe filesystem-only repairs may use their owning check. No repair
   command contacts a provider or mutates retained data.
7. Confirm in the same static mode and report residual findings.

## Hard constraints

- Missing configuration is valid; absent `github` means no Project/Status policy is selected.
- The canonical top-level `github` object is validated once by Init's resolver. Legacy
  `artifacts.provider`, `artifacts.linear`, `artifacts.plane`, and older root provider settings are
  opaque historical data: preserve them, do not validate them as active policy, and report their
  retirement at the affected boundary.
- Static diagnosis and every shell repair are provider-free. Authorized GitHub capability evidence
  is read by the calling workflow through native host tools or host-authenticated `gh`; Doctor
  accepts no capability receipt and never opens a provider session.
- Never scaffold, migrate, import, mirror, create, repair, reparent, rewrite, close, or delete
  remote or retained records. Never read credentials or invoke custom HTTP/GraphQL transports.
- Gate every repair. Preserve symlink/no-follow, private-file, locking/CAS, dirty-worktree, and
  read-back safety. Never merge.
