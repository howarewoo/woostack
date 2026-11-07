"use client";

import { RootProvider } from "fumadocs-ui/provider/next";
import { DocsSearchDialog } from "./search-dialog";
import type { ReactNode } from "react";

export function DocsProvider({ children }: { children: ReactNode }) {
  return <RootProvider search={{ SearchDialog: DocsSearchDialog }}>{children}</RootProvider>;
}
