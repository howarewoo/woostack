const technologies = [
  "Next.js",
  "Expo",
  "React Native",
  "Hono",
  "oRPC",
  "Supabase",
  "Tailwind CSS",
  "TypeScript",
  "Turborepo",
];

/** Horizontal strip of technology names showcasing the template's stack. */
export function TechStackBar() {
  return (
    <section className="border-b border-border/40 py-10">
      <div className="mx-auto max-w-6xl px-6">
        <p className="mb-6 text-center text-xs font-medium uppercase tracking-widest text-muted-foreground/60">
          Built with
        </p>
        <div className="flex flex-wrap items-center justify-center gap-x-10 gap-y-4">
          {technologies.map((name) => (
            <span
              key={name}
              className="text-sm font-medium text-muted-foreground/50 transition-colors hover:text-muted-foreground"
            >
              {name}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}
