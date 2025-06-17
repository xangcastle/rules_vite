"""Rules for vite"""

VITE_DEPENDENCIES = [
    "//:node_modules/vite",
]

VITEST_DEPENDENCIES = [
    "//:node_modules/vite",
    "//:node_modules/vitest",
    "//:node_modules/jsdom",
]

VITE_LIBRARY_DEPENDENCIES = [
    "//:node_modules/vite",
]

def _vite_binary_impl(ctx):
    # Include files from vite_library dependencies
    dep_files = []
    for dep in ctx.attr.deps:
        dep_files.extend(dep[DefaultInfo].files.to_list())

    core_runfiles = ctx.files.srcs + ctx.files._vite_deps + dep_files

    if ctx.attr.vite_config:
        config_file = ctx.file.vite_config
        script_content = """
#!/bin/bash
set -e

export BAZEL_VITE_ROOT="${{BUILD_WORKSPACE_DIRECTORY}}/{package}"

exec ./{vite_cli} --config {config_short_path} "$@"
""".format(
            vite_cli = ctx.executable.vite_cli.short_path,
            package = ctx.label.package,
            config_short_path = config_file.short_path,
        )
        runfiles_files = core_runfiles + [config_file]
    else:
        config_template = ctx.actions.declare_file(ctx.label.name + ".config.mjs")
        ctx.actions.write(
            output = config_template,
            content = """
import { defineConfig } from 'vite'
export default defineConfig({
    root: '__ROOT_DIR__',
    server: {
        host: '0.0.0.0',
    }
})
""",
        )
        script_content = """
#!/bin/bash
set -e

CONFIG_TEMPLATE_PATH="{config_template}"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${{TMP_DIR}}"' EXIT
CONFIG_PATH="${{TMP_DIR}}/vite.config.mjs"

ln -s "$(pwd)/node_modules" "${{TMP_DIR}}/node_modules"

ROOT_DIR="${{BUILD_WORKSPACE_DIRECTORY}}/{package}"

sed "s|__ROOT_DIR__|${{ROOT_DIR}}|g" "${{CONFIG_TEMPLATE_PATH}}" > "${{CONFIG_PATH}}"

exec ./{vite_cli} --config "${{CONFIG_PATH}}" "$@"
""".format(
            vite_cli = ctx.executable.vite_cli.short_path,
            package = ctx.label.package,
            config_template = config_template.short_path,
        )
        runfiles_files = core_runfiles + [config_template]

    script = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = runfiles_files,
    ).merge(ctx.attr.vite_cli[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            executable = script,
            runfiles = runfiles,
        ),
    ]

vite_binary = rule(
    implementation = _vite_binary_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Additional source files needed for the application",
        ),
        "deps": attr.label_list(
            doc = "List of node_modules dependencies",
        ),
        "vite_config": attr.label(
            allow_single_file = True,
            doc = "Custom vite config file.",
        ),
        "vite_cli": attr.label(
            default = Label("//vite:vite_cli"),
            executable = True,
            cfg = "exec",
            doc = "The vite CLI tool to use for bundling the application",
        ),
        "_vite_deps": attr.label_list(
            default = VITE_DEPENDENCIES,
        ),
    },
    executable = True,
)

def _vite_test_impl(ctx):
    config_file = ctx.file.vite_config

    script_content = """
#!/bin/bash
set -e
exec ./{vitest_cli} run --root {package_root}
""".format(
        vitest_cli = ctx.executable._vitest_cli.short_path,
        package_root = ctx.label.package,
    )

    script = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    # Include files from vite_library dependencies
    dep_files = []
    for dep in ctx.attr.deps:
        dep_files.extend(dep[DefaultInfo].files.to_list())

    runfiles = ctx.runfiles(
        files = ctx.files.srcs + dep_files + ctx.files._vitest_deps + [config_file],
    ).merge(ctx.attr._vitest_cli[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            executable = script,
            runfiles = runfiles,
        ),
    ]

vite_test = rule(
    implementation = _vite_test_impl,
    test = True,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "A list of source files, test files, and any other assets needed for the test to run. This should include all transitive source files, such as `.css` files, SVGs, and `tsconfig.json` files if applicable.",
        ),
        "deps": attr.label_list(
            doc = "A list of `node_modules` dependencies required by the test. These are typically targets from the root `BUILD.bazel` file (e.g., `//:node_modules/@testing-library/react`).",
        ),
        "vite_config": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "The `vitest.config.ts` (or `.js`, `.mjs`) file for the test. This file is made available in the runfiles and will be found by Vitest by convention, as the test root is set to the package directory.",
        ),
        "_vitest_cli": attr.label(
            default = Label("//vite:vitest_cli"),
            executable = True,
            cfg = "exec",
        ),
        "_vitest_deps": attr.label_list(
            default = VITEST_DEPENDENCIES,
        ),
    },
)

def _vite_library_impl(ctx):
    """Implementation for vite_library rule."""

    return [
        DefaultInfo(
            files = depset(ctx.files.srcs),
        ),
    ]

vite_library = rule(
    implementation = _vite_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "Source files for the library",
        ),
        "deps": attr.label_list(
            doc = "List of node_modules dependencies",
        ),
    },
)
