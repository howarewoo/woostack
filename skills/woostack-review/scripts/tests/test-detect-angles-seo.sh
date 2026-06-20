#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"

# setup $1 = changed file path, $2 = diff body (may be multi-line; literal +/- prefixes)
setup_diff() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '{"files":[{"path":"%s"}]}\n' "$1" > "$OUTDIR/meta.json"
  printf '%s\n' "$2" > "$OUTDIR/diff.txt"
}
absent() { grep -cx 'seo' "$OUTDIR/angles.txt" || true; }  # "0" when seo not enabled

# 1. HARD file: robots.txt fires on path alone (no token needed).
setup_diff "public/robots.txt" "+Disallow: /tmp"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "robots.txt enables seo on path alone"
assert_contains "$(cat "$OUTDIR/angles.txt")" "bugs" "bugs always on"
rm -rf "$work"

# 2. HARD file: sitemap.xml fires on path alone.
setup_diff "app/sitemap.xml" "+  <loc>https://x.com/</loc>"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "sitemap.xml enables seo"
rm -rf "$work"

# 3. HARD file: app/manifest.ts fires on path alone.
setup_diff "app/manifest.ts" "+  name: 'X',"
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "app/manifest.ts enables seo"
rm -rf "$work"

# 4. SOFT file, no token: layout.tsx restyle does NOT enable seo.
setup_diff "app/layout.tsx" '+  <div className="wrap">'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "layout.tsx restyle does not enable seo"
rm -rf "$work"

# 5. SOFT file + metadata co-signal (added): generateMetadata enables seo.
setup_diff "app/layout.tsx" '+export async function generateMetadata() {'
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "added generateMetadata enables seo"
rm -rf "$work"

# 6. SOFT file + metadata co-signal (REMOVED): a removed export is an SEO regression.
setup_diff "app/page.tsx" '-export const metadata = { title: "Old" }'
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "removed metadata export enables seo"
rm -rf "$work"

# 7. SOFT file, no token: *.html with no SEO tag does NOT enable seo.
setup_diff "emails/welcome.html" '+  <div>Hello</div>'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "html with no SEO tag does not enable seo"
rm -rf "$work"

# 8. SOFT file + token: *.html with <meta> enables seo.
setup_diff "public/index.html" '+  <meta name="description" content="x">'
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "seo" "html with <meta> enables seo"
rm -rf "$work"

# 9. SOFT file, no token: next.config.ts alone does NOT enable seo.
setup_diff "next.config.ts" '+  images: { remotePatterns: [] },'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "next.config.ts alone does not enable seo"
rm -rf "$work"

# 10. Excluded token: SVG <title> does NOT enable seo (collision guard).
setup_diff "components/Icon.tsx" '+    <title>Close</title>'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "SVG <title> does not enable seo"
rm -rf "$work"

# 11. Excluded token: <link rel="stylesheet"> does NOT enable seo.
setup_diff "app/layout.tsx" '+  <link rel="stylesheet" href="/x.css">'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "link rel=stylesheet does not enable seo"
rm -rf "$work"

# 12. Anchoring: an UNCHANGED (context) metadata line does NOT enable seo.
setup_diff "app/layout.tsx" "$(printf '+  <div className="x">\n   export const metadata = { title: "keep" }')"
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(absent)" "0" "unchanged-context metadata does not enable seo"
rm -rf "$work"

finish
