/* MIT: Copyright (c) 2023 shadcn. See LICENSE. Browser-only catalog adaptation. */
"use client";
import { CheckIcon, ChevronsUpDownIcon, SearchIcon } from "lucide-react";

import * as React from "react";

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Item, ItemActions, ItemContent, ItemDescription, ItemTitle } from "@/components/ui/item";
import { Label } from "@/components/ui/label";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarInput,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarRail,
  SidebarTrigger,
} from "@/components/ui/sidebar";

export default function SidebarExample() {
  const data = {
    versions: ["1.0.1", "1.1.0-alpha", "2.0.0-beta1"],
    navMain: [
      {
        title: "Getting Started",
        items: [
          {
            title: "Installation",
          },
          {
            title: "Project Structure",
          },
        ],
      },
      {
        title: "Build Your Application",
        items: [
          {
            title: "Routing",
          },
          {
            title: "Data Fetching",
          },
          {
            title: "Rendering",
          },
          {
            title: "Caching",
          },
          {
            title: "Styling",
          },
          {
            title: "Optimizing",
          },
          {
            title: "Configuring",
          },
          {
            title: "Testing",
          },
          {
            title: "Authentication",
          },
          {
            title: "Deploying",
          },
          {
            title: "Upgrading",
          },
          {
            title: "Examples",
          },
        ],
      },
      {
        title: "API Reference",
        items: [
          {
            title: "Components",
          },
          {
            title: "File Conventions",
          },
          {
            title: "Functions",
          },
          {
            title: "next.config.js Options",
          },
          {
            title: "CLI",
          },
          {
            title: "Edge Runtime",
          },
        ],
      },
      {
        title: "Architecture",
        items: [
          {
            title: "Accessibility",
          },
          {
            title: "Fast Refresh",
          },
          {
            title: "Next.js Compiler",
          },
          {
            title: "Supported Browsers",
          },
          {
            title: "Turbopack",
          },
        ],
      },
    ],
  };

  const [selectedVersion, setSelectedVersion] = React.useState(data.versions[0]);
  const [selectedPage, setSelectedPage] = React.useState("Data Fetching");

  return (
    <SidebarProvider className="relative isolate h-[32rem] min-h-0 overflow-hidden [transform:translateZ(0)]">
      <Sidebar className="h-full">
        <SidebarHeader>
          <SidebarMenu>
            <SidebarMenuItem>
              <DropdownMenu>
                <DropdownMenuTrigger
                  render={
                    <SidebarMenuButton
                      size="lg"
                      className="data-open:bg-sidebar-accent data-open:text-sidebar-accent-foreground"
                    />
                  }
                >
                  <Item className="p-0" size="xs">
                    <ItemContent>
                      <ItemTitle className="text-sm">Documentation</ItemTitle>
                      <ItemDescription>v{selectedVersion}</ItemDescription>
                    </ItemContent>
                    <ItemActions>
                      <ChevronsUpDownIcon />
                    </ItemActions>
                  </Item>
                </DropdownMenuTrigger>
                <DropdownMenuContent>
                  {data.versions.map((version) => (
                    <DropdownMenuItem key={version} onSelect={() => setSelectedVersion(version)}>
                      v{version} {version === selectedVersion && <CheckIcon className="ml-auto" />}
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
            </SidebarMenuItem>
          </SidebarMenu>
          <form>
            <SidebarGroup className="py-0">
              <SidebarGroupContent className="relative">
                <Label htmlFor="search" className="sr-only">
                  Search
                </Label>
                <SidebarInput id="search" placeholder="Search the docs..." className="pl-8" />
                <SearchIcon className="pointer-events-none absolute top-1/2 left-2 size-4 -translate-y-1/2 opacity-50 select-none" />
              </SidebarGroupContent>
            </SidebarGroup>
          </form>
        </SidebarHeader>
        <SidebarContent>
          {data.navMain.map((item) => (
            <SidebarGroup key={item.title}>
              <SidebarGroupLabel>{item.title}</SidebarGroupLabel>
              <SidebarGroupContent>
                <SidebarMenu>
                  {item.items.map((subItem) => (
                    <SidebarMenuItem key={subItem.title}>
                      <SidebarMenuButton
                        onClick={() => setSelectedPage(subItem.title)}
                        isActive={selectedPage === subItem.title}
                      >
                        {subItem.title}
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  ))}
                </SidebarMenu>
              </SidebarGroupContent>
            </SidebarGroup>
          ))}
        </SidebarContent>
        <SidebarRail />
      </Sidebar>
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 px-4">
          <SidebarTrigger className="-ml-1" />
        </header>
        <div className="flex flex-1 flex-col gap-4 p-4">
          <h2 className="text-lg font-semibold" aria-live="polite">
            {selectedPage}
          </h2>
          <p className="text-sm text-muted-foreground">
            Documentation preview · v{selectedVersion}
          </p>
          <div className="grid auto-rows-min gap-4 md:grid-cols-3">
            <div className="aspect-video rounded-xl bg-muted/50" />
            <div className="aspect-video rounded-xl bg-muted/50" />
            <div className="aspect-video rounded-xl bg-muted/50" />
          </div>
          <div className="min-h-32 flex-1 rounded-xl bg-muted/50" />
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}
