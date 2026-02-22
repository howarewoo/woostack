import { Button, Card, CardContent, CardHeader, CardTitle } from "@infrastructure/ui-web";
import type { Metadata } from "next";
import { FeatureSection } from "@/components/feature-section";
import { Footer } from "@/components/footer";
import { Hero } from "@/components/hero";
import { TechStackBar } from "@/components/logo-bar";
import { Navbar } from "@/components/navbar";

export const metadata: Metadata = {
  title: "Monorepo Template — Web, Mobile & API in One Codebase",
  description:
    "A production-ready monorepo template with Next.js, Expo, Hono, and oRPC. Shared packages, type-safe APIs, and platform-specific apps that deploy independently.",
};

const valueProps = [
  {
    figure: "FIG 0.1",
    title: "Shared by Default",
    description:
      "Design tokens, navigation, utilities, and UI components live in shared packages. Write once, use everywhere.",
  },
  {
    figure: "FIG 0.2",
    title: "Type-Safe End to End",
    description:
      "oRPC contracts generate typed clients automatically. Catch errors at compile time, not in production.",
  },
  {
    figure: "FIG 0.3",
    title: "Zero Config DX",
    description:
      "Turborepo caching, Biome linting, React Compiler, and pnpm workspaces. Everything just works out of the box.",
  },
];

const testimonials = [
  {
    quote:
      "This template cut our setup time from weeks to hours. The shared package architecture is exactly right.",
    name: "Alex Chen",
    role: "Senior Engineer",
  },
  {
    quote:
      "Finally, a monorepo template that treats mobile as a first-class citizen. The UniWind integration is seamless.",
    name: "Sarah Park",
    role: "Mobile Lead",
  },
];

/** Marketing landing page showcasing monorepo features, tech stack, and testimonials. */
export default function LandingPage() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <Navbar />
      <Hero />
      <TechStackBar />

      {/* Mission Statement */}
      <section className="border-b border-border/40 py-20 md:py-28">
        <div className="mx-auto max-w-3xl px-6 text-center">
          <p className="text-2xl leading-relaxed md:text-3xl">
            <span className="font-semibold">One codebase for web, mobile, and API.</span>{" "}
            <span className="text-muted-foreground">
              A production-ready monorepo template with shared packages, type-safe APIs, and
              platform-specific apps that deploy independently.
            </span>
          </p>
        </div>
      </section>

      {/* Value Props */}
      <section id="features" className="border-b border-border/40 py-20 md:py-28">
        <div className="mx-auto max-w-6xl px-6">
          <div className="grid gap-px overflow-hidden rounded-xl border border-border/60 bg-border/40 md:grid-cols-3">
            {valueProps.map((prop) => (
              <div key={prop.figure} className="bg-background p-8 md:p-10">
                <span className="mb-6 block font-mono text-[11px] font-medium uppercase tracking-widest text-muted-foreground/50">
                  {prop.figure}
                </span>
                <h3 className="text-lg font-semibold">{prop.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                  {prop.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Feature Sections */}
      <div id="stack">
        <FeatureSection
          number="1.0"
          title="Web"
          description="Next.js 16 with App Router, React Compiler, and shadcn/ui components built on Base UI primitives. Server components by default with streaming and partial prerendering."
          features={[
            "App Router",
            "React Compiler",
            "shadcn/ui",
            "Tailwind v4",
            "Server Components",
          ]}
          codeLabel="apps/web/app/page.tsx"
          code={`import { Button } from "@infrastructure/ui-web";

export default function Home() {
  return (
    <main className="min-h-screen p-8">
      <h1>Ship faster</h1>
      <Button>Get Started</Button>
    </main>
  );
}`}
        />

        <FeatureSection
          number="2.0"
          title="Mobile"
          description="Expo SDK 54 with React Native 0.81 and UniWind for Tailwind-style styling. Shared navigation and design tokens keep mobile and web in sync."
          features={["Expo Router", "UniWind", "React Native 0.81", "Web Export", "Reusables"]}
          codeLabel="apps/mobile/app/(tabs)/index.tsx"
          code={`import { Link } from "@infrastructure/navigation";
import { View, Text } from "react-native";

export default function Home() {
  return (
    <View className="flex-1 p-4">
      <Text className="text-2xl font-bold">
        Hello from mobile
      </Text>
      <Link href="/settings">Settings</Link>
    </View>
  );
}`}
          reverse
        />

        <FeatureSection
          number="3.0"
          title="API"
          description="Hono server with oRPC for end-to-end type safety. Define contracts once, get typed clients for free. Zod validation at the boundary, TypeScript everywhere else."
          features={["Hono", "oRPC", "Zod Validation", "Type-Safe Client", "React Query"]}
          codeLabel="packages/infrastructure/api-client/src/contract.ts"
          code={`import { os } from "@orpc/server";
import { z } from "zod";

const pub = os.$context<{ requestId?: string }>();

export const router = {
  users: {
    list: pub.output(z.array(UserSchema))
      .handler(() => { /* ... */ }),
    get: pub.input(z.object({ id: z.string() }))
      .output(UserSchema)
      .handler(({ input }) => { /* ... */ }),
  },
};`}
        />

        <FeatureSection
          number="4.0"
          title="Infrastructure"
          description="Shared packages for navigation, UI tokens, utilities, and TypeScript configs. Feature packages for isolated business logic. Clean dependency boundaries enforced by convention."
          features={[
            "Design Tokens",
            "Navigation",
            "Utilities",
            "TypeScript Configs",
            "UI Components",
          ]}
          codeLabel="packages/infrastructure/"
          code={`infrastructure/
├── api-client/     # oRPC contracts + client
├── navigation/     # Platform-agnostic nav
├── ui/             # Design tokens, cn()
├── ui-web/         # shadcn/ui components
├── utils/          # Cross-platform helpers
└── typescript-config/
    ├── base.json
    ├── library.json
    ├── nextjs.json
    └── react-native.json`}
          reverse
        />
      </div>

      {/* Testimonials */}
      <section className="border-b border-border/40 py-20 md:py-28">
        <div className="mx-auto max-w-6xl px-6">
          <div className="grid gap-6 md:grid-cols-2">
            {testimonials.map((t) => (
              <Card key={t.name}>
                <CardContent className="pt-6">
                  <blockquote className="leading-relaxed text-muted-foreground">
                    &ldquo;{t.quote}&rdquo;
                  </blockquote>
                </CardContent>
                <CardHeader>
                  <CardTitle className="flex items-center gap-3">
                    <span className="flex size-8 items-center justify-center rounded-full bg-muted text-xs font-semibold">
                      {t.name[0]}
                    </span>
                    <span>
                      {t.name}
                      <span className="ml-2 text-sm font-normal text-muted-foreground">
                        {t.role}
                      </span>
                    </span>
                  </CardTitle>
                </CardHeader>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="py-24 md:py-32">
        <div className="mx-auto max-w-6xl px-6 text-center">
          <h2 className="text-3xl font-bold tracking-tight md:text-4xl lg:text-5xl">
            Built for the future.
            <br />
            <span className="text-muted-foreground">Available today.</span>
          </h2>
          <p className="mx-auto mt-6 max-w-md text-muted-foreground">
            Clone the template and start shipping in minutes. MIT licensed, forever free.
          </p>
          <div className="mt-10 flex items-center justify-center gap-3">
            <Button size="lg">Get Started</Button>
            <Button variant="outline" size="lg">
              View on GitHub
            </Button>
          </div>
        </div>
      </section>

      <Footer />
    </div>
  );
}
