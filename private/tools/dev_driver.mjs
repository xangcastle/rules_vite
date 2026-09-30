import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
//
// Serves the real workspace tree via vite's dev server with native HMR.
// Symlinks the linked node_modules tree into the workspace for the
// server's lifetime. Optionally links a shared component directory at
// a package-relative path via the overlay argument. Exits with the
// appropriate signal code on SIGINT/SIGTERM/SIGHUP.
//

const [nmRel, viteEntry, pkg, overlay, ...rest] = process.argv.slice(2);

if (!nmRel || !viteEntry || !pkg) {
    console.error("dev_driver: expected <nm_rel> <vite_entry> <package> [overlay] [args...]");
    process.exit(2);
}

const workspace = process.env.BUILD_WORKSPACE_DIRECTORY;
if (!workspace) {
    console.error("dev_driver: BUILD_WORKSPACE_DIRECTORY is not set; run via bazel run.");
    process.exit(2);
}

let runfiles = process.env.RUNFILES_DIR;
if (!runfiles) {
    runfiles = path.dirname(new URL(import.meta.url).pathname);
    while (runfiles !== path.dirname(runfiles) && !path.basename(runfiles).endsWith(".runfiles")) {
        runfiles = path.dirname(runfiles);
    }
    if (!path.basename(runfiles).endsWith(".runfiles")) {
        console.error("dev_driver: could not locate the .runfiles root from " + runfiles);
        process.exit(2);
    }
}

const ws = process.env.TEST_WORKSPACE || "_main";
const nmAbsolute = path.join(runfiles, ws, nmRel);
const entryAbsolute = path.join(runfiles, ws, viteEntry);

if (!fs.existsSync(nmAbsolute)) {
    console.error("dev_driver: linked node_modules not found in runfiles at " + nmAbsolute);
    process.exit(2);
}

const linkPath = path.join(workspace, nmRel);
fs.mkdirSync(path.dirname(linkPath), { recursive: true });

let managesLink = false;
const existing = fs.lstatSync(linkPath, { throwIfNoEntry: false });
if (!existing) {
    fs.symlinkSync(nmAbsolute, linkPath, "dir");
    managesLink = true;
} else if (existing.isSymbolicLink()) {
    const currentTarget = fs.readlinkSync(linkPath);
    if (currentTarget === nmAbsolute) {
        managesLink = true;
    } else if (currentTarget.includes("bazel-out") || currentTarget.includes(".runfiles")) {
        managesLink = true;
    } else {
        console.error(
            "dev_driver: " + linkPath + " is a symlink to " + currentTarget +
            " (not ours). Remove it manually if you want the dev server to manage it.",
        );
        process.exit(2);
    }
} else if (existing.isDirectory()) {
    console.error(
        "dev_driver: " + linkPath + " is a real directory (your node_modules)." +
        " The dev server will not touch it. Remove it to let bazel manage node_modules.",
    );
    process.exit(2);
}

const cleanup = () => {
    if (managesLink) {
        try {
            fs.rmSync(linkPath, { force: true });
        } catch {}
    }
};

process.on("exit", cleanup);
for (const [signal, code] of [["SIGINT", 130], ["SIGTERM", 143], ["SIGHUP", 129]]) {
    process.on(signal, () => {
        cleanup();
        process.exit(code);
    });
}

const overlaySep = overlay ? overlay.indexOf("=") : -1;
if (overlaySep > 0) {
    const injectDir = overlay.slice(0, overlaySep);
    const sharedDir = overlay.slice(overlaySep + 1);
    const target = path.join(workspace, pkg === "." ? "" : pkg, injectDir);
    const source = path.join(workspace, sharedDir);
    if (!fs.existsSync(source)) {
        console.error("dev_driver: shared_dir not found at " + source);
        process.exit(2);
    }
    fs.mkdirSync(path.dirname(target), { recursive: true });
    if (!fs.existsSync(target)) {
        fs.symlinkSync(source, target, "dir");
        process.on("exit", () => fs.rmSync(target, { force: true }));
    }
}

process.chdir(pkg ? path.join(workspace, pkg) : workspace);
process.argv = [process.argv[0], "vite", ...rest];

await import(pathToFileURL(entryAbsolute).href);
