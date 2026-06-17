---
name: fumadocs-folder-index-title-duplicates-nav
type: gotcha
scope: site/content/docs/**,site/components/concepts/**
tags: fumadocs, docs, navigation, taxonomy
hook: Fumadocs shows folder meta title and index page title separately, so matching names create duplicate parent/child labels.
updated: 2026-06-16
source: [[fixes/2026-06-16-context-management-economy]]
---

In Fumadocs, `content/docs/<folder>/meta.json` names the folder and `<folder>/index.mdx`
names the index child page. If both use the same title, the sidebar can show a duplicated
parent and child, such as `Core concepts` under `Core concepts`. Keep the folder title for
the section label and title the index page `Overview` when it is only a landing page.
