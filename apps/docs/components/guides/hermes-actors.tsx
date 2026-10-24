/**
 * HermesActors component for the Use Hermes with OMP guide.
 *
 * Details the three actor boundaries: Hermes, Responsible User, and OMP Coding Session.
 * Responsive semantic HTML with Fumadocs theme utilities.
 */
export function HermesActors() {
  const actors = [
    {
      role: "Hermes",
      subtitle: "External engineer",
      can: [
        "Coordinates process and reviews diffs",
        "Checks contract compliance and blockers",
        "Requests in-scope corrections",
      ],
      cannot: "Cannot edit source, run builds, commit, push, or merge",
      badge: "Review & Coordinate",
    },
    {
      role: "Responsible user",
      subtitle: "Decision authority",
      can: [
        "Approves scope changes and new tasks",
        "Answers pending questions (Asks)",
        "Retains exclusive merge authority",
      ],
      cannot: "Answers relayed live and verbatim through the process",
      badge: "Authority",
    },
    {
      role: "OMP session",
      subtitle: "Coding harness",
      can: [
        "Executes agent skills and tools",
        "Edits source code and runs tests",
        "Maintains persistent process state",
      ],
      cannot: "Controlled by OMP profile and active tool schema",
      badge: "Execution",
    },
  ];

  return (
    <figure className="not-prose my-6 rounded-xl border border-fd-border bg-fd-card p-4 sm:p-6">
      <div className="flex flex-col gap-4">
        <div>
          <h3 className="text-sm font-semibold text-fd-foreground">
            Hermes and OMP actor boundaries
          </h3>
          <p className="text-xs text-fd-muted-foreground mt-0.5">
            Strict separation between external coordination, user decisions, and harness
            implementation.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {actors.map((a) => (
            <div
              key={a.role}
              className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4"
            >
              <div>
                <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-semibold text-fd-muted-foreground">
                  {a.badge}
                </span>
                <h4 className="mt-2 text-sm font-semibold text-fd-foreground">{a.role}</h4>
                <p className="text-xs text-fd-muted-foreground">{a.subtitle}</p>
                <ul className="mt-3 space-y-1 text-xs text-fd-foreground">
                  {a.can.map((item) => (
                    <li key={item}>• {item}</li>
                  ))}
                </ul>
              </div>
              <p className="mt-3 border-t border-fd-border/60 pt-2 text-xs font-medium text-fd-muted-foreground">
                {a.cannot}
              </p>
            </div>
          ))}
        </div>
      </div>
    </figure>
  );
}

export default HermesActors;
