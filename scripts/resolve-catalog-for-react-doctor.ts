/**
 * Resolves catalog: references in package.json files for react-doctor compatibility.
 * react-doctor cannot parse pnpm catalog: protocol, so this script temporarily
 * replaces catalog: with actual versions before running react-doctor.
 *
 * Usage: pnpx tsx scripts/resolve-catalog-for-react-doctor.ts
 */
import fs from "node:fs";

const lines = fs.readFileSync("pnpm-workspace.yaml", "utf8").split("\n");
const catalog: Record<string, string> = {};
let inCatalog = false;
for (const line of lines) {
	if (/^catalog:/.test(line)) {
		inCatalog = true;
		continue;
	}
	if (inCatalog && /^\S/.test(line)) {
		inCatalog = false;
	}
	if (inCatalog) {
		const m = line.match(/^\s+(.+?):\s*['"](.+?)['"]/);
		if (m) catalog[m[1]] = m[2];
	}
}

for (const app of ["apps/web", "apps/landing"]) {
	const pkgPath = `${app}/package.json`;
	const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));
	for (const depType of ["dependencies", "devDependencies"]) {
		if (!pkg[depType]) continue;
		for (const [name, ver] of Object.entries(pkg[depType])) {
			if (ver === "catalog:" && catalog[name]) {
				pkg[depType][name] = catalog[name];
			}
		}
	}
	fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`);
}
