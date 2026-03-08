/**
 * Import boundary enforcement script.
 * Validates that monorepo packages respect architectural import rules.
 */
import { execFileSync } from "node:child_process";

interface Violation {
  file: string;
  line: number;
  rule: string;
  detail: string;
}

const violations: Violation[] = [];

function grep(pattern: string, paths: string[]): string[] {
  try {
    const args = ["-rn", "--include=*.ts", "--include=*.tsx", pattern, ...paths];
    const result = execFileSync("grep", args, { encoding: "utf-8" });
    return result
      .trim()
      .split("\n")
      .filter(
        (line) =>
          line &&
          !line.includes("node_modules") &&
          !line.includes("__tests__") &&
          !line.includes(".test.") &&
          !line.includes(".spec.")
      );
  } catch (error: unknown) {
    // grep exits with code 1 for "no matches" — that's expected
    if (error instanceof Error && "status" in error && (error as { status: number }).status === 1) {
      return [];
    }
    throw error;
  }
}

// Use . to match the quote character (single or double) after "from" — specific
// enough in import statements to avoid false positives.

// Rule 1: Features cannot import from apps or other feature packages
const featureImportsFromApps = grep("from .\\(apps/\\|web\\|api\\|landing\\|mobile\\)", [
  "packages/features/",
]);
for (const line of featureImportsFromApps) {
  const [file, lineNum] = line.split(":");
  violations.push({
    file,
    line: Number(lineNum),
    rule: "feature-no-app-import",
    detail: "Feature packages cannot import from apps",
  });
}

// Rule 2: Features cannot import from other features
const featureImportsFromFeatures = grep("from .@features/", ["packages/features/"]);
for (const match of featureImportsFromFeatures) {
  const [filePath, lineNum, ...rest] = match.split(":");
  const content = rest.join(":");
  // Allow self-imports (within the same feature package)
  const featureName = filePath.split("packages/features/")[1]?.split("/")[0];
  if (featureName && !content.includes(`@features/${featureName}`)) {
    violations.push({
      file: filePath,
      line: Number(lineNum),
      rule: "feature-no-cross-feature-import",
      detail: "Feature packages cannot import from other feature packages",
    });
  }
}

// Rule 3: No direct @supabase/supabase-js imports outside @infrastructure/supabase
const directSupabaseImports = grep("from .@supabase/supabase-js", ["packages/", "apps/"]);
for (const match of directSupabaseImports) {
  const [filePath, lineNum] = match.split(":");
  if (!filePath.includes("packages/infrastructure/supabase/")) {
    violations.push({
      file: filePath,
      line: Number(lineNum),
      rule: "no-direct-supabase-import",
      detail: "Use @infrastructure/supabase instead of importing @supabase/supabase-js directly",
    });
  }
}

// Rule 4: No direct next/navigation imports in feature packages
const nextNavInFeatures = grep("from .next/navigation", ["packages/features/"]);
for (const match of nextNavInFeatures) {
  const [filePath, lineNum] = match.split(":");
  violations.push({
    file: filePath,
    line: Number(lineNum),
    rule: "no-direct-next-navigation",
    detail: "Use @infrastructure/navigation instead of next/navigation in feature packages",
  });
}

// Rule 5: No direct expo-router imports in feature packages
const expoRouterInFeatures = grep("from .expo-router", ["packages/features/"]);
for (const match of expoRouterInFeatures) {
  const [filePath, lineNum] = match.split(":");
  violations.push({
    file: filePath,
    line: Number(lineNum),
    rule: "no-direct-expo-router",
    detail: "Use @infrastructure/navigation instead of expo-router in feature packages",
  });
}

// Rule 6: Apps cannot import from other apps
for (const app of ["web", "landing", "api", "mobile"]) {
  const otherApps = ["web", "landing", "api", "mobile"]
    .filter((a) => a !== app)
    .map((a) => `from .${a}.\\|from .${a}/`)
    .join("\\|");
  const appImportsOtherApps = grep(otherApps, [`apps/${app}/`]);
  for (const match of appImportsOtherApps) {
    const [filePath, lineNum] = match.split(":");
    violations.push({
      file: filePath,
      line: Number(lineNum),
      rule: "app-no-cross-app-import",
      detail: "Apps cannot import from other apps",
    });
  }
}

if (violations.length > 0) {
  console.error(`\n Found ${violations.length} import boundary violation(s):\n`);
  for (const v of violations) {
    console.error(`  ${v.file}:${v.line}`);
    console.error(`    Rule: ${v.rule}`);
    console.error(`    ${v.detail}\n`);
  }
  process.exit(1);
} else {
  console.log("All import boundaries are valid.");
}
