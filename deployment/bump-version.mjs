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
const fields = ["desktop", "mobile", "cashier", "customer"];
const current = Object.fromEntries(
  fields.map((field) => {
    const match = source.match(new RegExp(`\\b${field}:\\s*(\\d+)`));
    if (!match)
      throw new Error(`Cannot find ${field} version in ${versionFile}`);
    return [field, Number(match[1])];
  }),
);
const next = Object.fromEntries(
  fields.map((field) => [field, current[field] + 1]),
);
const currentFull = `AQ${fields.map((field) => current[field]).join(".")}`;
const nextFull = `AQ${fields.map((field) => next[field]).join(".")}`;

if (process.argv.includes("--check")) {
  console.log(`CURRENT_VERSION=${currentFull}`);
  console.log(`NEXT_VERSION=${nextFull}`);
  process.exit(0);
}

let updatedSource = source;
for (const field of fields) {
  updatedSource = updatedSource.replace(
    new RegExp(`(\\b${field}:\\s*)${current[field]}\\b`),
    `$1${next[field]}`,
  );
}

const packageJson = JSON.parse(fs.readFileSync(packageFile, "utf8"));
if (packageJson.version !== currentFull) {
  throw new Error(
    `frontend/package.json is ${packageJson.version}; expected ${currentFull}`,
  );
}
packageJson.version = nextFull;

fs.writeFileSync(versionFile, updatedSource);
fs.writeFileSync(packageFile, `${JSON.stringify(packageJson, null, 2)}\n`);
console.log(`DEPLOY_VERSION=${nextFull}`);
