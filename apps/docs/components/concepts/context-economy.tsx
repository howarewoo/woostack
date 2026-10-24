/**
 * Context-economy diagram for the Core concepts and Context management pages.
 *
 * Three mechanisms feed one scarce resource: the agent's working context.
 * Scoped instructions, shell scripts, and subagents each keep heavy work out
 * of the main context window.
 * Responsive semantic HTML with Fumadocs theme utilities.
 */
export function ContextEconomy() {
  const mechanisms = [
    {
      title: "Scoped instructions",
      sub: "Load only applicable rules for the active workflow.",
      tag: "Rules",
    },
    {
      title: "Scripts compute",
      sub: "Run heavy calculation in shell; return small text output.",
      tag: "Execution",
    },
    {
      title: "Subagents isolate",
      sub: "Perform bounded task in separate context; return summary.",
      tag: "Isolation",
    },
  ];

  return (
    <figure className="not-prose my-6 rounded-xl border border-fd-border bg-fd-card p-4 sm:p-6">
      <div className="flex flex-col gap-4">
        <div>
          <h3 className="text-sm font-semibold text-fd-foreground">
            Context economy: three mechanisms, one scarce resource
          </h3>
          <p className="text-xs text-fd-muted-foreground mt-0.5">
            Keep working memory focused by isolating heavy operations outside the main context
            window.
          </p>
        </div>

        {/* Three mechanism cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          {mechanisms.map((m) => (
            <div
              key={m.title}
              className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-3.5"
            >
              <div>
                <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-semibold text-fd-muted-foreground">
                  {m.tag}
                </span>
                <h4 className="mt-2 text-sm font-semibold text-fd-foreground">{m.title}</h4>
              </div>
              <p className="mt-2 text-xs text-fd-muted-foreground">{m.sub}</p>
            </div>
          ))}
        </div>

        {/* Downward connector */}
        <div className="flex items-center justify-center gap-2 text-xs font-medium text-fd-muted-foreground">
          <span className="hidden sm:inline">Protects</span>
          <span aria-hidden="true">↓</span>
        </div>

        {/* The scarce resource */}
        <div className="rounded-lg border border-fd-primary/30 bg-fd-primary/5 p-4 text-center">
          <div className="text-xs font-semibold uppercase tracking-wider text-fd-primary">
            Scarce Resource
          </div>
          <div className="mt-1 text-sm font-bold text-fd-foreground">Agent working context</div>
          <p className="mt-1 text-xs text-fd-muted-foreground">
            Kept focused on user goals, active decisions, and verified evidence.
          </p>
        </div>
      </div>
    </figure>
  );
}

export default ContextEconomy;
