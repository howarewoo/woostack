/** Pure utility functions for the gencode script. Extracted for testability. */

/** Replace absolute pnpm store paths with package specifiers in type strings. */
export function replaceAbsolutePaths(typeStr: string): string {
  return typeStr.replace(/import\("([^"]+)"\)/g, (_match: string, importPath: string) => {
    const marker = "node_modules/";
    const lastIndex = importPath.lastIndexOf(marker);
    if (lastIndex === -1) return _match;

    const packagePath = importPath.substring(lastIndex + marker.length);

    // Extract package name (handle scoped @scope/name packages)
    let packageName: string;
    let subPath: string;

    if (packagePath.startsWith("@")) {
      const parts = packagePath.split("/");
      packageName = `${parts[0]}/${parts[1]}`;
      subPath = parts.slice(2).join("/");
    } else {
      const parts = packagePath.split("/");
      packageName = parts[0] as string;
      subPath = parts.slice(1).join("/");
    }

    // Validate package name — reject unexpected characters
    const validPkg = /^(@[a-z0-9._-]+\/)?[a-z0-9._-]+$/i;
    if (!validPkg.test(packageName)) {
      throw new Error(`Invalid package name encountered in type output: ${packageName}`);
    }
    if (subPath && /['"\\]/.test(subPath)) {
      throw new Error(`Invalid subpath encountered in type output: ${subPath}`);
    }

    // Strip common entry points — use bare package specifier
    if (
      !subPath ||
      subPath === "index" ||
      subPath === "dist/index" ||
      subPath === "src/index" ||
      subPath === "dist/types" ||
      subPath === "src/types"
    ) {
      return `import("${packageName}")`;
    }

    // Normalize internal file paths to their nearest registered export entry.
    // e.g. "v4/core/schemas" → "v4/core" (zod exports "./v4/core" but not "./v4/core/schemas")
    const normalizedSubPath = subPath.replace(/\/[^/]+$/, "");
    if (
      normalizedSubPath &&
      normalizedSubPath !== subPath &&
      (subPath.endsWith("/schemas") || subPath.endsWith("/index") || subPath.endsWith("/types"))
    ) {
      return `import("${packageName}/${normalizedSubPath}")`;
    }

    return `import("${packageName}/${subPath}")`;
  });
}

/**
 * Workspace type references that TypeScript serializes as bare names
 * (because workspace packages resolve via symlinks, not node_modules).
 * Maps type name → package specifier.
 */
const WORKSPACE_TYPE_MAP: Record<string, string> = {
  SupabaseUser: "@infrastructure/supabase",
  TypedSupabaseClient: "@infrastructure/supabase",
};

/** Qualify bare workspace type references with import() syntax. */
export function qualifyBareWorkspaceTypes(typeStr: string): string {
  let result = typeStr;
  for (const [typeName, pkg] of Object.entries(WORKSPACE_TYPE_MAP)) {
    // Match bare type name not already preceded by "." (import("pkg").Type)
    const regex = new RegExp(`(?<!\\.)\\b${typeName}\\b`, "g");
    result = result.replace(regex, `import("${pkg}").${typeName}`);
  }
  return result;
}

/** Format a type string with indentation, respecting string literals. */
export function formatTypeString(typeStr: string): string {
  const lines: string[] = [];
  let currentLine = "";
  let indent = 0;
  let inString = false;
  let stringChar = "";
  const INDENT = "  ";

  for (let i = 0; i < typeStr.length; i++) {
    const char = typeStr[i] as string;

    // Track whether we're inside a string literal (single, double, or backtick quoted)
    if (!inString && (char === '"' || char === "'" || char === "`")) {
      inString = true;
      stringChar = char;
      currentLine += char;
      continue;
    }
    if (inString) {
      currentLine += char;
      // Handle escaped characters
      if (char === "\\" && i + 1 < typeStr.length) {
        i++;
        currentLine += typeStr[i] as string;
        continue;
      }
      if (char === stringChar) {
        inString = false;
      }
      continue;
    }

    if (char === "{") {
      indent++;
      currentLine += "{";
      lines.push(currentLine.trimEnd());
      currentLine = INDENT.repeat(indent);
    } else if (char === "}") {
      if (indent <= 0) {
        throw new Error(`Unbalanced braces in type string near: ${currentLine.trim()}`);
      }
      indent--;
      if (currentLine.trim()) {
        lines.push(currentLine.trimEnd());
      }
      currentLine = `${INDENT.repeat(indent)}}`;
    } else if (char === ";") {
      if (indent > 0) {
        currentLine += ";";
        lines.push(currentLine.trimEnd());
        currentLine = INDENT.repeat(indent);
      } else {
        currentLine += ";";
      }
    } else if (char === " " && currentLine === INDENT.repeat(indent)) {
    } else {
      currentLine += char;
    }
  }
  if (currentLine.trim()) {
    lines.push(currentLine.trimEnd());
  }
  return lines.join("\n");
}
