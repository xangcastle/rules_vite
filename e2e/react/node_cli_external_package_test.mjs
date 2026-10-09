import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import path from "node:path";

const [cliStub] = process.argv.slice(2);

const result = spawnSync(path.resolve(cliStub), ["from", "another", "repository"], {
    encoding: "utf8",
    env: { ...process.env, RUNFILES_DIR: process.env.RUNFILES_DIR || process.env.TEST_SRCDIR },
});

assert.equal(result.status, 0, `exit ${result.status}\nstdout: ${result.stdout}\nstderr: ${result.stderr}`);
assert.equal(result.stdout, "greet from another repository\n");
