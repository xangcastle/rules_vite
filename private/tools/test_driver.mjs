import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
//
// Stages sources, config, and node_modules into an ephemeral directory
// under TEST_TMPDIR, then runs `vitest run` with the project root
// pinned to the staged package. Receives a JSON manifest.
//

const [manifest, nmRootArg, vitestEntry, ...rest] = process.argv.slice(2);

if (!manifest || !vitestEntry) {
    console.error("test_driver: expected <manifest> <nm_root> <vitest_entry> [args...]");
    process.exit(2);
}

const manifestAbsolute = path.resolve(manifest);
const entryAbsolute = path.resolve(vitestEntry);

const spec = JSON.parse(fs.readFileSync(manifestAbsolute, "utf8"));

const stageRoot = process.env.TEST_TMPDIR || os.tmpdir();
const stage = fs.mkdtempSync(path.join(stageRoot, "rules_vite_test_"));

for (const file of spec.files) {
    const dst = path.join(stage, file.dst);
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(path.resolve(file.src), dst);
}

if (spec.links) {
    fs.mkdirSync(path.join(stage, "node_modules"), { recursive: true });
    for (const link of spec.links) {
        const dst = path.join(stage, "node_modules", link.rel);
        fs.mkdirSync(path.dirname(dst), { recursive: true });
        fs.symlinkSync(path.resolve(link.src), dst, "dir");
    }
} else if (spec.nm_root) {
    fs.symlinkSync(path.resolve(spec.nm_root), path.join(stage, "node_modules"), "dir");
} else if (nmRootArg && nmRootArg !== "-") {
    fs.symlinkSync(path.resolve(nmRootArg), path.join(stage, "node_modules"), "dir");
} else {
    console.error("test_driver: no node_modules source (links, nm_root, or argv)");
    process.exit(2);
}

const stagePackage = spec.package ? path.join(stage, spec.package) : stage;

process.chdir(stagePackage);
process.argv = [process.argv[0], "vitest", "run", ...(spec.extra_args || []), ...rest];

await import(pathToFileURL(entryAbsolute).href);
