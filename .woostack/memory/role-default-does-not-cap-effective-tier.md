---
name: role-default-does-not-cap-effective-tier
type: gotcha
scope: skills/woostack-execute/**
tags: model-routing, subagents
hook: A prompt tier default does not constrain a role-agnostic escalation table
updated: 2026-07-16
source: [[fixes/2026-07-16-execute-implementation-tier]]
---
A prompt's default tier is only a starting point. If the shared effective-tier policy has a
role-agnostic escalation, that role can still reach every tier in the table. Encode role-specific
ceilings in the policy, mirror them in the prompt default and skill summary, and pin the matrix with
a targeted contract test.
