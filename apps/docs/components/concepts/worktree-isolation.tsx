/**
 * WorktreeIsolation component for the Parallelism with worktrees concept page.
 *
 * Explains what Git worktrees isolate per task versus what remains shared.
 * Responsive semantic HTML with Fumadocs theme utilities.
 */
export function WorktreeIsolation() {
  return (
    <figure className="not-prose my-6 rounded-xl border border-fd-border bg-fd-card p-4 sm:p-6">
      <div className="flex flex-col gap-4">
        <div>
          <h3 className="text-sm font-semibold text-fd-foreground">Worktree isolation boundary</h3>
          <p className="text-xs text-fd-muted-foreground mt-0.5">
            Git worktrees isolate filesystem edits and branches while sharing repository history and
            system runtime.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {/* Isolated per worktree */}
          <div className="rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <span className="rounded bg-fd-primary/10 px-2 py-0.5 text-xs font-semibold text-fd-primary">
              Isolated per task
            </span>
            <h4 className="mt-2 text-sm font-semibold text-fd-foreground">Task workspace</h4>
            <ul className="mt-2 space-y-1 text-xs text-fd-muted-foreground">
              <li>• Dedicated directory and working files</li>
              <li>• Independent Git branch and HEAD</li>
              <li>• Separate staging index and unstaged diffs</li>
              <li>• Isolated edits protect primary checkout</li>
            </ul>
          </div>

          {/* Shared across worktrees */}
          <div className="rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-semibold text-fd-muted-foreground">
              Shared across tasks
            </span>
            <h4 className="mt-2 text-sm font-semibold text-fd-foreground">
              Repository &amp; system runtime
            </h4>
            <ul className="mt-2 space-y-1 text-xs text-fd-muted-foreground">
              <li>
                • Shared Git object database (<code>.git/objects</code>)
              </li>
              <li>• Local network ports and web servers</li>
              <li>• Databases and background daemon services</li>
              <li>• Host secret store and credentials</li>
            </ul>
          </div>
        </div>

        <div className="rounded-lg border border-fd-border/70 bg-fd-muted/40 px-3 py-2 text-center text-xs text-fd-muted-foreground">
          Ownership rule: Exactly one active writer per workspace. Concurrent writers require
          separate worktrees.
        </div>
      </div>
    </figure>
  );
}

export default WorktreeIsolation;
