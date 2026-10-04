<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API for rules_vite: Vite build, Vitest test, dev server, and node
CLI rules for Bazel with bzlmod.

vite is not vendored by this ruleset. The consumer's `npm_translate_lock`
repository provides it, so plugin peer-dependency versions always match the
application (vite 5/6/7 may coexist in one build graph).

Label arguments are plain strings resolved against the consuming package.
The default `node_modules` label follows the standard rules_js convention
(`npm_link_all_packages` named "node_modules" at the workspace root).

<a id="node_cli"></a>

## node_cli

<pre>
load("@rules_vite//:defs.bzl", "node_cli")

node_cli(<a href="#node_cli-name">name</a>, <a href="#node_cli-package">package</a>, <a href="#node_cli-entry">entry</a>, <a href="#node_cli-cli_args">cli_args</a>, <a href="#node_cli-env">env</a>, <a href="#node_cli-tags">tags</a>, <a href="#node_cli-visibility">visibility</a>, <a href="#node_cli-kwargs">**kwargs</a>)
</pre>

Exposes a node CLI package as a hermetic `bazel run` executable.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="node_cli-name"></a>name |  Target name.   |  none |
| <a id="node_cli-package"></a>package |  The CLI package's node_modules link label.   |  none |
| <a id="node_cli-entry"></a>entry |  The CLI entry script, relative to the package link. shadcn's is "dist/index.js".   |  `"auto"` |
| <a id="node_cli-cli_args"></a>cli_args |  Arguments baked into the stub before the passthrough ones bazel run appends.   |  `[]` |
| <a id="node_cli-env"></a>env |  Environment variables exported for the CLI.   |  `{}` |
| <a id="node_cli-tags"></a>tags |  Standard tags.   |  `[]` |
| <a id="node_cli-visibility"></a>visibility |  Standard visibility (None = package default).   |  `None` |
| <a id="node_cli-kwargs"></a>kwargs |  Forwarded to the rule (tags, testonly, target_compatible_with).   |  none |


<a id="vite_build"></a>

## vite_build

<pre>
load("@rules_vite//:defs.bzl", "vite_build")

vite_build(<a href="#vite_build-name">name</a>, <a href="#vite_build-srcs">srcs</a>, <a href="#vite_build-config">config</a>, <a href="#vite_build-out_dir">out_dir</a>, <a href="#vite_build-args">args</a>, <a href="#vite_build-env">env</a>, <a href="#vite_build-data">data</a>, <a href="#vite_build-deps">deps</a>, <a href="#vite_build-injected_srcs">injected_srcs</a>, <a href="#vite_build-inject_dir">inject_dir</a>,
           <a href="#vite_build-inject_strip">inject_strip</a>, <a href="#vite_build-node_modules">node_modules</a>, <a href="#vite_build-vite">vite</a>, <a href="#vite_build-vite_entry">vite_entry</a>, <a href="#vite_build-visibility">visibility</a>, <a href="#vite_build-kwargs">**kwargs</a>)
</pre>

Runs `vite build` as a sandboxed, shell-free Bazel action.

The action's node driver stages sources, config and node_modules into
an ephemeral temp directory, then runs vite with the project root
pinned to the staged application. out_dir is the declared output (a
TreeArtifact).


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="vite_build-name"></a>name |  Target name. The bundle tree is the target's default output.   |  none |
| <a id="vite_build-srcs"></a>srcs |  Application sources. Defaults to a glob of the usual vite layout (src/**, public/**, index.html, *.json, *.config.*) plus the committed env files (.env, .env.[mode]); per-machine *.local env files are left out. With explicit srcs, list the .env files yourself or the build will not see their VITE_* values (the dev server reads them from the workspace).   |  `None` |
| <a id="vite_build-config"></a>config |  Optional vite config file (label or package-relative path). Passed explicitly via `--config` and staged with the sources.   |  `None` |
| <a id="vite_build-out_dir"></a>out_dir |  Directory declared as the action output. The default, "dist", is vite's own default.   |  `"dist"` |
| <a id="vite_build-args"></a>args |  Extra argv entries appended after the vite build flags. A plain list; no shell interpolation happens anywhere.   |  `[]` |
| <a id="vite_build-env"></a>env |  Extra environment variables for the action (e.g. VITE_* flags).   |  `{}` |
| <a id="vite_build-data"></a>data |  Extra labels staged alongside the sources (merged inputs).   |  `[]` |
| <a id="vite_build-deps"></a>deps |  Per-package node_modules links (for example [":node_modules/vite", ":node_modules/react"]). Each link target carries its full dependency closure in the pnpm store, so the action input is only what the app declares.   |  `[]` |
| <a id="vite_build-injected_srcs"></a>injected_srcs |  Files staged into inject_dir inside the application (subdirectories preserved via inject_strip) for many apps.   |  `[]` |
| <a id="vite_build-inject_dir"></a>inject_dir |  Package-relative directory injected_srcs land in.   |  `""` |
| <a id="vite_build-inject_strip"></a>inject_strip |  Workspace path prefix stripped from injected_srcs so subdirectories are preserved.   |  `""` |
| <a id="vite_build-node_modules"></a>node_modules |  The whole npm_link_all_packages tree - every package enters every sandbox. The default when neither deps nor node_modules is given; pass explicitly only for nested workspace packages that link their own tree.   |  `None` |
| <a id="vite_build-vite"></a>vite |  The vite package link; locates the CLI entry script.   |  `"//:node_modules/vite"` |
| <a id="vite_build-vite_entry"></a>vite_entry |  vite CLI entry script, relative to the vite package link; override only for exotic package manager layouts.   |  `"bin/vite.js"` |
| <a id="vite_build-visibility"></a>visibility |  Standard visibility (None = package default).   |  `None` |
| <a id="vite_build-kwargs"></a>kwargs |  Forwarded to the rule (tags, testonly, target_compatible_with).   |  none |


<a id="vite_run"></a>

## vite_run

<pre>
load("@rules_vite//:defs.bzl", "vite_run")

vite_run(<a href="#vite_run-name">name</a>, <a href="#vite_run-args">args</a>, <a href="#vite_run-inject_dir">inject_dir</a>, <a href="#vite_run-shared_dir">shared_dir</a>, <a href="#vite_run-shared_srcs">shared_srcs</a>, <a href="#vite_run-env">env</a>, <a href="#vite_run-deps">deps</a>, <a href="#vite_run-node_modules">node_modules</a>, <a href="#vite_run-vite_entry">vite_entry</a>, <a href="#vite_run-tags">tags</a>,
         <a href="#vite_run-visibility">visibility</a>, <a href="#vite_run-kwargs">**kwargs</a>)
</pre>

Runs the vite dev server (`bazel run`) with native HMR.

Sources are served live from the workspace - vite's own watcher and
websocket HMR with no intermediate process restarts. The linked
node_modules tree is symlinked into the workspace for the lifetime of
the server and removed on exit; an existing real node_modules
directory is respected and left untouched. Concurrent servers on the
same workspace share the link; the last one to exit removes it.
Dependency (lockfile/BUILD) changes need a server restart; source
changes do not - that is what HMR is for.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="vite_run-name"></a>name |  Target name.   |  none |
| <a id="vite_run-args"></a>args |  Arguments appended to the vite CLI (e.g. ["--host", "--port", "5173"]). Passed by bazel run after the driver's own argv; a plain list, no shell interpolation.   |  `[]` |
| <a id="vite_run-inject_dir"></a>inject_dir |  Package-relative directory the shared sources are linked at for the dev server overlay.   |  `""` |
| <a id="vite_run-shared_dir"></a>shared_dir |  Workspace-relative directory whose files are linked (individually, live for HMR) at inject_dir.   |  `""` |
| <a id="vite_run-shared_srcs"></a>shared_srcs |  Labels whose files are linked at inject_dir from runfiles; use for generated shared trees (e.g. a shadcn component set).   |  `[]` |
| <a id="vite_run-env"></a>env |  Environment variables for the dev server (e.g. VITE_* flags consumed by the app's vite config).   |  `{}` |
| <a id="vite_run-deps"></a>deps |  Per-package node_modules links; linked individually under node_modules in the workspace for the server's lifetime.   |  `[]` |
| <a id="vite_run-node_modules"></a>node_modules |  The npm_link_all_packages target of the consuming workspace ("//:node_modules").   |  `"//:node_modules"` |
| <a id="vite_run-vite_entry"></a>vite_entry |  vite CLI entry script, workspace-relative inside runfiles; override only for exotic package manager layouts.   |  `"node_modules/vite/bin/vite.js"` |
| <a id="vite_run-tags"></a>tags |  Standard tags.   |  `[]` |
| <a id="vite_run-visibility"></a>visibility |  Standard visibility (None = package default).   |  `None` |
| <a id="vite_run-kwargs"></a>kwargs |  Forwarded to the rule (tags, testonly, target_compatible_with).   |  none |


<a id="vitest_test"></a>

## vitest_test

<pre>
load("@rules_vite//:defs.bzl", "vitest_test")

vitest_test(<a href="#vitest_test-name">name</a>, <a href="#vitest_test-srcs">srcs</a>, <a href="#vitest_test-config">config</a>, <a href="#vitest_test-args">args</a>, <a href="#vitest_test-deps">deps</a>, <a href="#vitest_test-injected_srcs">injected_srcs</a>, <a href="#vitest_test-inject_dir">inject_dir</a>, <a href="#vitest_test-inject_strip">inject_strip</a>, <a href="#vitest_test-node_modules">node_modules</a>,
            <a href="#vitest_test-vitest_entry">vitest_entry</a>, <a href="#vitest_test-tags">tags</a>, <a href="#vitest_test-visibility">visibility</a>, <a href="#vitest_test-kwargs">**kwargs</a>)
</pre>

Runs `vitest run` hermetically via a native (shell-free) launcher stub.

The test always runs with the `block-network` tag (merged with any
user-provided tags): vitest resolves everything from runfiles and the
staged tree. The standard test attributes (`env`, `size`, `data`,
`args`) behave as for any bazel test target; `args` entries are
appended by bazel test after the driver's own argv.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="vitest_test-name"></a>name |  Test target name.   |  none |
| <a id="vitest_test-srcs"></a>srcs |  Application sources (must include the config and any file the tests import; `srcs = [":<app>.srcs"]`-style filegroups work).   |  none |
| <a id="vitest_test-config"></a>config |  The vite/vitest config file, mandatory. vitest discovers it from the package root of the staged tree.   |  none |
| <a id="vitest_test-args"></a>args |  Extra argv entries appended after `vitest run` by bazel test. A plain list; no shell interpolation happens anywhere.   |  `[]` |
| <a id="vitest_test-deps"></a>deps |  Per-package node_modules links (vitest plus every package the config imports). Linked individually in the staged tree.   |  `[]` |
| <a id="vitest_test-injected_srcs"></a>injected_srcs |  Files staged into inject_dir inside the application - the shared component set.   |  `[]` |
| <a id="vitest_test-inject_dir"></a>inject_dir |  Package-relative directory injected_srcs land in.   |  `""` |
| <a id="vitest_test-inject_strip"></a>inject_strip |  Workspace path prefix stripped so subdirectories survive the injection.   |  `""` |
| <a id="vitest_test-node_modules"></a>node_modules |  The npm_link_all_packages target of the consuming workspace ("//:node_modules").   |  `"//:node_modules"` |
| <a id="vitest_test-vitest_entry"></a>vitest_entry |  Path of the vitest entry script inside the linked node_modules tree, overridden only for exotic package layouts.   |  `"node_modules/vitest/vitest.mjs"` |
| <a id="vitest_test-tags"></a>tags |  Standard test tags (block-network is always included).   |  `[]` |
| <a id="vitest_test-visibility"></a>visibility |  Standard visibility (None = package default).   |  `None` |
| <a id="vitest_test-kwargs"></a>kwargs |  Forwarded to the rule (tags, testonly, target_compatible_with).   |  none |


