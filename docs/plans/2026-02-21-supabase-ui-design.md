# Supabase UI Updates Design

**Date:** 2026-02-21
**Status:** Approved

## Overview

Update `apps/web` and `apps/landing` to reflect the Supabase integration added in the backend. The web app gets a full auth flow (sign-in, sign-up, forgot/reset password, dashboard, settings). The landing page gets updated content showcasing Supabase as a core feature.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Auth form approach | Custom shadcn/ui forms | Matches design system, full styling control |
| Auth methods | Email/password + OAuth (Google, Apple, GitHub) | Covers all wired-up providers |
| Route protection | Next.js middleware + server layout guard | Double-layer: middleware for redirects, layout for SSR check |
| Dashboard scope | User info + UserList | Minimal but demonstrates authenticated data fetching |
| Landing Supabase section | Section 4.0 (Infrastructure becomes 5.0) | Better narrative flow: apps → backend → infra |
| Hero mockups | Updated to show auth state | Makes Supabase features visible above the fold |
| Value prop update | Replace "Zero Config DX" with "Auth & Storage Built In" | Highlights the most impactful new capability |

## Web App: Route Structure

```
apps/web/app/
├── (auth)/                        # Auth route group (public)
│   ├── sign-in/page.tsx           # Email/password + OAuth sign-in
│   ├── sign-up/page.tsx           # Email/password + OAuth sign-up
│   ├── forgot-password/page.tsx   # Email input → password reset request
│   └── reset-password/page.tsx    # New password form (via Supabase link)
├── (protected)/                   # Protected route group
│   ├── layout.tsx                 # Auth guard — redirects to /sign-in if no session
│   ├── dashboard/page.tsx         # Authenticated home (user info + UserList)
│   └── settings/page.tsx          # User profile, email, sign-out
├── page.tsx                       # Root redirect: authed → /dashboard, else → /sign-in
├── middleware.ts                  # Route protection + session refresh
├── layout.tsx                     # Unchanged (Providers wrapper)
└── providers.tsx                  # Unchanged (AuthProvider already wired)
```

## Web App: Auth Form Design

Each auth page uses a centered card layout (~400px max-width):
- `Card` wrapping the form, vertically centered on page
- `Input` + `Label` for email/password fields
- Primary `Button` for form submission
- `Separator` with "Or continue with" text
- Three OAuth icon buttons (Google, Apple, GitHub)
- Navigation links between sign-in ↔ sign-up
- Inline error display below form

Shared `AuthForm` component handles the common form layout; individual pages customize heading, submit action, and links.

## Web App: Dashboard

- Header bar: app name (left), user avatar circle (email initial) + email + sign-out button (right)
- "Welcome back, {email}" greeting
- `UserList` component (moved from current home page) fetching with authenticated token
- Link to settings

## Web App: Settings

- Card with user info: email, user ID, created date
- Sign-out button → redirects to /sign-in
- Back link to dashboard

## Web App: Root Page

Server component that checks session via `createSSRServerClient(cookies)`:
- User exists → redirect to `/dashboard`
- No user → redirect to `/sign-in`

## Web App: New shadcn/ui Components

Install via `pnpx shadcn@latest add input label separator` from `apps/web/`, then move to `@infrastructure/ui-web` for sharing across web apps.

## Landing Page: Hero Updates

**Announcement badge:** "Now with Supabase Auth, Database & Storage"

**Subtitle:** "Ship web, mobile, and API from a single codebase. Authentication, database, and storage included. Type-safe from backend to device."

**Browser frame:** Updated to show an authenticated dashboard mockup:
- Header with user avatar + email + sign-out
- Welcome greeting
- User list card
- Supabase in infrastructure badges

**Phone frame:** Updated to show a sign-in screen:
- "Sign In" heading
- Mini email/password fields
- Sign-in button
- OAuth button row (G / A / GH)
- "Sign up" link

## Landing Page: Tech Stack Bar

Add "Supabase" to the technologies array.

## Landing Page: Value Props

Replace FIG 0.3:
- **Old:** "Zero Config DX" — Turborepo caching, Biome linting, etc.
- **New:** "Auth & Storage Built In" — Supabase provides authentication, database, and file storage out of the box. Row-level security, OAuth providers, and typed queries — no backend assembly required.

## Landing Page: Feature Sections Reorder

1. **1.0 Web** — unchanged
2. **2.0 Mobile** — unchanged
3. **3.0 API** — unchanged
4. **4.0 Backend** (NEW) — Supabase auth, database, storage, RLS, generated types
5. **5.0 Infrastructure** (renumbered from 4.0) — shared packages

### Section 4.0 Backend

```
title: "Backend"
description: "Supabase for authentication, PostgreSQL database, and file storage.
Row-level security scopes every query. JWT validation at the API layer.
Auto-generated TypeScript types from your schema."
features: ["Supabase Auth", "PostgreSQL", "Row-Level Security", "File Storage", "Generated Types"]
```

Code sample:
```typescript
import { useAuth } from "@infrastructure/supabase/auth";
import { createStorageClient } from "@infrastructure/supabase/storage";

// Auth — sign in with email or OAuth
const { signIn, signInWithOAuth, user } = useAuth();
await signIn({ email, password });
await signInWithOAuth("github");

// Storage — upload with RLS
const storage = createStorageClient(supabase);
await storage.upload("avatars", `${user.id}.png`, file);
```

## File Inventory

### New Files

| File | Purpose |
|------|---------|
| `apps/web/app/(auth)/sign-in/page.tsx` | Sign-in form |
| `apps/web/app/(auth)/sign-up/page.tsx` | Sign-up form |
| `apps/web/app/(auth)/forgot-password/page.tsx` | Password reset request |
| `apps/web/app/(auth)/reset-password/page.tsx` | New password form |
| `apps/web/app/(protected)/layout.tsx` | Auth guard layout |
| `apps/web/app/(protected)/dashboard/page.tsx` | Authenticated dashboard |
| `apps/web/app/(protected)/settings/page.tsx` | User profile + sign-out |
| `apps/web/middleware.ts` | Next.js middleware |
| `apps/web/components/auth-form.tsx` | Shared auth form component |

### Modified Files

| File | Change |
|------|--------|
| `apps/web/app/page.tsx` | Replace with auth-based redirect |
| `apps/landing/app/page.tsx` | Renumber sections, add 4.0 Backend, update value props |
| `apps/landing/components/hero.tsx` | Badge text + subtitle |
| `apps/landing/components/browser-frame.tsx` | Authenticated dashboard mockup |
| `apps/landing/components/phone-frame.tsx` | Sign-in screen mockup |
| `apps/landing/components/logo-bar.tsx` | Add "Supabase" |

### New Shared Components

| Component | Install command |
|-----------|----------------|
| Input | `pnpx shadcn@latest add input` |
| Label | `pnpx shadcn@latest add label` |
| Separator | `pnpx shadcn@latest add separator` |

## Out of Scope (YAGNI)

- Admin panel / user management
- Email verification UI (Supabase handles this)
- "Remember me" checkbox (Supabase handles session persistence)
- Dark mode toggle (system preference already works)
- Mobile app auth UI (separate task)
- Password strength indicator
- Rate limiting UI
