import {
  lazy,
  Suspense,
  useEffect,
  useRef,
  useState,
  type ComponentType,
  type KeyboardEvent,
} from "react";
import { useTheme } from "next-themes";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarTrigger,
  useSidebar,
} from "@/components/ui/sidebar";
import {
  Command,
  CommandDialog,
  CommandInput,
  CommandList,
  CommandEmpty,
  CommandGroup,
  CommandItem,
} from "@/components/ui/command";
import { TooltipProvider } from "@/components/ui/tooltip";
import baseline from "./inventory.json";

type Entry = {
  id: string;
  name: string;
  group: string;
  specimen: string;
  importPath: string;
  importExample: string;
  coverage: string;
  source?: string;
  provenance?: string;
};
const entries: Entry[] = [...baseline.entries, ...baseline.projectExtensions];
const modules = import.meta.glob<{ default: ComponentType }>("./examples/**/*.tsx");
const sources = import.meta.glob("./examples/**/*.tsx", {
  query: "?raw",
  import: "default",
  eager: true,
}) as Record<string, string>;
const specimens = Object.fromEntries(
  entries.map((entry) => [entry.id, lazy(modules[`./${entry.specimen.replace(/^src\//, "")}`])]),
);
const groups = [...new Set(entries.map((entry) => entry.group))];

export default function App() {
  return (
    <TooltipProvider>
      <SidebarProvider>
        <Catalog />
      </SidebarProvider>
    </TooltipProvider>
  );
}

function Catalog() {
  const { isMobile, openMobile, setOpenMobile } = useSidebar();
  const { theme, setTheme } = useTheme();
  const [search, setSearch] = useState("");
  const [active, setActive] = useState(() => location.hash.slice(1) || "home");
  const [command, setCommand] = useState(false);
  const [copyStatus, setCopyStatus] = useState("");
  const heading = useRef<HTMLHeadingElement>(null);
  const searchInput = useRef<HTMLInputElement>(null);
  const navigationPending = useRef(Boolean(location.hash));
  const entry = entries.find((item) => item.id === active);
  const results = entries.filter((item) =>
    `${item.name} ${item.group}`.toLowerCase().includes(search.toLowerCase()),
  );
  const Specimen = entry ? specimens[entry.id] : null;
  const sourceKey = entry ? `./${entry.specimen.replace(/^src\//, "")}` : "";

  useEffect(() => {
    const navigate = () => {
      navigationPending.current = true;
      setActive(location.hash.slice(1) || "home");
      setSearch("");
      setCommand(false);
      setOpenMobile(false);
    };
    window.addEventListener("hashchange", navigate);
    window.addEventListener("popstate", navigate);
    return () => {
      window.removeEventListener("hashchange", navigate);
      window.removeEventListener("popstate", navigate);
    };
  }, [setOpenMobile]);

  useEffect(() => {
    setCopyStatus("");
    if (!navigationPending.current || command || openMobile) return;
    // Wait for focus-managed overlays to finish closing before destination focus.
    let frame = 0;
    const focusDestination = () => {
      if (document.querySelector('[data-slot="sheet-overlay"], [data-slot="dialog-overlay"]')) {
        frame = requestAnimationFrame(focusDestination);
        return;
      }
      navigationPending.current = false;
      heading.current?.focus({ preventScroll: true });
      window.scrollTo({ top: 0, behavior: "instant" });
    };
    frame = requestAnimationFrame(focusDestination);
    return () => cancelAnimationFrame(frame);
  }, [active, command, openMobile]);

  useEffect(() => {
    const key = (event: globalThis.KeyboardEvent) => {
      const editing =
        event.target instanceof HTMLElement &&
        (event.target.matches("input,textarea,select") || event.target.isContentEditable);
      if ((event.metaKey || event.ctrlKey) && !event.altKey && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setCommand((open) => !open);
      } else if (
        event.key === "/" &&
        !event.metaKey &&
        !event.ctrlKey &&
        !event.altKey &&
        !editing
      ) {
        event.preventDefault();
        if (isMobile) setCommand(true);
        else searchInput.current?.focus();
      }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [isMobile]);

  function choose(id: string) {
    navigationPending.current = true;
    setSearch("");
    setCommand(false);
    setOpenMobile(false);
    if (location.hash !== `#${id}`) location.hash = id;
    else if (!command && !openMobile) {
      navigationPending.current = false;
      heading.current?.focus();
    }
  }

  function navKeys(event: KeyboardEvent<HTMLElement>) {
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return;
    const links = Array.from(event.currentTarget.querySelectorAll<HTMLAnchorElement>("a[href]"));
    const index = links.indexOf(document.activeElement as HTMLAnchorElement);
    if (index < 0) return;
    event.preventDefault();
    const next =
      event.key === "Home"
        ? 0
        : event.key === "End"
          ? links.length - 1
          : (index + (event.key === "ArrowDown" ? 1 : -1) + links.length) % links.length;
    links[next]?.focus();
  }

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopyStatus("Copied to clipboard");
    } catch {
      setCopyStatus("Clipboard unavailable. Select and copy the example below.");
    }
  }

  return (
    <>
      <Sidebar>
        <SidebarHeader>
          <a href="#home" onClick={() => choose("home")} className="font-semibold p-2">
            Project design system
          </a>
          <label htmlFor="catalog-search" className="text-sm">
            Search components
          </label>
          <Input
            id="catalog-search"
            ref={searchInput}
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search… (/)"
          />
          <p aria-live="polite" className="text-xs text-muted-foreground">
            {results.length} results
          </p>
        </SidebarHeader>
        <SidebarContent onKeyDown={navKeys}>
          {groups.map((group) => (
            <SidebarGroup key={group}>
              <SidebarGroupLabel>{group}</SidebarGroupLabel>
              <SidebarMenu>
                {results
                  .filter((item) => item.group === group)
                  .map((item) => (
                    <SidebarMenuItem key={item.id}>
                      <SidebarMenuButton
                        isActive={active === item.id}
                        render={
                          <a
                            href={`#${item.id}`}
                            onClick={(event) => {
                              event.preventDefault();
                              choose(item.id);
                            }}
                          />
                        }
                      >
                        {item.name}
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  ))}
              </SidebarMenu>
            </SidebarGroup>
          ))}
          {!results.length && <p className="p-4">No matching components. Try another search.</p>}
        </SidebarContent>
      </Sidebar>
      <main className="catalog-main">
        <header className="sticky top-0 z-10 flex flex-wrap items-center gap-3 border-b bg-background py-3 mb-8">
          <SidebarTrigger />
          <Button variant="outline" onClick={() => setCommand(true)}>
            Find component <kbd>⌘/Ctrl K</kbd>
          </Button>
          <label htmlFor="appearance" className="ml-auto text-sm">
            Appearance
          </label>
          <select
            id="appearance"
            className="rounded border bg-background p-2 text-sm"
            value={theme ?? "system"}
            onChange={(event) => setTheme(event.target.value)}
          >
            <option value="system">System</option>
            <option value="light">Light</option>
            <option value="dark">Dark</option>
          </select>
        </header>
        <section id={entry?.id ?? "home"} className="catalog-section space-y-6">
          <h1 ref={heading} tabIndex={-1} className="text-3xl font-semibold">
            {entry?.name ?? (active === "home" ? "Project design system" : "Component not found")}
          </h1>
          {entry && Specimen ? (
            <>
              <p className="text-sm text-muted-foreground">
                {entry.provenance ?? baseline.upstream.provenance}{" "}
                <a
                  className="underline"
                  href={entry.source ?? baseline.upstream.catalog}
                  target="_blank"
                  rel="noreferrer"
                >
                  Component guidance
                </a>
              </p>
              <div className="rounded border p-4 overflow-x-auto">
                <Suspense fallback={<p role="status">Loading specimen…</p>}>
                  <Specimen />
                </Suspense>
              </div>
              <h2 className="text-xl font-semibold">Public import</h2>
              <pre className="rounded bg-muted p-4 overflow-auto">
                <code>{entry.importExample}</code>
              </pre>
              <Button variant="outline" onClick={() => copy(entry.importExample)}>
                Copy import
              </Button>
              <h2 className="text-xl font-semibold">Live adoption example</h2>
              <p className="text-sm text-muted-foreground">
                This exact source renders the specimen above. Local interactions demonstrate
                controls, not product features. See the canonical component guidance for usage and
                keyboard contracts.
              </p>
              <Button variant="outline" onClick={() => copy(sources[sourceKey])}>
                Copy example
              </Button>
              <p role="status">{copyStatus}</p>
              <pre className="rounded border bg-muted p-4 max-h-96 overflow-auto text-xs">
                <code>{sources[sourceKey]}</code>
              </pre>
            </>
          ) : (
            <>
              <p>
                The canonical inventory covers{" "}
                {baseline.entries.filter((item) => item.coverage === "upstream").length} upstream
                entries and{" "}
                {baseline.entries.filter((item) => item.coverage === "owned-foundation").length}{" "}
                owned foundations. Project extensions are recorded separately.
              </p>
              <h2 className="text-xl font-semibold">Colors and tokens</h2>
              <p>
                Neutral shadcn semantic tokens drive catalog chrome and controls. Preserve target
                tokens when adapting.
              </p>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                {[
                  "background",
                  "foreground",
                  "primary",
                  "secondary",
                  "muted",
                  "accent",
                  "destructive",
                  "border",
                ].map((token) => (
                  <div key={token} className="rounded border p-3">
                    <div
                      className="h-16 rounded border"
                      style={{ background: `var(--${token})` }}
                    />
                    <code className="text-sm">--{token}</code>
                  </div>
                ))}
              </div>
              <h2 className="text-xl font-semibold">Component inventory</h2>
              <div className="flex flex-wrap gap-2">
                {entries.map((item) => (
                  <Button key={item.id} variant="outline" onClick={() => choose(item.id)}>
                    {item.name}
                  </Button>
                ))}
              </div>
            </>
          )}
        </section>
      </main>
      <CommandDialog
        open={command}
        onOpenChange={setCommand}
        showCloseButton
        className="[&_[data-slot=command-input-wrapper]]:pr-10"
      >
        <Command>
          <CommandInput placeholder="Find a component…" />
          <CommandList>
            <CommandEmpty>No matching components.</CommandEmpty>
            {groups.map((group) => (
              <CommandGroup key={group} heading={group}>
                {entries
                  .filter((item) => item.group === group)
                  .map((item) => (
                    <CommandItem
                      key={item.id}
                      value={`${item.name} ${item.group}`}
                      onSelect={() => choose(item.id)}
                    >
                      {item.name}
                    </CommandItem>
                  ))}
              </CommandGroup>
            ))}
          </CommandList>
        </Command>
      </CommandDialog>
    </>
  );
}
