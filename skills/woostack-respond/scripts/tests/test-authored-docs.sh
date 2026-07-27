#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/assert.sh"
ROOT="$(cd "$HERE/../../../.." && pwd)"
config="$(cat "$ROOT/site/content/docs/configuration.mdx")"; start="$(cat "$ROOT/site/content/docs/getting-started.mdx")"
for phrase in 'init template ships five' 'validates all five scaffolded keys' 'There are ten top-level settings' '"respond": {}' 'respond.provider' 'respond.environment' 'respond.window' 'respond.max_groups' 'respond.remediation' '5 minutes through 30 days' 'from 1 through 5' 'prepare-fix' 'report-only' 'Explicit command arguments' 'Provider credentials' 'authenticated host integration'; do assert_contains "$config" "$phrase" "configuration documents $phrase"; done
for phrase in 'Set up production error response? [y/N]' '/woostack-init --respond' '/woostack-init --no-respond' 'provider-native' '.woostack/respond/' '.woostack/respond/evidence/' '/docs/skills/woostack-respond'; do assert_contains "$start" "$phrase" "getting started documents $phrase"; done
finish
