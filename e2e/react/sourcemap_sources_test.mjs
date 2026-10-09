import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const [distDirectory] = process.argv.slice(2);

const mapFiles = fs.readdirSync(distDirectory, { recursive: true })
    .filter((relativePath) => relativePath.endsWith(".map"));
assert.ok(mapFiles.length > 0, `no .map files under ${distDirectory}`);

const sources = mapFiles.flatMap(
    (relativePath) => JSON.parse(fs.readFileSync(path.join(distDirectory, relativePath), "utf8")).sources,
);

for (const source of sources) {
    assert.ok(!path.isAbsolute(source), `absolute source: ${source}`);
    assert.ok(!source.split("/").includes(".."), `source escapes the map directory: ${source}`);
    assert.doesNotMatch(source, /rules_vite_|bazel-out|execroot/, `host-dependent source: ${source}`);
}

assert.ok(sources.includes("src/App.jsx"), `workspace source missing from ${JSON.stringify(sources)}`);
assert.ok(
    sources.some((source) => /^node_modules\/\.aspect_rules_js\/react@[^/]+\/node_modules\/react\/index\.js$/.test(source)),
    `node_modules source missing from ${JSON.stringify(sources)}`,
);
