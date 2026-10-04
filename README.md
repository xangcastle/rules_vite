# rules_vite

[Vite](https://vite.dev/) build, [Vitest](https://vitest.dev/) test, dev
server, and node CLI rules for Bazel with bzlmod.

```starlark
bazel_dep(name = "rules_vite", version = "0.1.0")
```

## Quickstart

Requires the standard rules_js setup: a pnpm lockfile translated with
`npm_translate_lock`, packages linked at the workspace root, and the
rules_nodejs toolchain registered.

`MODULE.bazel`:

```starlark
bazel_dep(name = "rules_vite", version = "0.1.0")
bazel_dep(name = "aspect_rules_js", version = "3.1.2")
bazel_dep(name = "rules_nodejs", version = "6.7.4")

node = use_extension("@rules_nodejs//nodejs:extensions.bzl", "node", dev_dependency = True)
node.toolchain(node_version = "22.14.0")
use_repo(node, "nodejs")

npm = use_extension("@aspect_rules_js//npm:extensions.bzl", "npm", dev_dependency = True)
npm.npm_translate_lock(
    name = "npm",
    pnpm_lock = "//:pnpm-lock.yaml",
    verify_node_modules_ignored = "//:.bazelignore",
)
use_repo(npm, "npm")
```

`BUILD.bazel`:

```starlark
load("@npm//:defs.bzl", "npm_link_all_packages")
load("@rules_vite//:defs.bzl", "vite_build", "vite_run", "vitest_test")

npm_link_all_packages(name = "node_modules")

vite_build(
    name = "web",
    srcs = glob(["src/**"]) + ["index.html", "package.json", "vite.config.js"],
)

vitest_test(
    name = "unit_tests",
    srcs = glob(["src/**"]) + ["index.html", "package.json", "vite.config.js"],
    config = "vite.config.js",
)

vite_run(
    name = "web.dev",
    args = ["--host"],
)
```

`bazel build //:web` produces the bundle as a TreeArtifact. `bazel test
//:unit_tests` runs vitest with network access blocked. `bazel run //:web.dev`
starts the dev server. See [e2e/](e2e/) for complete working modules.

## Rules

### vite_build

Runs `vite build` as a sandboxed action. The node runtime is the action
executable, invoked on a driver that stages sources, config, and
node_modules into an ephemeral directory, then runs the vite CLI. The
action runs with `block-network` and produces `out_dir` as a TreeArtifact.

Sourcemap `sources` are rewritten to host-independent paths once vite
exits: application files become workspace-relative (`src/App.jsx`) and
linked packages keep their path below the bin directory
(`node_modules/.aspect_rules_js/react@18.3.1/node_modules/react/index.js`).
Without it every `.map` would encode the staging directory, the output base
and the spawn strategy, and the TreeArtifact digest would change on every
clean build. Inline sourcemaps (`--sourcemap inline`) are not rewritten.

By default the entire `node_modules` tree enters the sandbox. Pass
per-package links via `deps` to include only what the app declares — each
link carries its full dependency closure:

```starlark
vite_build(
    name = "web",
    srcs = glob(["src/**"]) + ["index.html"],
    deps = [
        "//:node_modules/@vitejs/plugin-react",
        "//:node_modules/react",
        "//:node_modules/react-dom",
        "//:node_modules/vite",
    ],
)
```

### vitest_test

Runs `vitest run` via a compiled native stub. The stub invokes a node
driver that stages sources, config, and node_modules into a temp directory
under `TEST_TMPDIR`, then runs vitest with the project root pinned to the
staged package. Tests always run with the `block-network` tag.

Snapshots are compared, never written: the test runs vitest in CI mode, so
a `toMatchSnapshot()` with no committed snapshot fails instead of silently
writing one into the throwaway stage. Commit the `__snapshots__/` files and
keep them in `srcs`; write or update them with vitest outside Bazel
(`vitest run -u`). `--test_env=CI=false` restores vitest's default.

Results are reported per test case: under `bazel test` vitest's JUnit
reporter writes Bazel's `XML_OUTPUT_FILE`, so `bazel-testlogs/<pkg>/<name>/test.xml`
(and anything that reads it: CI test views, BES backends) lists every
case with its file, duration and failure message instead of one entry for
the whole target. The console keeps vitest's `default` reporter unless the
target's `args` pass their own `--reporter`.

`--test_filter=<pattern>` is passed to vitest as `-t <pattern>`: only cases
whose name matches run, the rest are reported as skipped. The test log is
plain text (`NO_COLOR=1`); `--test_env=FORCE_COLOR=1` keeps vitest's colors.

### vite_run

Runs the vite dev server against the real workspace tree. Vite watches
the developer's actual sources and serves websocket HMR directly. The
linked `node_modules` tree is symlinked into the workspace for the
server's lifetime and removed on exit. Source edits trigger HMR without
restarting the server; dependency changes require a restart. The links
land at their own path in the workspace, so `node_modules` and `deps` must
come from the main repository; analysis fails for links from another one.

### node_cli

Exposes an npm CLI package as a `bazel run` executable. The entry script
defaults to the `bin` field of the package's `package.json`. The working
directory is set to `BUILD_WORKSPACE_DIRECTORY`:

```starlark
node_cli(
    name = "shadcn",
    package = "//:node_modules/shadcn",
)
```

## Shared component injection

`injected_srcs` stages files into `inject_dir` inside each app's tree,
preserving subdirectories via `inject_strip`:

```starlark
vite_build(
    name = "web",
    srcs = glob(["src/**"]),
    injected_srcs = ["//libs/components:ui"],
    inject_dir = "src/components/ui",
    inject_strip = "libs/components/src/ui/",
)
```

The dev server links the shared directory at the same path via a
workspace symlink. A complete working setup - five applications, one
component set, one lockfile - lives in [example/](example/README.md).

## shadcn components

```starlark
shadcn = use_extension("@rules_vite//shadcn:extensions.bzl", "shadcn")
shadcn.components(name = "shadcn", lock = "//:shadcn-lock.json")
use_repo(shadcn, "shadcn")
```

Each locked component is extracted from the registry JSON into a tree
that mirrors the registry layout (`@shadcn//:all_files`; also one
js_library per component, `@shadcn//:button`), with registry-internal
imports rewritten to relative paths. Components are pinned by sha256 in
the lock file. A lock entry missing a component that another one
declares as a registry dependency fails the repository fetch with the
name to add.

ui.shadcn.com is mutable: a republished JSON keeps its URL but changes
its bytes, and cold builds break on the sha mismatch. Pin entries with
`urls` (tried in order) and keep the upstream registry behind a mirror
you control:

```json
{
  "components": {
    "button": {
      "urls": [
        "https://mirrors.example.com/shadcn/new-york-v4/button.json",
        "https://ui.shadcn.com/r/styles/new-york-v4/button.json"
      ],
      "sha256": "..."
    }
  }
}
```

## Labels

| Label | Default | Description |
| --- | --- | --- |
| `node_modules` | `//:node_modules` | The `npm_link_all_packages` tree. |
| `node` | toolchain | Resolved from the registered rules_nodejs toolchain. |

Both are overridable. A nested pnpm importer (a sub-package with its own
`npm_link_all_packages`) passes `node_modules = ":node_modules"`, or its own
`":node_modules/<pkg>"` links as `deps`; the vite and vitest entry points
are derived from those same links, so nothing else needs overriding.
`e2e/nested` is the working example. Runfiles address every repository,
including external ones, by canonical name - exactly the form
File.short_path already carries.

## Dev server links

`bazel run` dev servers symlink the linked `node_modules` tree (or the
per-package `deps` links), the `shared_dir` workspace directory and any
`shared_srcs` runfiles trees into the real workspace for their lifetime.
Concurrent servers share those paths through a refcount marker
(`<path>.rules_vite`) that also records every file the driver created in
overlay directories; the last server to exit removes exactly those files
and never touches anything else. A directory holding untracked files
refuses to be adopted, and a stale marker (after kill -9) makes the next
start fail loudly instead of deleting unknown content. The marker is
read-modify-write without a lock: two servers starting in the same
instant can drop a PID from the list, which at worst leaves the path for
manual removal (marker writes are atomic, so a reader never sees a torn
file). A real `node_modules` directory is never touched.

Removal is conditional: a tracked entry goes away only while it is still a
symlink, or a runfiles copy with its original bytes. An editor's "safe
write" (JetBrains, vim with `backupcopy=no`) replaces the symlink with a
regular file, so that edit never reached the shared source; the server
keeps such files and names them on exit, and the next start refuses the
directory until the change is moved where it belongs. Overlays never
mirror `BUILD`, `BUILD.bazel`, `MODULE.bazel`, `WORKSPACE` or `REPO.bazel`,
so no phantom Bazel package appears inside the app while a server runs.

vite's dependency optimizer cache is pinned per application under
`$TMPDIR/rules_vite_dev/<hash>/cache`: a generated config wraps the app's
own and sets `cacheDir` only when the app did not. The default,
`<root>/node_modules/.vite`, would resolve through the linked tree into
`bazel-out`, and every concurrent server of the workspace would share one
cache and invalidate each other's pre-bundles (`504 Outdated Optimize
Dep`, blank pages).

Consumers should gitignore the symlinked paths (`node_modules` without a
trailing slash also matches the symlink, `*.rules_vite` covers the
markers) and any `inject_dir` the dev server links into app packages.
Gitignored paths are invisible to Tailwind v4's automatic content
detection, so a stylesheet that must style overlay-injected components
registers them with an explicit `@source`; without it the dev stylesheet
silently loses every class only those components use. Register the real
shared directory (for a `shared_dir` overlay, `@source` relative to it),
not the overlay path: vite's module graph holds symlink targets by real
path, so a change Tailwind sees under the overlay path falls outside the
graph and forces a full page reload, while the real path keeps it a hot
update. The example's globals.css (`@source "../"`) already lives in the
shared tree.

## Known limitations

- `block-network` is enforced by the local sandbox; remote executors
  honor it only if the platform supports network isolation.
- Staging directories are cleaned by exit and signal handlers; `kill -9`
  still leaks the temp directory.
- On macOS the staging directory lives in TMPDIR, outside the sandbox;
  contents are cleaned but never sandbox-confined.

## Repo layout

```
defs.bzl                    public API
shadcn/                     module extension + repo rules
docs/api/defs.md            generated API reference
example/                    five-app monorepo sharing one component set
e2e/{vanilla,react,shadcn}  standalone consumer modules
private/
  build.bzl, run.bzl, test.bzl, cli.bzl
  helpers/                  js_stub_binary, node, js_library
  tools/                    node drivers
  snapshots/                committed snapshots of generated repos
  tests/                    bazel_skylib unittest suites
```

## Development

```bash
bazel run //:buildifier -- --mode=check --lint=warn <files>
bazel run //:gazelle
bazel run //docs:update_docs
bazel run //private/snapshots:snapshots
bazel test //private/...
```

## Compatibility

Bazel 8+ (bzlmod), macOS and Linux. CI (Bazel 8.7.0 and 9.2.0, ubuntu and
macos) covers vite 7.3.1 and 8.3.1, vitest 3.2.4 and 5.0.3 across the
consumer modules under `e2e/` and `example/`.
