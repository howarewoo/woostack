---
name: provider-normalization-needs-write-read-symmetry
type: gotcha
scope: skills/woostack-init/scripts/artifacts/**, skills/woostack-init/scripts/tests/**
tags: linear, metadata, readback
hook: Provider normalization requires symmetric parsing and serialization
updated: 2026-07-15
source: [[fixes/2026-07-15-linear-metadata-normalization]]
---
Managed-block normalization: accept the provider form and serialize expected read-back identically.
