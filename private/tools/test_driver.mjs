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

const snapshotUpdateRequested = passthroughArgs.some((arg) => arg === "-u" || arg === "--update");
const workspaceToUpdate = process.env.BUILD_WORKSPACE_DIRECTORY;
if (snapshotUpdateRequested && !workspaceToUpdate) {
    console.error(
        "test_driver: -u/--update rewrites snapshots in the source tree, which `bazel test` cannot " +
        "reach. Run `bazel run " + (process.env.TEST_TARGET || "<test target>") + " -- -u` instead.",
    );
    process.exit(2);
}

const workspaceSourceContents = new Map(
    manifest.files
        .filter((stagedFile) => stagedFile.runfiles_path.endsWith("/" + stagedFile.destination))
        .map((stagedFile) => [stagedFile.destination, fs.readFileSync(path.join(stageDirectory, stagedFile.destination))]),
);

function isSnapshotFile(relativePath) {
    return relativePath.split("/").includes("__snapshots__");
}

function stagedFilesBelow(directory, relativeDirectory = "") {
    const files = [];
    for (const entry of fs.readdirSync(path.join(directory, relativeDirectory), { withFileTypes: true })) {
        const relativePath = relativeDirectory ? relativeDirectory + "/" + entry.name : entry.name;
        if (entry.isDirectory() && entry.name !== "node_modules") {
            files.push(...stagedFilesBelow(directory, relativePath));
        } else if (entry.isFile()) {
            files.push(relativePath);
        }
    }
    return files;
}

function writeSnapshotUpdatesToWorkspace() {
    const stagedFiles = new Set(stagedFilesBelow(stageDirectory));
    for (const relativePath of stagedFiles) {
        const original = workspaceSourceContents.get(relativePath);
        const current = fs.readFileSync(path.join(stageDirectory, relativePath));
        const changed = original ? !original.equals(current) : isSnapshotFile(relativePath);
        if (changed) {
            const workspacePath = path.join(workspaceToUpdate, relativePath);
            fs.mkdirSync(path.dirname(workspacePath), { recursive: true });
            fs.writeFileSync(workspacePath, current);
            console.log("test_driver: updated " + relativePath);
        }
    }
    for (const relativePath of workspaceSourceContents.keys()) {
        if (isSnapshotFile(relativePath) && !stagedFiles.has(relativePath)) {
            fs.rmSync(path.join(workspaceToUpdate, relativePath), { force: true });
            console.log("test_driver: removed obsolete " + relativePath);
        }
    }
}

if (snapshotUpdateRequested) {
    process.prependListener("exit", writeSnapshotUpdatesToWorkspace);
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
if (process.env.FORCE_COLOR === undefined) {
    process.env.NO_COLOR ??= "1";
}

const callerPassedConfig = passthroughArgs.some(
    (arg) => arg === "-c" || arg === "--config" || arg.startsWith("--config="),
);
const configArgs = callerPassedConfig ? [] : ["--config", path.join(stageDirectory, manifest.config)];

function githubActionsReporterModule() {
    const vitestManifest = JSON.parse(fs.readFileSync(path.join(stageDirectory, "node_modules", "vitest", "package.json"), "utf8"));
    return "./reporters" in (vitestManifest.exports ?? {}) ? "vitest/reporters" : "vitest/node";
}

function writeGithubActionsReporter() {
    const reporterPath = path.join(stageDirectory, ".rules_vite", "github-actions-reporter.mjs");
    const stageRoots = [...new Set([stageDirectory, fs.realpathSync(stageDirectory)])];
    fs.mkdirSync(path.dirname(reporterPath), { recursive: true });
    fs.writeFileSync(
        reporterPath,
        'import path from "node:path";\n' +
        `import { GithubActionsReporter } from ${JSON.stringify(githubActionsReporterModule())};\n` +
        `const stageRoots = ${JSON.stringify(stageRoots)};\n` +
        `const repositoryPrefix = ${JSON.stringify(process.env.RULES_VITE_ANNOTATION_PREFIX || "")};\n` +
        "function repositoryPath(file) {\n" +
        "    for (const stageRoot of stageRoots) {\n" +
        "        const relative = path.relative(stageRoot, file);\n" +
        "        if (!relative.startsWith(\"..\") && !path.isAbsolute(relative)) {\n" +
        "            return path.posix.join(repositoryPrefix, relative.split(path.sep).join(\"/\"));\n" +
        "        }\n" +
        "    }\n" +
        "    return file;\n" +
        "}\n" +
        "export default class RepositoryPathGithubActionsReporter extends GithubActionsReporter {\n" +
        "    constructor() {\n" +
        "        super({ onWritePath: repositoryPath });\n" +
        "    }\n" +
        "}\n",
    );
    return reporterPath;
}

const callerPassedReporter = passthroughArgs.some((arg) => arg === "--reporter" || arg.startsWith("--reporter="));
const writesJunit = Boolean(process.env.XML_OUTPUT_FILE);
const annotatesGithub = process.env.GITHUB_ACTIONS === "true";
const reporterArgs = [
    ...(!callerPassedReporter && (writesJunit || annotatesGithub) ? ["--reporter=default"] : []),
    ...(writesJunit ? ["--reporter=junit", `--outputFile.junit=${process.env.XML_OUTPUT_FILE}`] : []),
    ...(annotatesGithub ? [`--reporter=${writeGithubActionsReporter()}`] : []),
];
const testNameFilterArgs = process.env.TESTBRIDGE_TEST_ONLY ? ["-t", process.env.TESTBRIDGE_TEST_ONLY] : [];

const undeclaredOutputsDirectory = process.env.TEST_UNDECLARED_OUTPUTS_DIR;
const stagedFilesBeforeRun = new Set(stagedFilesBelow(stageDirectory));
const stagedPackagePrefix = manifest.package ? manifest.package + "/" : "";

function copyRunOutputsToUndeclaredOutputs() {
    for (const relativePath of stagedFilesBelow(stageDirectory)) {
        const writtenByRun = !stagedFilesBeforeRun.has(relativePath)
            && relativePath.startsWith(stagedPackagePrefix)
            && !relativePath.startsWith(".rules_vite/")
            && !isSnapshotFile(relativePath);
        if (writtenByRun) {
            const outputPath = path.join(undeclaredOutputsDirectory, relativePath.slice(stagedPackagePrefix.length));
            fs.mkdirSync(path.dirname(outputPath), { recursive: true });
            fs.copyFileSync(path.join(stageDirectory, relativePath), outputPath);
        }
    }
}

if (undeclaredOutputsDirectory) {
    process.prependListener("exit", copyRunOutputsToUndeclaredOutputs);
}
const coverageDirectory = process.env.COVERAGE_DIR;
const coverageArgs = coverageDirectory
    ? [
        "--coverage.enabled=true",
        "--coverage.reportsDirectory=coverage",
        ...["text", "html", "clover", "json", "lcov"].map((reporter) => `--coverage.reporter=${reporter}`),
    ]
    : [];

function workspaceRelativeSourcePath(sourceFile) {
    const absoluteSourceFile = path.isAbsolute(sourceFile) ? sourceFile : path.join(stagedPackageDirectory, sourceFile);
    for (const stageRoot of new Set([stageDirectory, fs.realpathSync(stageDirectory)])) {
        const relative = path.relative(stageRoot, absoluteSourceFile);
        if (!relative.startsWith("..") && !path.isAbsolute(relative)) {
            return relative.split(path.sep).join("/");
        }
    }
    return sourceFile;
}

function writeCoverageForBazel() {
    const lcovPath = path.join(stagedPackageDirectory, "coverage", "lcov.info");
    if (!fs.existsSync(lcovPath)) {
        return;
    }
    const lcov = fs.readFileSync(lcovPath, "utf8")
        .split("\n")
        .map((line) => (line.startsWith("SF:") ? "SF:" + workspaceRelativeSourcePath(line.slice(3)) : line))
        .join("\n");
    fs.writeFileSync(path.join(coverageDirectory, "vitest_lcov.dat"), lcov);
}

const coverageManifest = process.env.COVERAGE_MANIFEST;
if (coverageDirectory && coverageManifest && fs.existsSync(coverageManifest) && fs.statSync(coverageManifest).size === 0) {
    console.error(
        "test_driver: bazel coverage instruments no files for this target, so its coverage.dat stays empty. " +
        "vitest_test sources are attributes of the test itself: add --instrument_test_targets " +
        "(e.g. `coverage --instrument_test_targets` in .bazelrc).",
    );
}

if (coverageDirectory) {
    process.prependListener("exit", writeCoverageForBazel);
}

process.argv = [process.argv[0], "vitest", "run", ...configArgs, ...reporterArgs, ...coverageArgs, ...testNameFilterArgs, ...passthroughArgs];

await import(pathToFileURL(resolveWorkspaceRunfilesPath(vitestEntryScript)).href);
