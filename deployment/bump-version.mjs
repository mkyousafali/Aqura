import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const deploymentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(deploymentDir, "..");
const versionFile = path.join(
  repoRoot,
  "frontend",
  "src",
  "lib",
  "appVersion.ts",
);
const packageFile = path.join(repoRoot, "frontend", "package.json");
const source = fs.readFileSync(versionFile, "utf8");
const versionPattern = /\bexport const versionNumber\s*=\s*(\d+)\s*;/;
const match = source.match(versionPattern);
if (!match) throw new Error(`Cannot find shared versionNumber in ${versionFile}`);
const current = Number(match[1]);
const next = current + 1;
if (!Number.isSafeInteger(current) || !Number.isSafeInteger(next)) {
  throw new Error("Shared version number must be a safe integer");
}
const currentFull = `V-AQ${current}`;
const nextFull = `V-AQ${next}`;

const packageJson = JSON.parse(fs.readFileSync(packageFile, "utf8"));
if (packageJson.version !== currentFull) {
  throw new Error(
    `frontend/package.json is ${packageJson.version}; expected ${currentFull}`,
  );
}

if (process.argv.includes("--check")) {
  console.log(`CURRENT_VERSION=${currentFull}`);
  console.log(`NEXT_VERSION=${nextFull}`);
  process.exit(0);
}

const updatedSource = source.replace(versionPattern, `export const versionNumber = ${next};`);
packageJson.version = nextFull;

fs.writeFileSync(versionFile, updatedSource);
fs.writeFileSync(packageFile, `${JSON.stringify(packageJson, null, 2)}\n`);
console.log(`DEPLOY_VERSION=${nextFull}`);
