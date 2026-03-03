import { ThemeToggle } from "@/components/theme-toggle";

/**
 * Brand Kit home page — the shell landing point for the design system reference.
 * Phase 2+ will populate the main area with color swatches, typography, and components.
 */
export default function Page() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <header className="flex items-center justify-between border-b border-border px-6 py-4">
        <h1 className="text-lg font-semibold">Brand Kit</h1>
        <ThemeToggle />
      </header>
      <main className="mx-auto max-w-6xl px-6 py-12">
        <p className="text-muted-foreground">Design system content coming in Phase 2.</p>
      </main>
    </div>
  );
}
