import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@infrastructure/ui-web";
import type { Metadata } from "next";
import { UserList } from "@/components/user-list";

export const metadata: Metadata = {
  title: "Monorepo Template",
  description:
    "A production-ready monorepo with Next.js, Expo, and Hono. Type-safe APIs, shared packages, and platform-specific apps.",
};

export default function Home() {
  return (
    <main className="min-h-screen p-8">
      <div className="max-w-5xl mx-auto space-y-6">
        <div className="text-center space-y-2">
          <h1 className="text-4xl font-bold">Monorepo Template</h1>
          <p className="text-muted-foreground">
            A production-ready monorepo with Next.js, Expo, and Hono
          </p>
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          <Card>
            <CardHeader>
              <CardTitle>Web</CardTitle>
              <CardDescription>Next.js 16 &middot; port 3000</CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>App Router</li>
                <li>React Compiler</li>
                <li>shadcn/ui (Base UI)</li>
                <li>Tailwind CSS v4</li>
              </ul>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Mobile</CardTitle>
              <CardDescription>Expo SDK 54 &middot; port 8081</CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>React Native 0.81</li>
                <li>UniWind</li>
                <li>react-native-reusables</li>
                <li>iOS, Android, Web</li>
              </ul>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>API</CardTitle>
              <CardDescription>Hono + oRPC &middot; port 3001</CardDescription>
            </CardHeader>
            <CardContent>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>Type-safe RPC</li>
                <li>Zod validation</li>
                <li>End-to-end types</li>
                <li>Typed client SDK</li>
              </ul>
            </CardContent>
          </Card>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Shared Infrastructure</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex flex-wrap gap-2 text-xs">
                <code className="bg-muted px-2 py-1 rounded">api-client</code>
                <code className="bg-muted px-2 py-1 rounded">navigation</code>
                <code className="bg-muted px-2 py-1 rounded">ui</code>
                <code className="bg-muted px-2 py-1 rounded">ui-web</code>
                <code className="bg-muted px-2 py-1 rounded">utils</code>
                <code className="bg-muted px-2 py-1 rounded">typescript-config</code>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Tooling</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex flex-wrap gap-2 text-xs">
                <code className="bg-muted px-2 py-1 rounded">Turborepo</code>
                <code className="bg-muted px-2 py-1 rounded">pnpm</code>
                <code className="bg-muted px-2 py-1 rounded">Biome</code>
                <code className="bg-muted px-2 py-1 rounded">Vitest</code>
                <code className="bg-muted px-2 py-1 rounded">Playwright</code>
              </div>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardContent className="pt-6">
            <div className="flex flex-wrap items-center gap-4 text-sm">
              <span className="font-medium">Quick Start</span>
              <code className="bg-muted px-3 py-1.5 rounded text-xs">pnpm install</code>
              <code className="bg-muted px-3 py-1.5 rounded text-xs">pnpm dev</code>
              <code className="bg-muted px-3 py-1.5 rounded text-xs">pnpm build</code>
              <code className="bg-muted px-3 py-1.5 rounded text-xs">pnpm test</code>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Users from API</CardTitle>
            <CardDescription>Data fetched from the Hono API</CardDescription>
          </CardHeader>
          <CardContent>
            <UserList />
          </CardContent>
        </Card>

        <div className="flex justify-center gap-4">
          <Button>Get Started</Button>
          <Button variant="outline">Documentation</Button>
        </div>
      </div>
    </main>
  );
}
