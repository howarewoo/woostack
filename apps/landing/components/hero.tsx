import { Button } from "@infrastructure/ui-web";
import { BrowserFrame } from "./browser-frame";
import { PhoneFrame } from "./phone-frame";

/** Subtle dot-grid background pattern for the hero section. */
const DOT_GRID_STYLE = {
  backgroundImage: "radial-gradient(circle, currentColor 1px, transparent 1px)",
  backgroundSize: "24px 24px",
} as const;

/** Hero section with headline, subtitle, and responsive device frame previews. */
export function Hero() {
  return (
    <section className="relative overflow-hidden border-b border-border/40">
      {/* Subtle dot grid background */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.03]"
        aria-hidden="true"
        style={DOT_GRID_STYLE}
      />

      <div className="relative mx-auto max-w-6xl px-6 pb-20 pt-24 md:pb-28 md:pt-32">
        {/* Announcement badge */}
        <div className="mb-8 flex justify-center">
          <span className="inline-flex items-center gap-2 rounded-full border border-border/60 bg-muted/50 px-4 py-1.5 text-xs font-medium text-muted-foreground">
            <span className="size-1.5 rounded-full bg-primary" />
            Now with Supabase Auth, Database & Storage
          </span>
        </div>

        {/* Headline */}
        <h1 className="mx-auto max-w-3xl text-center text-4xl font-bold leading-[1.1] tracking-tight md:text-5xl lg:text-6xl">
          The modern monorepo
          <br />
          <span className="text-muted-foreground">template</span>
        </h1>

        {/* Subtitle */}
        <p className="mx-auto mt-6 max-w-xl text-center text-base leading-relaxed text-muted-foreground md:text-lg">
          Ship web, mobile, and API from a single codebase. Authentication, database, and storage
          included. Type-safe from backend to device.
        </p>

        {/* CTA buttons */}
        <div className="mt-10 flex items-center justify-center gap-3">
          <Button size="lg">Get Started</Button>
          <Button variant="outline" size="lg">
            View on GitHub
          </Button>
        </div>

        {/* Responsive device frames */}
        <div className="mx-auto mt-16 max-w-3xl">
          <div className="hidden md:block">
            <BrowserFrame />
          </div>
          <div className="block md:hidden">
            <PhoneFrame />
          </div>
        </div>
      </div>
    </section>
  );
}
