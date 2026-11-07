"use client";

import { use, useMemo, useRef, useState } from "react";
import { useDocsSearch } from "fumadocs-core/search/client";
import { fetchClient } from "fumadocs-core/search/client/fetch";
import { useOnChange } from "fumadocs-core/utils/use-on-change";
import { useI18n } from "fumadocs-ui/contexts/i18n";
import type { DefaultSearchDialogProps } from "fumadocs-ui/components/dialog/search-default";
import {
  SearchDialog,
  SearchDialogClose,
  SearchDialogContent,
  SearchDialogFooter,
  SearchDialogHeader,
  SearchDialogIcon,
  SearchDialogInput,
  SearchDialogList,
  SearchDialogOverlay,
  TagsList,
  TagsListItem,
} from "fumadocs-ui/components/dialog/search";

let staticClientModule: Promise<typeof import("fumadocs-core/search/client/orama-static")>;

// The default dialog has no content slot for Radix's autofocus hooks. Keep its
// search options and composition; capture focus only when the dialog commits.
export function DocsSearchDialog({
  type,
  api,
  delayMs,
  defaultTag,
  tags = [],
  allowClear = false,
  links = [],
  footer,
  ...props
}: DefaultSearchDialogProps) {
  const { locale } = useI18n();
  const [tag, setTag] = useState(defaultTag);
  useOnChange(defaultTag, setTag);
  const client =
    type === "static"
      ? use(
          (staticClientModule ??= import("fumadocs-core/search/client/orama-static")),
        ).staticClient({ from: api, locale, tag })
      : fetchClient({ api, locale, tag });
  const search = useDocsSearch({ client, delayMs });
  const defaultItems = useMemo(
    () =>
      links.length
        ? links.map(([name, url]) => ({
            type: "page" as const,
            id: name,
            content: name,
            url,
          }))
        : null,
    [links],
  );
  const opener = useRef<HTMLElement | null>(null);
  const selected = useRef(false);

  return (
    <SearchDialog
      {...search}
      {...props}
      onSelect={() => {
        selected.current = true;
      }}
    >
      <SearchDialogOverlay />
      <SearchDialogContent
        onOpenAutoFocus={() => {
          opener.current =
            document.activeElement instanceof HTMLElement ? document.activeElement : null;
          selected.current = false;
        }}
        onCloseAutoFocus={(event) => {
          // Without a Radix trigger, its default close handler focuses body.
          // A selected result owns subsequent navigation focus instead.
          event.preventDefault();
          if (!selected.current && opener.current?.isConnected) opener.current.focus();
        }}
      >
        <SearchDialogHeader>
          <SearchDialogIcon />
          <SearchDialogInput />
          <SearchDialogClose />
        </SearchDialogHeader>
        <SearchDialogList defaultItems={defaultItems} />
      </SearchDialogContent>
      <SearchDialogFooter>
        {tags.length > 0 && (
          <TagsList tag={tag} onTagChange={setTag} allowClear={allowClear}>
            {tags.map((item) => (
              <TagsListItem key={item.value} value={item.value}>
                {item.name}
              </TagsListItem>
            ))}
          </TagsList>
        )}
        {footer}
      </SearchDialogFooter>
    </SearchDialog>
  );
}
