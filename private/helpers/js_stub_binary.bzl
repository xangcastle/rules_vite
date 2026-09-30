"""Compiles native launcher stubs for `bazel run` and test executables.

The stub contract: `node <script> [runfiles...] [embedded_args...] "$@"`.
The node runtime and script are resolved from runfiles via rlocation.
Build actions do not use this module; they run node directly as the
action executable.
"""

load("@hermetic_launcher//launcher:lib.bzl", "launcher")

def js_stub_binary(ctx, node, script, runfiles = [], embedded_args = []):
    """Compiles the node-contract stub and returns its executable File.

    The contract: `node <script> [runfiles...] [embedded_args...] "$@"`
    where node, script and runfiles are rlocation-resolved runfiles.

    Args:
        ctx: The rule context; the declaring rule must declare the
            toolchains [launcher.finalizer_toolchain_type,
            launcher.template_toolchain_type].
        node: The node runtime File (attr.label allow_single_file,
            executable). Staged as a runfile by the caller.
        script: The driver script File. Staged as a runfile by the caller.
        runfiles: Extra Files staged as runfiles by the caller, appended
            after the script as rlocation-resolved arguments (data the
            driver reads by path).
        embedded_args: Ordered argv entries appended after the runfiles;
            plain strings only (empty strings are rejected by the stub -
            use "." or omit).

    Returns:
        The executable File (the compiled stub).
    """
    embedded, transformed = launcher.args_from_entrypoint(node)
    embedded, transformed = launcher.append_runfile(
        file = script,
        embedded_args = embedded,
        transformed_args = transformed,
    )
    for file in runfiles:
        embedded, transformed = launcher.append_runfile(
            file = file,
            embedded_args = embedded,
            transformed_args = transformed,
        )
    for arg in embedded_args:
        embedded, transformed = launcher.append_embedded_arg(
            arg = arg,
            embedded_args = embedded,
            transformed_args = transformed,
        )
    executable = ctx.actions.declare_file(ctx.label.name + "_stub")
    launcher.compile_stub(
        ctx = ctx,
        embedded_args = embedded,
        transformed_args = transformed,
        output_file = executable,
    )
    return executable
