import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
//
// Runs a node CLI package's entry script with the working directory
// set to BUILD_WORKING_DIRECTORY. The entry defaults to the `bin`
// field of the package's package.json.
//

const [packageRel, entryArg, ...rest] = process.argv.slice(2);

if (!packageRel || !entryArg) {
    console.error("cli_driver: expected <package_rel> <entry> [args...]");
    process.exit(2);
}

let runfiles = process.env.RUNFILES_DIR;
if (!runfiles) {
    runfiles = path.dirname(new URL(import.meta.url).pathname);
    while (runfiles !== path.dirname(runfiles) && !path.basename(runfiles).endsWith(".runfiles")) {
        runfiles = path.dirname(runfiles);
    }
    if (!path.basename(runfiles).endsWith(".runfiles")) {
        console.error("cli_driver: could not locate the .runfiles root from " + runfiles);
        process.exit(2);
    }
}

const ws = process.env.TEST_WORKSPACE || "_main";
const packageDir = path.join(runfiles, ws, packageRel);

let entry = entryArg;
if (entry === "auto") {
    const pkgJson = JSON.parse(fs.readFileSync(path.join(packageDir, "package.json"), "utf8"));
    const bin = pkgJson.bin || {};
    entry = typeof bin === "string" ? bin : bin[Object.keys(bin)[0]] || "index.js";
}

const entryAbsolute = path.join(packageDir, entry);

if (!fs.existsSync(entryAbsolute)) {
    console.error(
        "cli_driver: CLI entry not found at " + entryAbsolute +
        " (package: " + packageRel + ", entry: " + entry + ")",
    );
    process.exit(2);
}

const workspace = process.env.BUILD_WORKING_DIRECTORY;
if (workspace) {
    process.chdir(workspace);
}

process.argv = [process.argv[0], "cli", ...rest];

await import(pathToFileURL(entryAbsolute).href);
