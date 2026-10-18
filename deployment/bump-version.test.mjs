import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const deploymentDir = path.dirname(fileURLToPath(import.meta.url));
const tempRoot = path.resolve(deploymentDir, "../.tmp");

function fixture(t, version = "V-AQ86", source = "export const versionNumber = 86;\n") {
  fs.mkdirSync(tempRoot, { recursive: true });
  const root = fs.mkdtempSync(path.join(tempRoot, "version-bump-test-"));
  t.after(() => {
    assert.equal(path.dirname(root), tempRoot);
    assert.ok(path.basename(root).startsWith("version-bump-test-"));
    fs.rmSync(root, { recursive: true, force: true });
  });
  const script = path.join(root, "deployment/bump-version.mjs");
  const versionFile = path.join(root, "frontend/src/lib/appVersion.ts");
  const packageFile = path.join(root, "frontend/package.json");
  fs.mkdirSync(path.dirname(script), { recursive: true });
  fs.mkdirSync(path.dirname(versionFile), { recursive: true });
  fs.copyFileSync(path.join(deploymentDir, "bump-version.mjs"), script);
  fs.writeFileSync(versionFile, source);
  fs.writeFileSync(packageFile, JSON.stringify({ name: "test-app", version }));
  return {
    run: (...args) => spawnSync(process.execPath, [script, ...args], { encoding: "utf8" }),
    contents: () => [versionFile, packageFile].map(file => fs.readFileSync(file, "utf8")),
  };
}

test("check reports the shared current/next version without changing files", t => {
  const data = fixture(t);
  const before = data.contents();
  const result = data.run("--check");
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /CURRENT_VERSION=V-AQ86/);
  assert.match(result.stdout, /NEXT_VERSION=V-AQ87/);
  assert.deepEqual(data.contents(), before);
});

test("successive bumps increment only one shared release number", t => {
  const data = fixture(t);
  for (const expected of [87, 88]) {
    const result = data.run();
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, new RegExp(`DEPLOY_VERSION=V-AQ${expected}`));
    const [source, packageSource] = data.contents();
    assert.equal(source, `export const versionNumber = ${expected};\n`);
    assert.equal(JSON.parse(packageSource).version, `V-AQ${expected}`);
  }
});

test("mismatched package version fails before writing, including check mode", t => {
  const data = fixture(t, "V-AQ85");
  const before = data.contents();
  for (const args of [[], ["--check"]]) {
    const result = data.run(...args);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /expected V-AQ86/);
    assert.deepEqual(data.contents(), before);
  }
});

test("malformed version source fails without changing files", t => {
  const data = fixture(t, "V-AQ86", "export const versionNumber = 86.5;\n");
  const before = data.contents();
  const result = data.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Cannot find shared versionNumber/);
  assert.deepEqual(data.contents(), before);
});
