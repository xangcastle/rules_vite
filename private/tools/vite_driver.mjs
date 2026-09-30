import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";
//
// Stages the application tree into an ephemeral directory, links
// node_modules, and runs `vite build` with the project root pinned to
// the staged package. Receives a JSON manifest describing sources,
// config, and node_modules layout. Cleans up the stage on exit.
//

const [manifest, outDir, viteEntry, ...rest] = process.argv.slice(2);

if (!manifest || !outDir || !viteEntry) {
    console.error("vite_driver: expected <manifest> <out_dir> <vite_entry> [vite args...]");
    process.exit(2);
}

const outAbsolute = path.resolve(outDir);
const entryAbsolute = path.resolve(viteEntry);

if (!fs.existsSync(entryAbsolute)) {
    console.error(
        "vite_driver: vite entry not found at " + entryAbsolute +
        " - the expected node_modules link convention is " +
        "npm_link_all_packages(name = \"node_modules\") in the consuming package."
    );
    process.exit(2);
}

const spec = JSON.parse(fs.readFileSync(path.resolve(manifest), "utf8"));

const stage = fs.mkdtempSync(path.join(os.tmpdir(), "rules_vite_"));

if (spec.links) {
    fs.mkdirSync(path.join(stage, "node_modules"), { recursive: true });
    for (const link of spec.links) {
        const dst = path.join(stage, "node_modules", link.rel);
        fs.mkdirSync(path.dirname(dst), { recursive: true });
        fs.symlinkSync(path.resolve(link.src), dst, "dir");
    }
} else if (spec.nm_root) {
    fs.symlinkSync(path.resolve(spec.nm_root), path.join(stage, "node_modules"), "dir");
} else {
    console.error("vite_driver: manifest carries neither links nor nm_root");
    process.exit(2);
}

for (const file of spec.files) {
    const dst = path.join(stage, file.dst);
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(path.resolve(file.src), dst);
}

const stagePackage = spec.package ? path.join(stage, spec.package) : stage;

let configArg = [];
if (spec.config) {
    const configInStage = path.join(stage, spec.config);
    const configRelToPkg = path.relative(stagePackage, configInStage);
    if (configRelToPkg.startsWith("..")) {
        console.error(
            `vite_driver: config ${spec.config} lands outside the staged package ${spec.package}`,
        );
        process.exit(2);
    }
    configArg = ["--config", configRelToPkg];
}

process.chdir(stagePackage);
const _cleanup = () => {
    try { fs.rmSync(stage, { recursive: true, force: true }); } catch {}
};
process.on("exit", _cleanup);

process.argv = [process.argv[0], "vite", "build", ".", "--outDir", outAbsolute, ...configArg, ...rest];

await import(pathToFileURL(entryAbsolute).href);
