import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-6 px-4 py-24 text-center">
      <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">woostack</h1>
      <p className="max-w-2xl text-lg text-fd-muted-foreground">
        Plan work and deliver reviewable changes with your AI coding assistant. You decide what
        changes and when to merge.
      </p>
      <code className="rounded-lg bg-fd-muted px-4 py-2 text-sm font-medium">
        pnpx skills add howarewoo/woostack
      </code>
      <div className="flex flex-wrap items-center justify-center gap-3">
        <Link
          href="/docs/getting-started"
          className="rounded-lg bg-fd-primary px-5 py-2.5 font-medium text-fd-primary-foreground transition-opacity hover:opacity-90"
        >
          Create your first plan
        </Link>
        <a
          href="https://github.com/howarewoo/woostack"
          className="rounded-lg border border-fd-border px-5 py-2.5 font-medium transition-colors hover:bg-fd-accent"
        >
          GitHub
        </a>
      </div>
    </main>
  );
}
