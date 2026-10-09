import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [manifestPath, outputDirectory, viteCliEntry, ...passthroughArgs] = process.argv.slice(2);

if (!manifestPath || !outputDirectory || !viteCliEntry) {
    console.error("vite_driver: expected <manifest> <output_directory> <vite_entry> [vite args...]");
    process.exit(2);
}

const outputDirectoryAbsolute = path.resolve(outputDirectory);
const viteEntryAbsolute = path.resolve(viteCliEntry);

if (!fs.existsSync(viteEntryAbsolute)) {
    console.error(
        "vite_driver: vite entry not found at " + viteEntryAbsolute +
        " - the expected node_modules link convention is " +
        "npm_link_all_packages(name = \"node_modules\") in the consuming package."
    );
    process.exit(2);
}

const manifest = JSON.parse(fs.readFileSync(path.resolve(manifestPath), "utf8"));

const stageDirectory = fs.mkdtempSync(path.join(process.env.TEST_TMPDIR || os.tmpdir(), "rules_vite_"));

if (manifest.package_links) {
    fs.mkdirSync(path.join(stageDirectory, "node_modules"), { recursive: true });
    for (const packageLink of manifest.package_links) {
        const packageLinkPath = path.join(stageDirectory, "node_modules", packageLink.package_name);
        fs.mkdirSync(path.dirname(packageLinkPath), { recursive: true });
        fs.symlinkSync(path.resolve(packageLink.execroot_source), packageLinkPath, "dir");
    }
} else if (manifest.node_modules_root) {
    fs.symlinkSync(
        path.resolve(manifest.node_modules_root),
        path.join(stageDirectory, "node_modules"),
        "dir",
    );
} else {
    console.error("vite_driver: manifest carries neither package_links nor node_modules_root");
    process.exit(2);
}

for (const stagedFile of manifest.files) {
    const stagedPath = path.join(stageDirectory, stagedFile.destination);
    fs.mkdirSync(path.dirname(stagedPath), { recursive: true });
    fs.writeFileSync(
            stagedPath,
            fs.readFileSync(path.resolve(stagedFile.source)),
        );
}

const stagedPackageDirectory = manifest.package ? path.join(stageDirectory, manifest.package) : stageDirectory;

let configArguments = [];
if (manifest.config) {
    const configInStage = path.join(stageDirectory, manifest.config);
    const configRelativeToPackage = path.relative(stagedPackageDirectory, configInStage);
    if (configRelativeToPackage.startsWith("..")) {
        console.error(
            `vite_driver: config ${manifest.config} lands outside the staged package ${manifest.package}`,
        );
        process.exit(2);
    }
    configArguments = ["--config", configRelativeToPackage];
}

const stageDirectoryAliases = [stageDirectory, fs.realpathSync(stageDirectory)];
const bazelOutBinSegment = /\/bazel-out\/[^/]+\/bin\//;

function canonicalSourcemapSource(mapDirectory, sourceRoot, source) {
    const absoluteSource = path.resolve(mapDirectory, sourceRoot, source);
    for (const stageAlias of stageDirectoryAliases) {
        if (absoluteSource.startsWith(stageAlias + path.sep)) {
            return path.relative(stageAlias, absoluteSource).split(path.sep).join("/");
        }
    }
    const binMatch = bazelOutBinSegment.exec(absoluteSource);
    return binMatch ? absoluteSource.slice(binMatch.index + binMatch[0].length) : source;
}

function normalizeSourcemaps() {
    const mapFiles = fs.readdirSync(outputDirectoryAbsolute, { recursive: true })
        .filter((relativePath) => relativePath.endsWith(".map"));
    for (const relativePath of mapFiles) {
        const mapPath = path.join(outputDirectoryAbsolute, relativePath);
        const sourcemap = JSON.parse(fs.readFileSync(mapPath, "utf8"));
        if (!Array.isArray(sourcemap.sources)) {
            continue;
        }
        const mapDirectory = path.dirname(mapPath);
        sourcemap.sources = sourcemap.sources.map(
            (source) => canonicalSourcemapSource(mapDirectory, sourcemap.sourceRoot || "", source),
        );
        delete sourcemap.sourceRoot;
        fs.writeFileSync(mapPath, JSON.stringify(sourcemap));
    }
}

const removeStageDirectory = () => {
    try { fs.rmSync(stageDirectory, { recursive: true, force: true }); } catch {}
};
process.on("exit", (exitCode) => {
    if (exitCode !== 0) {
        return;
    }
    try {
        normalizeSourcemaps();
    } catch (error) {
        console.error("vite_driver: sourcemap normalization failed: " + error.stack);
        process.exitCode = 1;
    }
});
process.on("exit", removeStageDirectory);
for (const [signalName, exitCode] of [["SIGINT", 130], ["SIGTERM", 143], ["SIGHUP", 129]]) {
    process.on(signalName, () => {
        removeStageDirectory();
        process.exit(exitCode);
    });
}

process.chdir(stagedPackageDirectory);
process.argv = [
    process.argv[0],
    "vite",
    "build",
    ".",
    "--outDir",
    outputDirectoryAbsolute,
    ...configArguments,
    ...passthroughArgs,
];

await import(pathToFileURL(viteEntryAbsolute).href);
