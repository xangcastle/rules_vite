"""Vite dev server as a `bazel run` target with native HMR.

The executable is a compiled native stub that runs node on a driver
script. The driver serves the real workspace tree so vite watches the
developer's actual sources and serves websocket HMR directly. The linked
node_modules tree is symlinked into the workspace for the server's
lifetime and removed on exit; a pre-existing real node_modules directory
is never touched. Source edits trigger HMR without a server restart;
dependency changes require restarting the server.
"""

load("@hermetic_launcher//launcher:lib.bzl", "launcher")
load("//private/helpers:js_stub_binary.bzl", "js_stub_binary")
load("//private/helpers:node.bzl", "link_rel")

def _vite_run_impl(ctx):
    node = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"].nodeinfo.node
    nm_rel = None
    if ctx.attr.node_modules:
        nm_rel = link_rel(ctx.attr.node_modules.label)
    elif not ctx.attr.deps:
        nm_rel = "node_modules"

    overlay_arg = "-"
    if ctx.attr.inject_dir and ctx.attr.shared_dir:
        overlay_arg = ctx.attr.inject_dir + "=" + ctx.attr.shared_dir

    executable = js_stub_binary(
        ctx,
        node,
        ctx.file._driver,
        embedded_args = [
            nm_rel or "-",
            ctx.attr.vite_entry,
            ctx.label.package or ".",
            overlay_arg,
        ] + list(ctx.attr.args),
    )

    trees = ([ctx.attr.node_modules[DefaultInfo].files] if ctx.attr.node_modules else []) + [
        dep[DefaultInfo].files
        for dep in ctx.attr.deps
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
            doc = "The vite CLI entry script, workspace-relative inside runfiles.",
            default = "node_modules/vite/bin/vite.js",
        ),
        "node_modules": attr.label(
            doc = "The whole npm_link_all_packages tree; prefer deps.",
        ),
        "deps": attr.label_list(
            doc = "Extra node_modules-providing labels staged into runfiles.",
        ),
        "inject_dir": attr.string(
            doc = "Package-relative directory the shared sources are linked at.",
        ),
        "shared_dir": attr.string(
            doc = "Workspace-relative real directory linked at inject_dir.",
        ),
        "env": attr.string_dict(
            doc = "Environment variables exported for the dev server (e.g. VITE_* flags).",
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
        env = {},
        deps = [],
        node_modules = "//:node_modules",
        vite_entry = "node_modules/vite/bin/vite.js",
        tags = [],
        visibility = None,
        **kwargs):
    """Runs the vite dev server (`bazel run`) with native HMR.

    Sources are served live from the workspace - vite's own watcher and
    websocket HMR with no intermediate process restarts. The linked
    node_modules tree is
    symlinked into the workspace for the lifetime of the server and
    removed on exit; an existing real node_modules directory is respected
    and left untouched. Dependency (lockfile/BUILD) changes need a
    server restart; source changes do not - that is what HMR is for.

    Args:
        name: Target name.
        args: Arguments passed to the vite CLI (e.g. ["--host", "--port",
            "5173"]). A plain list; no shell interpolation happens.
        inject_dir: Package-relative directory the shared sources are
            linked at for the dev server overlay.
        shared_dir: Workspace-relative real directory linked at
            inject_dir.
        env: Environment variables for the dev server (e.g. VITE_* flags
            consumed by the app's vite config).
        deps: Extra node_modules-providing labels staged into runfiles.
        node_modules: The npm_link_all_packages target of the consuming
            workspace ("//:node_modules").
        vite_entry: vite CLI entry script, workspace-relative inside
            runfiles; override only for exotic package manager layouts.
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
        args = args,
        env = env,
        tags = tags,
        visibility = visibility,
        **kwargs
    )
