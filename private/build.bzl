"""`vite build` as a sandboxed Bazel action.

The action executable is the node runtime resolved from the rules_nodejs
toolchain. A node driver stages sources, config, and node_modules into an
ephemeral temp directory, then runs the vite CLI with the project root
pinned to the staged application. The action runs with block-network and
produces out_dir as a TreeArtifact output. No shell is involved anywhere.
"""

load("//private:validation.bzl", "vite_build_validation_error")
load("//private/helpers:node.bzl", "foreign_src_error", "link_package_name", "link_path", "staged_injected_files")

def _vite_build_impl(ctx):
    node = ctx.toolchains["@rules_nodejs//nodejs:toolchain_type"].nodeinfo.node
    vite_entry = link_path(ctx.attr.vite.label, ctx.bin_dir.path) + "/" + ctx.attr.vite_entry

    package_links = None
    node_modules_root = None
    if ctx.attr.deps:
        if ctx.attr.node_modules:
            fail(
                "rules_vite %s: pass either node_modules (whole linked tree) " % ctx.label.name +
                "or deps (per-package links), not both.",
            )
        package_links = [
            {
                "package_name": link_package_name(dep.label),
                "execroot_source": link_path(dep.label, ctx.bin_dir.path),
            }
            for dep in ctx.attr.deps
        ]
    elif ctx.attr.node_modules:
        node_modules_root = link_path(ctx.attr.node_modules.label, ctx.bin_dir.path)
    else:
        fail(
            "rules_vite %s: pass deps (per-package links, the slim " % ctx.label.name +
            "sandbox) or node_modules (the whole linked tree).",
        )

    staged = []
    for f in ctx.files.srcs:
        error = foreign_src_error(f.short_path, ctx.label.name)
        if error:
            fail(error)
        staged.append({"source": f.path, "destination": f.short_path})
    staged.extend(staged_injected_files(ctx))

    manifest = {
        "package": ctx.label.package,
        "config": ctx.file.config.short_path if ctx.attr.config else None,
        "package_links": package_links,
        "node_modules_root": node_modules_root,
        "files": staged,
    }
    if ctx.attr.config:
        if ctx.file.config.short_path.startswith("../"):
            fail(
                "rules_vite %s: config must live in the consuming repository " % ctx.label.name +
                "(got %s); generated configs from other repos are not stageable." % ctx.file.config.short_path,
            )
        manifest["files"].append({"source": ctx.file.config.path, "destination": ctx.file.config.short_path})
    manifest_file = ctx.actions.declare_file(ctx.label.name + "_manifest.json")
    ctx.actions.write(manifest_file, json.encode(manifest))

    out = ctx.actions.declare_directory(ctx.label.name + "/" + ctx.attr.out_dir)

    args = ctx.actions.args()
    args.add(ctx.file._driver.path)
    args.add(manifest_file.path)
    args.add(out.path)
    args.add(vite_entry)
    args.add_all(ctx.attr.args)

    ctx.actions.run(
        executable = node,
        arguments = [args],
        inputs = depset(
            [manifest_file, ctx.file._driver] +
            ([ctx.file.config] if ctx.attr.config else []) + ctx.files.srcs + ctx.files.injected_srcs,
            transitive = [
                dep[DefaultInfo].files
                for dep in ([ctx.attr.node_modules] if ctx.attr.node_modules else []) + list(ctx.attr.deps)
            ] + [ctx.attr.vite[DefaultInfo].files],
        ),
        outputs = [out],
        env = dict(ctx.attr.env),
        mnemonic = "ViteBuild",
        execution_requirements = {"block-network": "1"},
        progress_message = "ViteBuild %{label}",
    )

    return [DefaultInfo(files = depset([out]))]

_vite_build = rule(
    implementation = _vite_build_impl,
    attrs = {
        "vite_entry": attr.string(
            doc = "The vite CLI entry script, relative to the vite package link.",
            default = "bin/vite.js",
        ),
        "srcs": attr.label_list(
            doc = "Application sources, staged (workspace layout preserved).",
            allow_files = True,
        ),
        "injected_srcs": attr.label_list(
            doc = "Files staged into inject_dir inside the application " +
                  "(subdirectories preserved via inject_strip) for sharing one component set across " +
                  "many applications.",
            allow_files = True,
        ),
        "inject_dir": attr.string(
            doc = "Package-relative directory injected_srcs land in.",
        ),
        "inject_strip": attr.string(
            doc = "Workspace path prefix stripped from injected_srcs short paths " +
                  "so subdirectories are preserved in the staged tree.",
        ),
        "config": attr.label(
            doc = "Optional vite config file; passed explicitly via --config.",
            allow_single_file = True,
        ),
        "out_dir": attr.string(
            doc = "Directory declared as the action output, relative to the target.",
            default = "dist",
        ),
        "args": attr.string_list(
            doc = "Extra argv entries appended after the vite build flags.",
        ),
        "env": attr.string_dict(
            doc = "Extra environment variables for the action (e.g. VITE_* flags).",
        ),
        "node_modules": attr.label(
            doc = "The whole npm_link_all_packages tree; every package enters " +
                  "the sandbox. Prefer deps.",
        ),
        "deps": attr.label_list(
            doc = "Per-package node_modules links (for example the vite and react link targets of npm_link_all_packages). Each link carries its full dependency closure in the pnpm store, so the sandbox gets only what the app declares.",
        ),
        "vite": attr.label(
            doc = "The vite package link, used to locate the CLI entry script.",
            default = "//:node_modules/vite",
        ),
        "_driver": attr.label(
            doc = "The node driver that stages the app tree and runs vite.",
            default = Label("//private/tools:vite_driver.mjs"),
            allow_single_file = True,
        ),
    },
    toolchains = ["@rules_nodejs//nodejs:toolchain_type"],
)

def _default_vite_link(deps, node_modules):
    for dep in deps:
        if str(dep).endswith("node_modules/vite"):
            return dep
    if node_modules:
        return str(node_modules) + "/vite"
    return "//:node_modules/vite"

def vite_build(
        name,
        srcs = None,
        config = None,
        out_dir = "dist",
        args = [],
        env = {},
        data = [],
        deps = [],
        injected_srcs = [],
        inject_dir = "",
        inject_strip = "",
        node_modules = None,
        vite = None,
        vite_entry = "bin/vite.js",
        visibility = None,
        **kwargs):
    """Runs `vite build` as a sandboxed, shell-free Bazel action.

    The action's node driver stages sources, config and node_modules into
    an ephemeral temp directory, then runs vite with the project root
    pinned to the staged application. out_dir is the declared output (a
    TreeArtifact).

    Args:
        name: Target name. The bundle tree is the target's default output.
        srcs: Application sources. Defaults to a glob of the usual vite
            layout (src/**, public/**, index.html, *.json, *.config.*).
        config: Optional vite config file (label or package-relative path).
            Passed explicitly via `--config` and staged with the sources.
        out_dir: Directory declared as the action output. The default,
            "dist", is vite's own default.
        args: Extra argv entries appended after the vite build flags.
            A plain list; no shell interpolation happens anywhere.
        env: Extra environment variables for the action (e.g. VITE_* flags).
        data: Extra labels staged alongside the sources (merged inputs).
        injected_srcs: Files staged into inject_dir inside the application
            (subdirectories preserved via inject_strip) for many apps.
        inject_dir: Package-relative directory injected_srcs land in.
        inject_strip: Workspace path prefix stripped from injected_srcs so
            subdirectories are preserved.
        deps: Per-package node_modules links (for
            example [":node_modules/vite", ":node_modules/react"]). Each
            link target carries its full dependency closure in the pnpm
            store, so the action input is only what the app declares.
        node_modules: The whole npm_link_all_packages tree - every package
            enters every sandbox. The default when neither deps nor
            node_modules is given; pass explicitly only for nested
            workspace packages that link their own tree.
        vite: The vite package link; locates the CLI entry script.
            Defaults to the vite link in deps, else node_modules + "/vite"
            (so a nested importer uses its own vite), else
            "//:node_modules/vite".
        vite_entry: vite CLI entry script, relative to the vite package
            link; override only for exotic package manager layouts.
        visibility: Standard visibility (None = package default).
        **kwargs: Forwarded to the rule (tags, testonly, target_compatible_with).
    """
    if srcs == None:
        srcs = native.glob(["*.config.*", "*.json", "index.html", "public/**", "src/**"])
    error = vite_build_validation_error(name, out_dir, args, deps, node_modules)
    if error:
        fail(error)
    if not deps and not node_modules:
        node_modules = "//:node_modules"
    if vite == None:
        vite = _default_vite_link(deps, node_modules)
    if config and config not in srcs:
        srcs = list(srcs) + [config]

    _vite_build(
        name = name,
        vite = vite,
        vite_entry = vite_entry,
        srcs = srcs + list(data),
        config = config,
        out_dir = out_dir,
        args = args,
        env = env,
        node_modules = node_modules,
        deps = deps,
        injected_srcs = injected_srcs,
        inject_dir = inject_dir,
        inject_strip = inject_strip,
        visibility = visibility,
        **kwargs
    )
