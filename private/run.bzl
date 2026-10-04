"""Vite dev server as a `bazel run` target with native HMR.

The executable is a compiled native stub that runs node on a driver
script. The driver serves the real workspace tree so vite watches the
developer's actual sources and serves websocket HMR directly. The linked
node_modules tree is symlinked into the workspace for the servers'
lifetime and removed by the last server to exit; a pre-existing real
node_modules directory is never touched. Source edits trigger HMR without
a server restart; dependency changes require restarting the server.
"""

load("@hermetic_launcher//launcher:lib.bzl", "launcher")
load("//private/helpers:js_stub_binary.bzl", "js_stub_binary")
load("//private/helpers:node.bzl", "overlay_root_error", "package_entry_path", "runfiles_node_modules_spec", "runfiles_tree_root")

def _vite_run_impl(ctx):
    node = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"].nodeinfo.node

    node_modules_spec = runfiles_node_modules_spec(ctx.attr.node_modules, ctx.attr.deps, ctx.label.name)

    overlay_sources = []
    if ctx.attr.shared_dir:
        overlay_sources.append("ws:" + ctx.attr.shared_dir)
    if ctx.attr.shared_srcs:
        shared_files = depset(transitive = [
            dep[DefaultInfo].files
            for dep in ctx.attr.shared_srcs
        ])
        shared_root = runfiles_tree_root(shared_files)
        error = overlay_root_error(shared_root, ctx.label.name)
        if error:
            fail(error)
        overlay_sources.append("rf:" + shared_root)
    overlay_spec = "-"
    if ctx.attr.inject_dir and overlay_sources:
        overlay_spec = ctx.attr.inject_dir + "=" + ",".join(overlay_sources)

    vite_entry = ctx.attr.vite_entry or package_entry_path(
        ctx.attr.node_modules.label if ctx.attr.node_modules else None,
        [dep.label for dep in ctx.attr.deps],
        "vite",
        "bin/vite.js",
        ctx.label.name,
    )

    executable = js_stub_binary(
        ctx,
        node,
        ctx.file._driver,
        runfiles = [],
        embedded_args = [
            node_modules_spec or "-",
            vite_entry,
            ctx.label.package or ".",
            overlay_spec,
        ],
    )

    trees = ([ctx.attr.node_modules[DefaultInfo].files] if ctx.attr.node_modules else []) + [
        dep[DefaultInfo].files
        for dep in ctx.attr.deps
    ] + [
        dep[DefaultInfo].files
        for dep in ctx.attr.shared_srcs
    ]
    runfiles = ctx.runfiles(
        files = [node, ctx.file._driver],
        transitive_files = depset(transitive = trees),
    )

    return [
        DefaultInfo(executable = executable, runfiles = runfiles),
        RunEnvironmentInfo(environment = dict(ctx.attr.env)),
    ]

_vite_run = rule(
    implementation = _vite_run_impl,
    attrs = {
        "vite_entry": attr.string(
            doc = "The vite CLI entry script, workspace-relative inside runfiles. " +
                  "Empty derives it from node_modules (or the vite link in deps).",
        ),
        "node_modules": attr.label(
            doc = "The whole npm_link_all_packages tree; prefer deps.",
        ),
        "deps": attr.label_list(
            doc = "Per-package node_modules links; linked individually under " +
                  "node_modules in the workspace for the server's lifetime.",
        ),
        "inject_dir": attr.string(
            doc = "Package-relative directory the shared sources are linked at.",
        ),
        "shared_dir": attr.string(
            doc = "Workspace-relative directory whose files are linked at inject_dir.",
        ),
        "shared_srcs": attr.label_list(
            doc = "Labels whose files are linked at inject_dir from runfiles " +
                  "(generated shared trees); their deepest common directory " +
                  "is used as the source root.",
        ),
        "env": attr.string_dict(
            doc = "Environment variables exported for the dev server.",
        ),
        "_driver": attr.label(
            doc = "The node driver that links node_modules and runs vite.",
            default = Label("//private/tools:dev_driver.mjs"),
            allow_single_file = True,
        ),
    },
    executable = True,
    toolchains = [
        launcher.finalizer_toolchain_type,
        launcher.template_toolchain_type,
        "@rules_nodejs//nodejs:toolchain_type",
    ],
)

def vite_run(
        name,
        args = [],
        inject_dir = "",
        shared_dir = "",
        shared_srcs = [],
        env = {},
        deps = [],
        node_modules = "//:node_modules",
        vite_entry = "",
        tags = [],
        visibility = None,
        **kwargs):
    """Runs the vite dev server (`bazel run`) with native HMR.

    Sources are served live from the workspace - vite's own watcher and
    websocket HMR with no intermediate process restarts. The linked
    node_modules tree is symlinked into the workspace for the lifetime of
    the server and removed on exit; an existing real node_modules
    directory is respected and left untouched. Concurrent servers on the
    same workspace share the link; the last one to exit removes it.
    Dependency (lockfile/BUILD) changes need a server restart; source
    changes do not - that is what HMR is for.

    Args:
        name: Target name.
        args: Arguments appended to the vite CLI (e.g. ["--host",
            "--port", "5173"]). Passed by bazel run after the driver's
            own argv; a plain list, no shell interpolation.
        inject_dir: Package-relative directory the shared sources are
            linked at for the dev server overlay.
        shared_dir: Workspace-relative directory whose files are linked
            (individually, live for HMR) at inject_dir.
        shared_srcs: Labels whose files are linked at inject_dir from
            runfiles; use for generated shared trees (e.g. a shadcn
            component set).
        env: Environment variables for the dev server (e.g. VITE_* flags
            consumed by the app's vite config).
        deps: Per-package node_modules links; linked individually under
            node_modules in the workspace for the server's lifetime.
        node_modules: The npm_link_all_packages target of the consuming
            workspace ("//:node_modules").
        vite_entry: vite CLI entry script, workspace-relative inside
            runfiles. Empty (the default) derives it from node_modules, or
            from the vite link in deps; override only for exotic layouts.
        tags: Standard tags.
        visibility: Standard visibility (None = package default).
        **kwargs: Forwarded to the rule (tags, testonly, target_compatible_with).
    """
    if deps:
        node_modules = None

    _vite_run(
        name = name,
        vite_entry = vite_entry,
        node_modules = node_modules,
        deps = deps,
        inject_dir = inject_dir,
        shared_dir = shared_dir,
        shared_srcs = shared_srcs,
        env = env,
        args = args,
        tags = tags,
        visibility = visibility,
        **kwargs
    )
