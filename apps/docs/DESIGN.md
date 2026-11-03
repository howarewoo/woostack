---
name: WooStack website
description: Geometric branding and a ruled composition for the homepage and documentation.
colors:
  graphite: "#191C20"
  panel: "#22272E"
  chalk: "#F4F6FA"
  slate: "#B2BBC6"
  cobalt: "#365BE8"
  cobalt-hover: "#2646D0"
  mist: "#8AA4FF"
  rule-dark: "#505961"
  rule-light: "#CBD0D8"
  secondary-light: "#495462"
  white: "#FFFFFF"
  grid-line: "#849BFF"
  grid-line-muted: "#849BFF55"
  construction-cross: "#C9D5FF"
  accent-light: "#E1E6EF"
  accent-dark: "#303842"
typography:
  display:
    fontFamily: Archivo Black
    fontWeight: 400
    lineHeight: 1.04
    letterSpacing: "-0.04em"
  body:
    fontFamily: DM Sans
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.6
  code:
    fontFamily: IBM Plex Mono
    fontWeight: 400
    lineHeight: 1.5
  compact:
    fontFamily: IBM Plex Mono
    fontSize: "12px"
  code-label:
    fontFamily: IBM Plex Mono
    fontSize: "13px"
  action:
    fontFamily: DM Sans
    fontSize: "14px"
  introduction:
    fontFamily: DM Sans
    fontSize: "17px"
  quote-mobile:
    fontFamily: DM Sans
    fontSize: "19px"
  section-detail:
    fontFamily: DM Sans
    fontSize: "20px"
  wordmark:
    fontFamily: Archivo Black
    fontSize: "22px"
  section-mobile:
    fontFamily: DM Sans
    fontSize: "30px"
  section:
    fontFamily: DM Sans
    fontSize: "36px"
  display-mobile:
    fontFamily: Archivo Black
    fontSize: "clamp(34px, 8.9vw, 60px)"
  display-intermediate:
    fontFamily: Archivo Black
    fontSize: "clamp(42px, 5.6vw, 58px)"
  display-desktop:
    fontFamily: Archivo Black
    fontSize: "clamp(48px, 5.6vw, 80px)"
rounded:
  action: "0px"
spacing:
  unit: "8px"
  half-unit: "4px"
  mobile-gutter: "20px"
  intermediate-gutter: "32px"
  desktop-gutter: "48px"
components:
  button-primary:
    backgroundColor: "{colors.cobalt}"
    textColor: "{colors.white}"
    rounded: "{rounded.action}"
    height: "48px"
    padding: "12px 20px"
  button-primary-hover:
    backgroundColor: "{colors.cobalt-hover}"
---

# Design System: WooStack website

## Overview

The website pairs a geometric W and heavy display headline with a precise, ruled composition.
Home introduces the skills collection and routes visitors to the tutorial, documentation and source.
Documentation preserves familiar reading, search and navigation controls. Product and workflow
principles remain owned by the [root design guidance](../../DESIGN.md).

## Colors

Global Fumadocs variables in `app/global.css` supply both themes. Dark uses graphite and panel
surfaces, chalk prose, slate secondary text and mist links/focus. Light uses chalk and white
surfaces, graphite prose, `secondary-light` text and cobalt links/focus. Cobalt/white filled actions
stay the same in both themes. Preserve saved/system theme behavior and semantic callout colors.

## Typography

The five licensed local WOFF2 files in `app/fonts/` are loaded through `next/font/local`.
Archivo Black 400 is for the wordmark and home headline. DM Sans 400/600 is for prose, actions,
docs navigation and docs headings. IBM Plex Mono 400/500 is for code, commands and compact home
navigation. Fallbacks cover characters outside the supplied Latin subsets; synthetic weights are
disabled. Retain Fumadocs reading-page title sizes and aim for 65–75 character prose measures.

## Layout

The homepage is a navigation surface. Its CSS module owns the hero, installation strip, workflow
illustration and footer. Content is at most 1280px wide with 48px desktop gutters, 32px intermediate
gutters and 20px mobile gutters. At 700px and below, copy/actions precede the landscape W field;
workflow columns stack. Text may wrap naturally. Wide docs code and diagrams scroll inside their
own containers. Keep the library's documentation breakpoints and one main landmark per route.

## Elevation & Depth

Thin structural rules and raised surfaces organize content. The W construction grid stays bounded
to its cobalt field. Home has no entrance animation; action feedback is a 140ms color transition.
Reduced motion removes transitions and animation. Library overlays retain their native geometry.

## Shapes

Home panels and actions are square. The same supplied W path appears in both shells and the hero.
Do not redraw it or apply landing typography/reset selectors to documentation.

## Components

Reuse Fumadocs search, mobile menus, sidebar, TOC, theme selection, copy and source controls.
Authored hero actions are at least 48px tall. Focus uses a theme-appropriate 3px ring with 4px offset.
The Execute illustration has three tabs with roving focus, Arrow Left/Right wrapping and Home/End.
Its initial Inspect content renders on the server; tab changes only change the example text.
Keep the Illustrative label and explicit statement that no agent runs here.

## Do's and Don'ts

- Link to real docs and source destinations; verify installation copy against the repository README.
- Preserve meaningful callout colors and code syntax, visible focus and scroll containment.
- Keep ordinary dark-theme link text mist; cobalt on graphite is insufficient for body text.
- Keep design specimens, fabricated activity, metrics, pricing and new execution behavior off home.
- Avoid neon, glow, gradient text and decorative site-wide grids.
