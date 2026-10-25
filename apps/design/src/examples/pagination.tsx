/* MIT: Copyright (c) 2023 shadcn. See LICENSE. Browser-only catalog adaptation. */
"use client";

import * as React from "react";

import { Example, ExampleWrapper } from "@/components/example";
import { Field, FieldLabel } from "@/components/ui/field";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationLink,
  PaginationNext,
  PaginationPrevious,
} from "@/components/ui/pagination";
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export default function PaginationExample() {
  return (
    <ExampleWrapper>
      <PaginationBasic />
      <PaginationSimple />
      <PaginationIconsOnly />
    </ExampleWrapper>
  );
}

function PaginationBasic() {
  const [page, setPage] = React.useState(2);
  const selectPage = (next: number) => (event: React.MouseEvent<HTMLAnchorElement>) => {
    event.preventDefault();
    setPage(Math.max(1, Math.min(3, next)));
  };
  return (
    <Example title="Basic">
      <Pagination>
        <PaginationContent>
          <PaginationItem>
            <PaginationPrevious
              href="#"
              aria-disabled={page === 1}
              onClick={selectPage(page - 1)}
            />
          </PaginationItem>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 1} onClick={selectPage(1)}>
              1
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 2} onClick={selectPage(2)}>
              2
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 3} onClick={selectPage(3)}>
              3
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationNext href="#" aria-disabled={page === 3} onClick={selectPage(page + 1)} />
          </PaginationItem>
        </PaginationContent>
      </Pagination>
      <p role="status" className="text-sm text-muted-foreground">
        Page {page} of 3 · Showing items {(page - 1) * 10 + 1}–{page * 10}
      </p>
    </Example>
  );
}

function PaginationSimple() {
  const [page, setPage] = React.useState(2);
  const selectPage = (next: number) => (event: React.MouseEvent<HTMLAnchorElement>) => {
    event.preventDefault();
    setPage(next);
  };
  return (
    <Example title="Simple">
      <Pagination>
        <PaginationContent>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 1} onClick={selectPage(1)}>
              1
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 2} onClick={selectPage(2)}>
              2
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 3} onClick={selectPage(3)}>
              3
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 4} onClick={selectPage(4)}>
              4
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationLink href="#" isActive={page === 5} onClick={selectPage(5)}>
              5
            </PaginationLink>
          </PaginationItem>
        </PaginationContent>
      </Pagination>
      <p role="status" className="text-sm text-muted-foreground">
        Page {page} of 5 · Showing items {(page - 1) * 10 + 1}–{page * 10}
      </p>
    </Example>
  );
}

function PaginationIconsOnly() {
  const [page, setPage] = React.useState(1);
  const [rows, setRows] = React.useState("25");
  const pageCount = Math.ceil(100 / Number(rows));
  const selectPage = (next: number) => (event: React.MouseEvent<HTMLAnchorElement>) => {
    event.preventDefault();
    setPage(Math.max(1, Math.min(pageCount, next)));
  };
  return (
    <Example title="With Select">
      <div className="flex items-center justify-between gap-4">
        <Field orientation="horizontal" className="w-fit">
          <FieldLabel htmlFor="select-rows-per-page">Rows per page</FieldLabel>
          <Select
            value={rows}
            onValueChange={(value) => {
              if (value !== null) {
                setRows(value);
                setPage(1);
              }
            }}
          >
            <SelectTrigger className="w-20" id="select-rows-per-page">
              <SelectValue />
            </SelectTrigger>
            <SelectContent align="start">
              <SelectGroup>
                <SelectItem value="10">10</SelectItem>
                <SelectItem value="25">25</SelectItem>
                <SelectItem value="50">50</SelectItem>
                <SelectItem value="100">100</SelectItem>
              </SelectGroup>
            </SelectContent>
          </Select>
        </Field>
        <Pagination className="mx-0 w-auto">
          <PaginationContent>
            <PaginationItem>
              <PaginationPrevious
                href="#"
                aria-disabled={page === 1}
                onClick={selectPage(page - 1)}
              />
            </PaginationItem>
            <PaginationItem>
              <PaginationNext
                href="#"
                aria-disabled={page === pageCount}
                onClick={selectPage(page + 1)}
              />
            </PaginationItem>
          </PaginationContent>
        </Pagination>
      </div>
      <p role="status" className="text-sm text-muted-foreground">
        Showing {(page - 1) * Number(rows) + 1}–{Math.min(page * Number(rows), 100)} of 100 items ·
        Page {page} of {pageCount}
      </p>
    </Example>
  );
}
