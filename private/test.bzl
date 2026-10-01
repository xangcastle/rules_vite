"""Vitest test rule with a compiled native launcher stub.

The test executable is a native stub (hermetic_launcher) that runs node on
a driver script. The driver stages sources, config, and node_modules into
an ephemeral temp directory, then invokes `vitest run` with the project
root pinned to the staged package. Tests run without a shell, without
network access, and without host node_modules.
"""

load("@hermetic_launcher//launcher:lib.bzl", "launcher")
load("//private/helpers:js_stub_binary.bzl", "js_stub_binary")
load("//private/helpers:node.bzl", "runfiles_node_modules_spec", "staged_injected_files")

def _vitest_test_impl(ctx):
    node = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"].nodeinfo.node

    node_modules_spec = runfiles_node_modules_spec(ctx.attr.node_modules, ctx.attr.deps, ctx.label.name)

    if ctx.file.config.short_path.startswith("../"):
        fail(
            "rules_vite %s: config must live in the consuming repository " % ctx.label.name +
            "(got %s); generated configs from other repos are not stageable." % ctx.file.config.short_path,
        )
    staged = []
    for f in ctx.files.srcs:
        staged.append({
            "source": f.path,
            "runfiles_path": f.short_path[3:] if f.short_path.startswith("../") else ctx.workspace_name + "/" + f.short_path,
            "destination": f.short_path,
        })
    config_short_path = ctx.file.config.short_path
    staged.append({
        "source": ctx.file.config.path,
        "runfiles_path": config_short_path[3:] if config_short_path.startswith("../") else ctx.workspace_name + "/" + config_short_path,
        "destination": config_short_path,
    })
    staged.extend(staged_injected_files(ctx))

    manifest = {
        "package": ctx.label.package,
        "config": ctx.file.config.short_path,
        "files": staged,
    }
    manifest_file = ctx.actions.declare_file(ctx.label.name + "_manifest.json")
    ctx.actions.write(manifest_file, json.encode(manifest))

    executable = js_stub_binary(
        ctx,
        node,
        ctx.file._driver,
        runfiles = [manifest_file],
        embedded_args = [node_modules_spec, ctx.attr.vitest_entry],
    )

    files = [ctx.file.config, node, ctx.file._driver, manifest_file] + list(ctx.files.srcs) + list(ctx.files.injected_srcs)
    trees = ([ctx.attr.node_modules[DefaultInfo].files] if ctx.attr.node_modules else []) + [
        dep[DefaultInfo].files
        for dep in ctx.attr.deps
    ]
    runfiles = ctx.runfiles(files = files, transitive_files = depset(transitive = trees))

    return [DefaultInfo(executable = executable, runfiles = runfiles)]

_vitest_test = rule(
    implementation = _vitest_test_impl,
    attrs = {
        "vitest_entry": attr.string(
            doc = "The vitest entry script, workspace-relative inside runfiles.",
            default = "node_modules/vitest/vitest.mjs",
        ),
        "config": attr.label(
            doc = "The vite/vitest config file, staged at the package root inside the stage.",
            allow_single_file = True,
            mandatory = True,
        ),
        "srcs": attr.label_list(
            doc = "Test inputs: application sources staged into the ephemeral tree.",
            allow_files = True,
        ),
        "injected_srcs": attr.label_list(
            doc = "Files staged into inject_dir inside the application.",
            allow_files = True,
        ),
        "inject_dir": attr.string(
            doc = "Package-relative directory injected_srcs land in.",
        ),
        "inject_strip": attr.string(
            doc = "Workspace path prefix stripped from injected_srcs short paths " +
                  "so subdirectories are preserved in the staged tree.",
        ),
        "node_modules": attr.label(
            doc = "The whole npm_link_all_packages tree; prefer deps.",
        ),
        "deps": attr.label_list(
            doc = "Per-package node_modules links (e.g. vitest and the packages " +
                  "the config imports), linked individually in the stage.",
        ),
        "_driver": attr.label(
            doc = "The node driver that stages the app tree and runs vitest.",
            default = Label("//private/tools:test_driver.mjs"),
            allow_single_file = True,
        ),
    },
    test = True,
    toolchains = [
        launcher.finalizer_toolchain_type,
        launcher.template_toolchain_type,
        "@rules_nodejs//nodejs:toolchain_type",
    ],
)

def vitest_test(
        name,
        srcs,
        config,
        args = [],
        deps = [],
        injected_srcs = [],
        inject_dir = "",
        inject_strip = "",
        node_modules = "//:node_modules",
        vitest_entry = "node_modules/vitest/vitest.mjs",
        tags = [],
        visibility = None,
        **kwargs):
    """Runs `vitest run` hermetically via a native (shell-free) launcher stub.

    The test always runs with the `block-network` tag (merged with any
    user-provided tags): vitest resolves everything from runfiles and the
    staged tree. The standard test attributes (`env`, `size`, `data`,
    `args`) behave as for any bazel test target; `args` entries are
    appended by bazel test after the driver's own argv.

    Args:
        name: Test target name.
        srcs: Application sources (must include the config and any file the
            tests import; `srcs = [":<app>.srcs"]`-style filegroups work).
        config: The vite/vitest config file, mandatory. vitest discovers it
            from the package root of the staged tree.
        args: Extra argv entries appended after `vitest run` by bazel test.
            A plain list; no shell interpolation happens anywhere.
        deps: Per-package node_modules links (vitest plus every package the
            config imports). Linked individually in the staged tree.
        injected_srcs: Files staged into inject_dir inside the
            application - the shared component set.
        inject_dir: Package-relative directory injected_srcs land in.
        inject_strip: Workspace path prefix stripped so subdirectories
            survive the injection.
        node_modules: The npm_link_all_packages target of the consuming
            workspace ("//:node_modules").
        vitest_entry: Path of the vitest entry script inside the linked
            node_modules tree, overridden only for exotic package layouts.
        tags: Standard test tags (block-network is always included).
        visibility: Standard visibility (None = package default).
        **kwargs: Forwarded to the rule (tags, testonly, target_compatible_with).
    """
    all_tags = ["block-network"]
    for t in tags:
        if t not in all_tags:
            all_tags.append(t)

    if deps:
        node_modules = None

    _vitest_test(
        name = name,
        vitest_entry = vitest_entry,
        config = config,
        srcs = srcs,
        node_modules = node_modules,
        deps = deps,
        injected_srcs = injected_srcs,
        inject_dir = inject_dir,
        inject_strip = inject_strip,
        args = args,
        tags = all_tags,
        visibility = visibility,
        **kwargs
    )
