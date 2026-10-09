import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [packagePath, entryArgument, ...passthroughArgs] = process.argv.slice(2);

if (!packagePath || !entryArgument) {
    console.error("cli_driver: expected <package_path> <entry> [args...]");
    process.exit(2);
}

let runfilesRoot = process.env.RUNFILES_DIR;
if (!runfilesRoot) {
    runfilesRoot = path.dirname(new URL(import.meta.url).pathname);
    while (runfilesRoot !== path.dirname(runfilesRoot) && !path.basename(runfilesRoot).endsWith(".runfiles")) {
        runfilesRoot = path.dirname(runfilesRoot);
    }
    if (!path.basename(runfilesRoot).endsWith(".runfiles")) {
        console.error("cli_driver: could not locate the .runfiles root from " + runfilesRoot);
        process.exit(2);
    }
}

const packageDirectory = path.join(runfilesRoot, packagePath);

let entryRelativePath = entryArgument;
if (entryRelativePath === "auto") {
    const packageJson = JSON.parse(fs.readFileSync(path.join(packageDirectory, "package.json"), "utf8"));
    const binField = packageJson.bin || {};
    entryRelativePath = typeof binField === "string" ? binField : binField[Object.keys(binField)[0]] || "index.js";
}

const entryAbsolutePath = path.join(packageDirectory, entryRelativePath);

if (!fs.existsSync(entryAbsolutePath)) {
    console.error(
        "cli_driver: CLI entry not found at " + entryAbsolutePath +
        " (package: " + packagePath + ", entry: " + entryRelativePath + ")",
    );
    process.exit(2);
}

const workspaceDirectory = process.env.BUILD_WORKING_DIRECTORY;
if (workspaceDirectory) {
    process.chdir(workspaceDirectory);
}

process.argv = [process.argv[0], "cli", ...passthroughArgs];

await import(pathToFileURL(entryAbsolutePath).href);
