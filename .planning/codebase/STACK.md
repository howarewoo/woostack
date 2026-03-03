# Technology Stack

**Analysis Date:** 2026-03-02

## Languages

**Primary:**
- TypeScript 5.9.3 - Used across all packages and apps (ES2022 target)

**Secondary:**
- JavaScript - Configuration files (Next.js, Metro, build scripts)
- JSX/TSX - React components in web and mobile apps

## Runtime

**Environment:**
- Node.js 22 (pinned in CI; enforced via pnpm)

**Package Manager:**
- pnpm 10.30.1 (enforced via `packageManager` field in root `package.json`)
- Lockfile: present (`pnpm-lock.yaml`)

## Frameworks

**Core Web:**
- Next.js 16.1.6 - Used in `apps/web` (App Router, React Compiler enabled) and `apps/landing` (marketing page)
  - React 19.1.0 (exact version for React Native renderer compatibility)
  - React DOM 19.1.0

**Core Mobile:**
- Expo SDK 54.0.33 - Manages `apps/mobile` build/platform-specific code
- React Native 0.81.5 - Mobile runtime
- Expo Router 6.0.23 - File-based routing for Expo
- React Navigation 7.1.28 - Cross-platform navigation base

**API Server:**
- Hono 4.11.9 - Lightweight HTTP server framework in `apps/api`
- @hono/node-server 1.19.9 - Node.js adapter for Hono

**Build/Dev:**
- Turbo 2.8.10 - Monorepo build orchestration and caching
- tsx 4.21.0 - TypeScript execution for dev/build scripts in API
- Babel 7.29.0 - JavaScript transpilation (used by Expo)
- Metro - React Native bundler (configured in `apps/mobile/metro.config.js`)

**Styling:**
- Tailwind CSS 4.1.18 - Utility-first CSS framework (v4, CSS-first)
- @tailwindcss/postcss 4.1.18 - PostCSS plugin for web apps
- UniWind 1.3.1 - Tailwind for React Native (Metro integration)
- PostCSS 8.5.6 - CSS transformation pipeline

**UI Component Libraries:**
- @base-ui/react 1.2.0 - Unstyled, accessible primitives (Vega style)
- @radix-ui/react-slot 1.1.1 - Utility for slot forwarding
- lucide-react 0.564.0 - Consistent icon library across web
- @expo/vector-icons 15.0.3 - Icon library for mobile
- Sonner 2.0.7 - Toast notification library

**Utilities:**
- class-variance-authority 0.7.1 - Type-safe component variants
- clsx 2.1.1 - Conditional className utility
- tailwind-merge 3.4.0 - Tailwind class deduplication

## Key Dependencies

**Critical:**
- @supabase/supabase-js 2.97.0 - JavaScript client for Supabase (auth, database, storage)
- @supabase/ssr 0.8.0 - Server-side session handling for Next.js
- Zod 4.3.6 - TypeScript-first schema validation (auth forms, API contracts)

**API & Type-Safety:**
- @orpc/server 1.13.5 - oRPC server implementation
- @orpc/client 1.13.5 - oRPC client implementation
- @orpc/contract 1.13.5 - Contract definitions
- @orpc/tanstack-query 1.13.5 - TanStack Query integration for oRPC

**State Management & Forms:**
- @tanstack/react-query 5.90.21 - Server state management (caching, sync)
- @tanstack/react-form 1.28.3 - Form state without heavy dependencies
- @tanstack/react-form uses Standard Schema (Zod v4 compatible natively)

**React Native:**
- react-native-gesture-handler 2.28.0 - Touch gesture recognition
- react-native-reanimated 4.1.6 - High-performance animations
- react-native-safe-area-context 5.6.2 - Safe area boundaries (notches)
- react-native-screens 4.16.0 - Native screen handling for navigation
- react-native-web 0.21.2 - React Native components on web
- react-native-worklets 0.5.1 - Offthread worklets for performance

**Expo Utilities:**
- expo-constants 18.0.13 - App constants and metadata
- expo-font 14.0.11 - Custom font loading
- expo-linking 8.0.11 - Deep linking support
- expo-status-bar 3.0.9 - Status bar control

## Testing

**Framework:**
- Vitest 4.0.18 - Unit/integration tests (web, api, infrastructure packages)
  - Config: `vitest.config.ts` (root), `apps/web/vitest.config.ts`, `apps/landing/vitest.config.ts`, `apps/api/vitest.config.ts`
  - JSDOM 28.0.0 - DOM emulation for browser APIs

**Mobile Testing:**
- Jest 29.7.0 (via jest-expo preset) - Mobile unit tests in `apps/mobile`
- @testing-library/react-native 13.3.3 - React Native component testing
- jest-expo 54.0.17 - Expo preset for Jest

**E2E Testing:**
- @playwright/test 1.58.2 - Browser automation and E2E tests
  - Config: `apps/web/playwright.config.ts`
  - Run via: `pnpm test:e2e`

**Testing Utilities:**
- @testing-library/react 16.3.2 - React component testing utilities

## Configuration

**Environment:**
- API (`apps/api`): `.env` with `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, optional `PORT`, `CORS_ALLOWED_ORIGINS`
- Web (`apps/web`): `.env.local` with `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- Mobile (`apps/mobile`): `.env` with `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- Supabase (`apps/supabase`): `config.toml` (Supabase CLI configuration)

**Linting & Formatting:**
- Biome 2.4.4 - Unified linter and formatter
  - Config: `biome.json` (100-char line width, double quotes, ES5 trailing commas, semicolons)
  - Enforces: no-any (error), no-unused-imports (warn), no-unused-variables (warn)

**TypeScript:**
- TSC 5.9.3 - Type checking
- Shared configs: `packages/infrastructure/typescript-config/` (base, library, nextjs, react-native presets)
- tsconfig.json (root): ES2022 target, strict mode enabled

## Database & Backend Infrastructure

**Supabase:**
- supabase 2.76.12 - CLI for local development and migrations
- Hosted Supabase for production auth, PostgreSQL database, and S3 storage
- Local development: Docker-based (`pnpm --filter supabase-db start`)

**Generated Types:**
- `packages/infrastructure/supabase/src/generated/database.ts` - Auto-generated from Supabase schema
- Generated via: `pnpm gencode` (requires local Supabase running)
- `packages/infrastructure/api-client/src/generated/router-types.d.ts` - Auto-generated oRPC Router type

## Platform Requirements

**Development:**
- pnpm 10.30.1
- Node.js 22
- Docker (for local Supabase via `pnpm --filter supabase-db start`)
- Xcode (for iOS builds via Expo)
- Android Studio or SDK (for Android builds via Expo)

**Production:**
- API: Node.js 22+ (runs on `apps/api` via `node dist/index.js`)
- Web: Vercel or any Node.js hosting (Next.js)
- Landing: Vercel or any static/Node.js hosting (Next.js)
- Mobile: iOS App Store or Google Play (Expo-managed builds or EAS)
- Supabase: Managed Supabase instance (auth, DB, storage, edge functions)

---

*Stack analysis: 2026-03-02*
