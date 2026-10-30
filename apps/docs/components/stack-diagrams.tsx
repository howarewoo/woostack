import { Diagram, Group, Label, Node } from "./diagram";

// Callers supply a page-unique id so SVG markers and accessible names never collide.
export function StackRuntimeDiagram({ id }: { id: string }) {
  return (
    <Diagram
      id={id}
      title="Two hostnames, one Worker"
      height={670}
      description="The browser visits example.com for the public site or app.example.com for the SaaS application. Both Custom Domains enter the same Cloudflare Worker, which dispatches by hostname before looking up assets. The root host serves Astro HTML and files from the internal /site/ asset directory. The app host serves React and TanStack Router from the internal /app/ directory, with a shell fallback only for HTML navigation. Its /api endpoints reach Hono, oRPC, and Zod before asset lookup. The API uses Drizzle and pg through Hyperdrive to reach external Neon PostgreSQL. The app browser uses managed Neon Auth for sign-in and sessions."
      caption="Solid arrows show request and data flow; the dashed arrow shows sign-in. Asset prefixes are internal, not public URLs. Missing public pages, API routes, and static files return 404. The API verifies sessions and authorization; the browser never connects directly to the database."
    >
      <Group y={246} height={284} title="One Worker + its static assets" />
      <g fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" markerEnd={`url(#${id}-arrow)`}>
        <path d="M 260 92 V 114 H 166 V 150" />
        <path d="M 300 92 V 114 H 562 V 150" />
        <path d="M 662 150 V 92" strokeDasharray="5 4" markerStart={`url(#${id}-arrow)`} />
        <path d="M 166 216 V 234 H 330 V 290" />
        <path d="M 590 216 V 234 H 430 V 290" />
        <path d="M 330 356 V 382 H 148 V 424" />
        <path d="M 380 356 V 424" />
        <path d="M 430 356 V 382 H 612 V 424" />
        <path d="M 612 506 V 584" />
        <path d="M 512 617 H 360" />
      </g>
      <Label x={701} y={126}>sign-in</Label>
      <Label x={380} y={230}>Custom Domains</Label>
      <Label x={148} y={408}>root host</Label>
      <Label x={380} y={408}>app pages</Label>
      <Label x={612} y={408}>app /api/*</Label>
      <Label x={636} y={563}>SQL</Label>
      <Label x={435} y={603}>pooled SQL</Label>
      <Node x={150} y={26} width={220} title="Browser" lines={["Visitors and SaaS users"]} />
      <Node x={500} y={26} width={212} title="Managed Neon Auth" lines={["External authentication"]} />
      <Node x={54} y={150} width={226} title="example.com" lines={["Landing pages + blog"]} />
      <Node x={480} y={150} width={232} title="app.example.com" lines={["SaaS screens + API calls"]} />
      <Node x={270} y={290} width={220} title="Hostname dispatcher" lines={["Worker-first routing"]} accent />
      <Node x={48} y={424} height={82} title="Astro public site" lines={["Static HTML + files", "ASSETS: /site/*"]} />
      <Node x={280} y={424} height={82} title="React SPA" lines={["Vite + TanStack Router", "ASSETS: /app/*"]} />
      <Node x={512} y={424} height={82} title="Hono API" lines={["oRPC + Zod", "Drizzle ORM + pg"]} />
      <Node x={512} y={584} title="Hyperdrive" lines={["Connection pooling"]} />
      <Node x={120} y={584} width={240} title="Neon PostgreSQL" lines={["External database"]} />
    </Diagram>
  );
}

export function StackDeliveryDiagram({ id }: { id: string }) {
  return (
    <Diagram
      id={id}
      title="Source apps to one release"
      height={760}
      description="Three separate pnpm workspace apps feed one GitHub Actions pipeline: apps/site contains Astro pages and blog content; apps/app contains React, Vite, TanStack Router, Query, and the oRPC client; apps/api contains hostname dispatch, Hono, and Wrangler configuration. GitHub Actions checks, builds, assembles, and verifies one release containing dist/assets/site/, dist/assets/app/, and the Worker bundle with deployment configuration and bindings. Wrangler deploys that verified output together to one Cloudflare Worker serving example.com and app.example.com. Both frontends are built for their hostname's root path."
      caption="GitHub Actions releases and rolls back the site, app, and API as one unit. Shared UI packages are optional. Preview environments use their own hostname pair, bindings, and data. Drizzle Kit migrations are a separate release step."
    >
      <Group y={20} height={144} title="pnpm workspace sources" />
      <Group y={350} height={146} title="Release artifact" />
      <g fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" markerEnd={`url(#${id}-arrow)`}>
        <path d="M 148 142 V 190 H 296 V 228" />
        <path d="M 380 142 V 228" />
        <path d="M 612 142 V 190 H 464 V 228" />
        <path d="M 296 296 V 326 H 148 V 404" />
        <path d="M 380 296 V 404" />
        <path d="M 464 296 V 326 H 612 V 404" />
        <path d="M 148 470 V 526 H 320 V 558" />
        <path d="M 380 470 V 558" />
        <path d="M 612 470 V 526 H 440 V 558" />
        <path d="M 380 624 V 678" />
      </g>
      <Node x={48} y={76} title="apps/site" lines={["Astro public site"]} />
      <Node x={280} y={76} title="apps/app" lines={["React + TanStack Router"]} />
      <Node x={512} y={76} title="apps/api" lines={["Hono + dispatch + config"]} />
      <Node x={238} y={228} width={284} height={68} title="GitHub Actions" lines={["Check · build · assemble · verify"]} accent />
      <Node x={48} y={404} title="Site assets" lines={["dist/assets/site/"]} />
      <Node x={280} y={404} title="App assets" lines={["dist/assets/app/"]} />
      <Node x={512} y={404} title="Worker bundle" lines={["Configuration + bindings"]} />
      <Node x={260} y={558} width={240} title="Wrangler" lines={["Deploy verified output together"]} />
      <Node x={220} y={678} width={320} title="One Cloudflare Worker" lines={["example.com + app.example.com"]} accent />
    </Diagram>
  );
}
