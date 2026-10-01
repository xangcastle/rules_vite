import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [nodeModulesSpec, viteCliEntry, appPackage, overlaySpec, ...passthroughArgs] = process.argv.slice(2);

if (!nodeModulesSpec || nodeModulesSpec === "-" || !viteCliEntry || !appPackage) {
    console.error("dev_driver: expected <node_modules_spec> <vite_cli_entry> <app_package> [overlay_spec] [args...]");
    process.exit(2);
}

const workspaceDirectory = process.env.BUILD_WORKSPACE_DIRECTORY;
if (!workspaceDirectory) {
    console.error("dev_driver: BUILD_WORKSPACE_DIRECTORY is not set; run via bazel run.");
    process.exit(2);
}

let runfilesRoot = process.env.RUNFILES_DIR;
if (!runfilesRoot) {
    runfilesRoot = path.dirname(new URL(import.meta.url).pathname);
    while (runfilesRoot !== path.dirname(runfilesRoot) && !path.basename(runfilesRoot).endsWith(".runfiles")) {
        runfilesRoot = path.dirname(runfilesRoot);
    }
    if (!path.basename(runfilesRoot).endsWith(".runfiles")) {
        console.error("dev_driver: could not locate the .runfiles root from " + runfilesRoot);
        process.exit(2);
    }
}

const runfilesWorkspace = process.env.TEST_WORKSPACE || "_main";

function resolveRunfilesPath(runfilesRelativePath) {
    const absolutePath = path.join(runfilesRoot, runfilesWorkspace, runfilesRelativePath);
    if (!fs.existsSync(absolutePath)) {
        console.error("dev_driver: not found in runfiles at " + absolutePath);
        process.exit(2);
    }
    return absolutePath;
}

function livePids(pids) {
    return pids.filter((pid) => {
        try {
            process.kill(pid, 0);
            return true;
        } catch {
            return false;
        }
    });
}

function readMarker(markerPath) {
    try {
        const parsed = JSON.parse(fs.readFileSync(markerPath, "utf8"));
        if (Array.isArray(parsed)) {
            return { pids: parsed, files: null };
        }
        if (Array.isArray(parsed.pids) && Array.isArray(parsed.files)) {
            return parsed;
        }
    } catch {}
    return null;
}

function writeMarker(markerPath, pids, files) {
    fs.writeFileSync(markerPath, JSON.stringify({ pids, files }));
}

const acquiredLinks = [];

function walkFiles(rootDirectory) {
    const files = [];
    const pending = [""];
    while (pending.length > 0) {
        const relative = pending.pop();
        const absolute = path.join(rootDirectory, relative);
        for (const entry of fs.readdirSync(absolute)) {
            const entryRelative = relative ? relative + "/" + entry : entry;
            const entryStat = fs.statSync(path.join(absolute, entry));
            if (entryStat.isDirectory()) {
                pending.push(entryRelative);
            } else if (entryStat.isFile()) {
                files.push(entryRelative);
            }
        }
    }
    return files;
}

function acquireLink(linkPath, runfilesTarget) {
    const markerPath = linkPath + ".rules_vite";
    const existing = fs.lstatSync(linkPath, { throwIfNoEntry: false });
    if (existing && existing.isDirectory() && !existing.isSymbolicLink()) {
        console.error(
            "dev_driver: " + linkPath + " is a real directory (your node_modules)." +
            " The dev server will not touch it. Remove it to let bazel manage node_modules.",
        );
        process.exit(2);
    }
    if (!existing) {
        fs.mkdirSync(path.dirname(linkPath), { recursive: true });
        fs.symlinkSync(runfilesTarget, linkPath, "dir");
        acquiredLinks.push({ pathToRemove: linkPath, markerPath, kind: "link" });
        writeMarker(markerPath, [process.pid], []);
        return;
    }
    if (!existing.isSymbolicLink()) {
        console.error("dev_driver: " + linkPath + " exists and is not a symlink.");
        process.exit(2);
    }
    const currentTarget = fs.readlinkSync(linkPath);
    if (!currentTarget.includes("bazel-out") && !currentTarget.includes(".runfiles") && currentTarget !== runfilesTarget) {
        console.error(
            "dev_driver: " + linkPath + " is a symlink to " + currentTarget +
            " (not ours). Remove it manually if you want the dev server to manage it.",
        );
        process.exit(2);
    }
    acquiredLinks.push({ pathToRemove: linkPath, markerPath, kind: "link" });
    const marker = readMarker(markerPath);
    const pids = marker ? livePids(marker.pids.filter((pid) => pid !== process.pid)) : [];
    writeMarker(markerPath, [...pids, process.pid], []);
}

function acquireOverlayDirectory(targetDirectory, sources) {
    const markerPath = targetDirectory + ".rules_vite";
    const existing = fs.lstatSync(targetDirectory, { throwIfNoEntry: false });
    let trackedFiles = [];
    if (existing) {
        const marker = readMarker(markerPath);
        if (!marker || marker.files === null) {
            console.error(
                "dev_driver: " + targetDirectory + " carries no readable dev-server " +
                "marker. Remove it manually if you want the dev server to own it.",
            );
            process.exit(2);
        }
        trackedFiles = marker.files;
        const untracked = walkFiles(targetDirectory).filter(
            (relativePath) => !trackedFiles.includes(relativePath),
        );
        if (untracked.length > 0) {
            console.error(
                "dev_driver: " + targetDirectory + " contains files the dev server " +
                "did not create: " + untracked.join(", ") +
                ". Remove them or the directory to let the dev server own it.",
            );
            process.exit(2);
        }
        const previousPids = livePids(marker.pids.filter((pid) => pid !== process.pid));
        writeMarker(markerPath, [...previousPids, process.pid], trackedFiles);
    } else {
        fs.mkdirSync(targetDirectory, { recursive: true });
        writeMarker(markerPath, [process.pid], []);
    }
    acquiredLinks.push({ pathToRemove: targetDirectory, markerPath, kind: "overlay" });

    const claimedRelativePaths = new Map();
    const plannedFiles = [];
    const planned = [];
    for (const source of sources) {
        const separator = source.indexOf(":");
        const sourceKind = source.slice(0, separator);
        const sourceLocation = source.slice(separator + 1);
        const sourceRoot = sourceKind === "ws"
            ? path.join(workspaceDirectory, sourceLocation)
            : path.join(runfilesRoot, sourceLocation);
        if (!fs.existsSync(sourceRoot)) {
            console.error("dev_driver: overlay source not found at " + sourceRoot);
            process.exit(2);
        }
        for (const relativePath of walkFiles(sourceRoot)) {
            if (claimedRelativePaths.has(relativePath)) {
                console.error(
                    "dev_driver: overlay collision at " + path.join(targetDirectory, relativePath) +
                    " (" + claimedRelativePaths.get(relativePath) + " and " + sourceRoot +
                    " provide the same relative path).",
                );
                process.exit(2);
            }
            claimedRelativePaths.set(relativePath, sourceRoot);
            plannedFiles.push(relativePath);
            planned.push({ relativePath, sourceKind, sourceRoot });
        }
    }
    const overlayMarker = readMarker(markerPath);
    const survivingPids = livePids(overlayMarker.pids.filter((pid) => pid !== process.pid));
    writeMarker(markerPath, [...survivingPids, process.pid], plannedFiles);

    for (const { relativePath, sourceKind, sourceRoot } of planned) {
        const linkPath = path.join(targetDirectory, relativePath);
        const sourcePath = path.join(sourceRoot, relativePath);
        if (sourceKind === "ws") {
            const existingEntry = fs.lstatSync(linkPath, { throwIfNoEntry: false });
            if (existingEntry && existingEntry.isSymbolicLink() && fs.readlinkSync(linkPath) === sourcePath) {
                continue;
            }
            fs.mkdirSync(path.dirname(linkPath), { recursive: true });
            fs.rmSync(linkPath, { force: true });
            fs.symlinkSync(sourcePath, linkPath, "file");
        } else {
            if (fs.existsSync(linkPath) && fs.readFileSync(linkPath).equals(fs.readFileSync(sourcePath))) {
                continue;
            }
            fs.mkdirSync(path.dirname(linkPath), { recursive: true });
            fs.writeFileSync(linkPath, fs.readFileSync(sourcePath));
        }
    }
}

function removeEmptyDirectories(rootDirectory) {
    let empty = true;
    for (const entry of fs.readdirSync(rootDirectory)) {
        const absolute = path.join(rootDirectory, entry);
        if (fs.statSync(absolute).isDirectory()) {
            if (removeEmptyDirectories(absolute)) {
                fs.rmdirSync(absolute);
            } else {
                empty = false;
            }
        } else {
            empty = false;
        }
    }
    return empty;
}

function releaseLinks() {
    for (const { pathToRemove, markerPath, kind } of acquiredLinks.reverse()) {
        try {
            const marker = readMarker(markerPath);
            if (!marker) {
                continue;
            }
            const otherLivePids = livePids(marker.pids.filter((pid) => pid !== process.pid));
            if (otherLivePids.length > 0) {
                writeMarker(markerPath, otherLivePids, marker.files || []);
                continue;
            }
            if (kind === "overlay") {
                if (marker.files === null) {
                    continue;
                }
                for (const relativePath of marker.files) {
                    fs.rmSync(path.join(pathToRemove, relativePath), { force: true });
                }
                removeEmptyDirectories(pathToRemove);
                try { fs.rmdirSync(pathToRemove); } catch {}
            } else {
                fs.rmSync(pathToRemove, { force: true });
            }
            fs.rmSync(markerPath, { force: true });
        } catch {}
    }
}

process.on("exit", releaseLinks);
for (const [signalName, exitCode] of [["SIGINT", 130], ["SIGTERM", 143], ["SIGHUP", 129]]) {
    process.on(signalName, () => {
        releaseLinks();
        process.exit(exitCode);
    });
}

if (nodeModulesSpec.startsWith("node_modules:")) {
    const nodeModulesRelativePath = nodeModulesSpec.slice("node_modules:".length);
    acquireLink(
        path.join(workspaceDirectory, nodeModulesRelativePath),
        resolveRunfilesPath(nodeModulesRelativePath),
    );
} else if (nodeModulesSpec.startsWith("links:")) {
    for (const linkRelativePath of nodeModulesSpec.slice("links:".length).split(",")) {
        acquireLink(path.join(workspaceDirectory, linkRelativePath), resolveRunfilesPath(linkRelativePath));
    }
} else {
    console.error("dev_driver: unsupported node_modules spec " + nodeModulesSpec);
    process.exit(2);
}

const viteEntryAbsolute = resolveRunfilesPath(viteCliEntry);

for (const overlayEntry of overlaySpec ? overlaySpec.split(";") : []) {
    const overlaySeparator = overlayEntry.indexOf("=");
    if (overlaySeparator <= 0) {
        continue;
    }
    const injectDir = overlayEntry.slice(0, overlaySeparator);
    const sources = overlayEntry.slice(overlaySeparator + 1).split(",");
    const overlayTarget = path.join(workspaceDirectory, appPackage === "." ? "" : appPackage, injectDir);
    acquireOverlayDirectory(overlayTarget, sources);
}

process.chdir(appPackage ? path.join(workspaceDirectory, appPackage) : workspaceDirectory);
process.argv = [process.argv[0], "vite", ...passthroughArgs];

await import(pathToFileURL(viteEntryAbsolute).href);
