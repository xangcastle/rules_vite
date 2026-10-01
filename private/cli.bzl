"""Expose a node CLI package as a hermetic `bazel run` executable.

The executable is a compiled native stub that runs node on the package's
entry script with remaining arguments passed through. The entry defaults
to the `bin` field of the package's package.json. The working directory
is set to BUILD_WORKING_DIRECTORY so the CLI operates on the workspace.
The package's dependency closure rides along in runfiles.
"""

load("@hermetic_launcher//launcher:lib.bzl", "launcher")
load("//private/helpers:js_stub_binary.bzl", "js_stub_binary")
load("//private/helpers:node.bzl", "link_rel")

def _node_cli_impl(ctx):
    node = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"].nodeinfo.node
    package_path = link_rel(ctx.attr.package.label)

    executable = js_stub_binary(
        ctx,
        node,
        ctx.file._driver,
        embedded_args = [package_path, ctx.attr.entry] + list(ctx.attr.cli_args),
    )

    runfiles = ctx.runfiles(
        files = [node, ctx.file._driver],
        transitive_files = depset(transitive = [
            ctx.attr.package[DefaultInfo].files,
        ]),
    )

    return [
        DefaultInfo(executable = executable, runfiles = runfiles),
        RunEnvironmentInfo(environment = dict(ctx.attr.env)),
    ]

_node_cli = rule(
    implementation = _node_cli_impl,
    attrs = {
        "package": attr.label(
            doc = "The CLI package's node_modules link (e.g. \":node_modules/shadcn\").",
            mandatory = True,
        ),
        "entry": attr.string(
            doc = "The CLI entry script relative to the package link, or 'auto' to read the bin field from package.json.",
            default = "auto",
        ),
        "env": attr.string_dict(
            doc = "Environment variables exported for the CLI.",
        ),
        "cli_args": attr.string_list(
            doc = "Arguments baked into the stub before the passthrough ones; " +
                  "the implicit args attribute is reserved for bazel run and bazel_env.",
        ),
        "_driver": attr.label(
            doc = "The node driver that resolves the entry inside runfiles.",
            default = Label("//private/tools:cli_driver.mjs"),
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

def node_cli(
        name,
        package,
        entry = "auto",
        cli_args = [],
        env = {},
        tags = [],
        visibility = None,
        **kwargs):
    """Exposes a node CLI package as a hermetic `bazel run` executable.

    Args:
        name: Target name.
        package: The CLI package's node_modules link label.
        entry: The CLI entry script, relative to the package link. shadcn's
            is "dist/index.js".
        cli_args: Arguments baked into the stub before the passthrough
            ones bazel run appends.
        env: Environment variables exported for the CLI.
        tags: Standard tags.
        visibility: Standard visibility (None = package default).
        **kwargs: Forwarded to the rule (tags, testonly, target_compatible_with).
    """
    _node_cli(
        name = name,
        package = package,
        entry = entry,
        cli_args = cli_args,
        env = env,
        tags = tags,
        visibility = visibility,
        **kwargs
    )
