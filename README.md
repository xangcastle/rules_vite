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

### vite_run

Runs the vite dev server against the real workspace tree. Vite watches
the developer's actual sources and serves websocket HMR directly. The
linked `node_modules` tree is symlinked into the workspace for the
server's lifetime and removed on exit. Source edits trigger HMR without
restarting the server; dependency changes require a restart.

### node_cli

Exposes an npm CLI package as a `bazel run` executable. The entry script
defaults to the `bin` field of the package's `package.json`. The working
directory is set to `BUILD_WORKSPACE_DIRECTORY`:

```starlark
node_cli(
    name = "chadcn",
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
workspace symlink.

## shadcn components

```starlark
chadcn = use_extension("@rules_vite//chadcn:extensions.bzl", "chadcn")
chadcn.components(name = "shadcn", lock = "//:shadcn-lock.json")
use_repo(chadcn, "shadcn")
```

Each locked component is extracted from the registry JSON into a real
source file exposed as a js_library (`@shadcn//:button`). Components are
pinned by sha256 in the lock file.

## Labels

| Label | Default | Description |
| --- | --- | --- |
| `node_modules` | `//:node_modules` | The `npm_link_all_packages` tree. |
| `node` | toolchain | Resolved from the registered rules_nodejs toolchain. |

Both are overridable. Nested workspace packages point at their own linked
tree by overriding `node_modules`.

## Known limitations

- `deps` in `vitest_test` does not support configs that import npm
  packages: vitest loads the config through its own module graph, not
  through the staged per-package links. Use `node_modules` for tests
  whose configs import plugins.
- `deps` in `vite_run` is accepted but the dev server needs a full
  `node_modules` tree for the workspace symlink.
- `block-network` is enforced by the local sandbox; remote executors
  honor it only if the platform supports network isolation.
- The build driver's staging directory is cleaned via process exit
  handlers; a `kill -9` may leave a temp directory.

## Repo layout

```
defs.bzl                    public API
chadcn/                     module extension + repo rules
docs/api/defs.md            generated API reference
e2e/{vanilla,react,chadcn}  standalone consumer modules
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

Bazel 8+ (bzlmod), macOS and Linux. Verified with Bazel 8.7.0 and 9.2.0,
aspect_rules_js 3.x, vite 7.3.1, vitest 3.2.x.
