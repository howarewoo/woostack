import { PERSPECTIVE_STYLE } from "./shared-styles";

/** Slight perspective tilt to suggest depth in the browser chrome mockup. */
const BROWSER_TRANSFORM_STYLE = { transform: "rotateX(2deg) rotateY(-1deg)" } as const;

/**
 * macOS traffic light button colors (used as static Tailwind arbitrary values below):
 * - Close:    #ff5f57  -> bg-[#ff5f57]
 * - Minimize: #febc2e  -> bg-[#febc2e]
 * - Maximize: #28c840  -> bg-[#28c840]
 *
 * Tailwind requires complete class strings at build time,
 * so these hex values are inlined in the JSX rather than interpolated from constants.
 */

const USER_ROWS = [
  { name: "Alex Chen", email: "alex@example.com", id: "1" },
  { name: "Sarah Park", email: "sarah@example.com", id: "2" },
] as const;

const INFRA_PACKAGES = ["api-client", "navigation", "supabase", "ui", "ui-web", "utils"] as const;
const TOOLING = ["Turborepo", "pnpm", "Biome", "Vitest", "Playwright"] as const;
const BADGE_SECTIONS = [
  { label: "Shared Infrastructure", items: INFRA_PACKAGES },
  { label: "Tooling", items: TOOLING },
] as const;

/** Desktop browser chrome mockup showing an authenticated dashboard. */
export function BrowserFrame() {
  return (
    <div style={PERSPECTIVE_STYLE}>
      <div
        className="overflow-hidden rounded-xl bg-card shadow-2xl ring-1 ring-foreground/5"
        style={BROWSER_TRANSFORM_STYLE}
      >
        {/* Chrome bar */}
        <div className="flex items-center gap-2 border-b border-border/60 bg-muted/30 px-4 py-2.5">
          {/* macOS traffic light close/minimize/maximize buttons */}
          <div className="flex items-center gap-1.5" aria-hidden="true">
            <span className="size-2.5 rounded-full bg-[#ff5f57]" />
            <span className="size-2.5 rounded-full bg-[#febc2e]" />
            <span className="size-2.5 rounded-full bg-[#28c840]" />
          </div>
          <div className="ml-3 flex-1">
            <div className="mx-auto max-w-xs rounded-md bg-background/60 px-3 py-1 text-center text-[10px] text-muted-foreground">
              localhost:3000
            </div>
          </div>
          {/* Spacer: balances the traffic-light dots (3 x 10px + 2 x 6px gap) + ml-3 (12px) on the left */}
          <div className="w-[62px]" />
        </div>

        {/* Dashboard content — 16:10 MacBook aspect ratio */}
        <div className="aspect-[16/10] bg-background p-5">
          {/* Header bar */}
          <div className="mb-3 flex items-center justify-between">
            <div className="text-[11px] font-semibold text-foreground">Monorepo Template</div>
            <div className="flex items-center gap-2">
              <span className="flex size-4 items-center justify-center rounded-full bg-primary text-[7px] font-semibold text-primary-foreground">
                u
              </span>
              <span className="text-[8px] text-muted-foreground">user@email.com</span>
              <span className="rounded bg-muted px-1.5 py-0.5 text-[7px] text-muted-foreground">
                Sign Out
              </span>
            </div>
          </div>

          {/* Welcome */}
          <div className="mb-3">
            <div className="text-[12px] font-bold text-foreground">Welcome back</div>
            <div className="text-[8px] text-muted-foreground">user@email.com</div>
          </div>

          {/* Users card */}
          <div className="rounded-lg border border-border/60 bg-card p-2.5">
            <div className="text-[10px] font-semibold text-foreground">Users from API</div>
            <div className="mt-1.5 flex flex-col gap-1">
              {USER_ROWS.map((row) => (
                <div
                  key={row.name}
                  className="flex items-center justify-between rounded border border-border/40 px-2 py-1"
                >
                  <div>
                    <div className="text-[8px] font-medium text-foreground">{row.name}</div>
                    <div className="text-[7px] text-muted-foreground">{row.email}</div>
                  </div>
                  <div className="text-[7px] text-muted-foreground">ID: {row.id}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Infrastructure badges */}
          <div className="mt-2.5 grid grid-cols-2 gap-2.5">
            {BADGE_SECTIONS.map((section) => (
              <div key={section.label} className="rounded-lg border border-border/60 bg-card p-2.5">
                <div className="mb-1.5 text-[10px] font-semibold text-foreground">
                  {section.label}
                </div>
                <div className="flex flex-wrap gap-1">
                  {section.items.map((name) => (
                    <span
                      key={name}
                      className="rounded bg-muted px-1.5 py-0.5 text-[8px] text-muted-foreground"
                    >
                      {name}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
