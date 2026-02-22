import { describe, expect, it } from "vitest";
import { formatTypeString, replaceAbsolutePaths } from "../gencode-utils";

describe("replaceAbsolutePaths", () => {
  it("replaces absolute pnpm store path with bare package specifier", () => {
    const input = 'import("/path/to/node_modules/zod/dist/index")';
    expect(replaceAbsolutePaths(input)).toBe('import("zod")');
  });

  it("handles scoped packages", () => {
    const input = 'import("/path/to/node_modules/@orpc/server/dist/index")';
    expect(replaceAbsolutePaths(input)).toBe('import("@orpc/server")');
  });

  it("preserves subpaths that are not common entry points", () => {
    const input = 'import("/path/to/node_modules/@orpc/client/fetch")';
    expect(replaceAbsolutePaths(input)).toBe('import("@orpc/client/fetch")');
  });

  it("leaves non-node_modules paths unchanged", () => {
    const input = 'import("/path/to/src/router")';
    expect(replaceAbsolutePaths(input)).toBe('import("/path/to/src/router")');
  });

  it("strips src/index entry point", () => {
    const input = 'import("/path/to/node_modules/zod/src/index")';
    expect(replaceAbsolutePaths(input)).toBe('import("zod")');
  });

  it("strips index-only entry point", () => {
    const input = 'import("/path/to/node_modules/zod/index")';
    expect(replaceAbsolutePaths(input)).toBe('import("zod")');
  });

  it("normalizes /schemas subpath to parent directory", () => {
    const input = 'import("/path/to/node_modules/zod/v4/core/schemas")';
    expect(replaceAbsolutePaths(input)).toBe('import("zod/v4/core")');
  });

  it("normalizes /types subpath to parent directory", () => {
    const input = 'import("/path/to/node_modules/zod/v4/core/types")';
    expect(replaceAbsolutePaths(input)).toBe('import("zod/v4/core")');
  });

  it("throws on invalid package name", () => {
    const input = 'import("/path/to/node_modules/bad!pkg/index")';
    expect(() => replaceAbsolutePaths(input)).toThrow("Invalid package name");
  });

  it("throws on subpath with quotes", () => {
    const input = 'import("/path/to/node_modules/pkg/sub\'path")';
    expect(() => replaceAbsolutePaths(input)).toThrow("Invalid subpath");
  });

  it("strips dist/types entry point", () => {
    const input = 'import("/path/to/node_modules/pkg/dist/types")';
    expect(replaceAbsolutePaths(input)).toBe('import("pkg")');
  });

  it("strips src/types entry point", () => {
    const input = 'import("/path/to/node_modules/pkg/src/types")';
    expect(replaceAbsolutePaths(input)).toBe('import("pkg")');
  });

  it("handles multiple imports in one string", () => {
    const input =
      'import("/a/node_modules/zod/dist/index").ZodString, import("/b/node_modules/@orpc/server/dist/index").Procedure';
    expect(replaceAbsolutePaths(input)).toBe(
      'import("zod").ZodString, import("@orpc/server").Procedure'
    );
  });
});

describe("formatTypeString", () => {
  it("formats a simple object type with indentation", () => {
    const input = "{ foo: string; bar: number; }";
    const expected = ["{", "  foo: string;", "  bar: number;", "}"].join("\n");
    expect(formatTypeString(input)).toBe(expected);
  });

  it("formats nested objects", () => {
    const input = "{ a: { b: string; }; }";
    const expected = ["{", "  a: {", "    b: string;", "  };", "}"].join("\n");
    expect(formatTypeString(input)).toBe(expected);
  });

  it("preserves braces inside double-quoted strings", () => {
    const input = '{ foo: "{bar}"; }';
    const expected = ["{", '  foo: "{bar}";', "}"].join("\n");
    expect(formatTypeString(input)).toBe(expected);
  });

  it("preserves braces inside single-quoted strings", () => {
    const input = "{ foo: '{bar}'; }";
    const expected = ["{", "  foo: '{bar}';", "}"].join("\n");
    expect(formatTypeString(input)).toBe(expected);
  });

  it("preserves braces inside backtick strings", () => {
    const input = "{ foo: `{bar}`; }";
    const expected = ["{", "  foo: `{bar}`;", "}"].join("\n");
    expect(formatTypeString(input)).toBe(expected);
  });

  it("handles escaped quotes inside strings", () => {
    const input = '{ foo: "say \\"hi\\""; }';
    const expected = ["{", '  foo: "say \\"hi\\"";', "}"].join("\n");
    expect(formatTypeString(input)).toBe(expected);
  });

  it("returns simple non-object types as-is", () => {
    expect(formatTypeString("string")).toBe("string");
  });

  it("throws on unbalanced closing braces", () => {
    expect(() => formatTypeString("foo }")).toThrow("Unbalanced braces");
  });
});
