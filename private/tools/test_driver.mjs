import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [manifestPath, nodeModulesSpec, vitestEntryScript, ...passthroughArgs] = process.argv.slice(2);

if (!manifestPath || !nodeModulesSpec || !nodeModulesSpec.includes(":") || !vitestEntryScript) {
    console.error("test_driver: expected <manifest> <node_modules_spec> <vitest_entry> [args...]");
    process.exit(2);
}

let runfilesRoot = process.env.RUNFILES_DIR;
if (!runfilesRoot) {
    runfilesRoot = path.dirname(new URL(import.meta.url).pathname);
    while (runfilesRoot !== path.dirname(runfilesRoot) && !path.basename(runfilesRoot).endsWith(".runfiles")) {
        runfilesRoot = path.dirname(runfilesRoot);
    }
    if (!path.basename(runfilesRoot).endsWith(".runfiles")) {
        console.error("test_driver: could not locate the .runfiles root from " + runfilesRoot);
        process.exit(2);
    }
}

const runfilesWorkspace = process.env.TEST_WORKSPACE || "_main";

function resolveWorkspaceRunfilesPath(workspaceRelativePath) {
    const absolutePath = path.join(runfilesRoot, runfilesWorkspace, workspaceRelativePath);
    if (!fs.existsSync(absolutePath)) {
        console.error("test_driver: not found in runfiles at " + absolutePath);
        process.exit(2);
    }
    return absolutePath;
}

function resolveRunfilesPath(runfilesRelativePath) {
    const absolutePath = path.join(runfilesRoot, runfilesRelativePath);
    if (!fs.existsSync(absolutePath)) {
        console.error("test_driver: not found in runfiles at " + absolutePath);
        process.exit(2);
    }
    return absolutePath;
}

const manifest = JSON.parse(fs.readFileSync(path.resolve(manifestPath), "utf8"));

const stageDirectory = fs.mkdtempSync(
    path.join(process.env.TEST_TMPDIR || os.tmpdir(), "rules_vite_test_"),
);
for (const stagedFile of manifest.files) {
    const stagedPath = path.join(stageDirectory, stagedFile.destination);
    fs.mkdirSync(path.dirname(stagedPath), { recursive: true });
    fs.writeFileSync(stagedPath, fs.readFileSync(resolveRunfilesPath(stagedFile.runfiles_path)));
}

const removeStageDirectory = () => {
    try { fs.rmSync(stageDirectory, { recursive: true, force: true }); } catch {}
};
process.on("exit", removeStageDirectory);
for (const [signalName, exitCode] of [["SIGINT", 130], ["SIGTERM", 143], ["SIGHUP", 129]]) {
    process.on(signalName, () => {
        removeStageDirectory();
        process.exit(exitCode);
    });
}

if (nodeModulesSpec.startsWith("node_modules:")) {
    const nodeModulesRelativePath = nodeModulesSpec.slice("node_modules:".length);
    fs.symlinkSync(
        resolveWorkspaceRunfilesPath(nodeModulesRelativePath),
        path.join(stageDirectory, "node_modules"),
        "dir",
    );
} else if (nodeModulesSpec.startsWith("links:")) {
    fs.mkdirSync(path.join(stageDirectory, "node_modules"), { recursive: true });
    for (const linkRelativePath of nodeModulesSpec.slice("links:".length).split(",")) {
        const marker = "node_modules/";
        const packageName = linkRelativePath.slice(linkRelativePath.lastIndexOf(marker) + marker.length);
        const packageLinkPath = path.join(stageDirectory, "node_modules", packageName);
        fs.mkdirSync(path.dirname(packageLinkPath), { recursive: true });
        fs.symlinkSync(resolveWorkspaceRunfilesPath(linkRelativePath), packageLinkPath, "dir");
    }
} else {
    console.error("test_driver: unsupported node_modules spec " + nodeModulesSpec);
    process.exit(2);
}

const stagedPackageDirectory = manifest.package ? path.join(stageDirectory, manifest.package) : stageDirectory;
process.chdir(stagedPackageDirectory);

process.env.CI ??= "true";

const callerPassedConfig = passthroughArgs.some(
    (arg) => arg === "-c" || arg === "--config" || arg.startsWith("--config="),
);
const configArgs = callerPassedConfig ? [] : ["--config", path.join(stageDirectory, manifest.config)];
process.argv = [process.argv[0], "vitest", "run", ...configArgs, ...passthroughArgs];

await import(pathToFileURL(resolveWorkspaceRunfilesPath(vitestEntryScript)).href);
