"""Module extension for lock-pinned shadcn component downloads.

    chadcn = use_extension("@rules_vite//chadcn:extensions.bzl", "chadcn")
    chadcn.components(name = "shadcn", lock = "//:shadcn-lock.json")
    use_repo(chadcn, "shadcn")

Each locked component is exposed as a js_library (`@shadcn//:<name>`).
Components are pinned by sha256 in the lock file. For a runnable CLI,
use node_cli with the shadcn npm package from the consumer's lock.
"""

load("@rules_vite//chadcn:repositories.bzl", "chadcn_cli_repo", "chadcn_components_repo")

def _chadcn_module_impl(module_ctx):
    registrations = {}
    for mod in module_ctx.modules:
        for tag in mod.tags.components:
            if tag.name in registrations:
                fail("chadcn.components: duplicate name %s" % tag.name)
            if not mod.is_root and tag.name in ["shadcn", "chadcn_cli"]:
                fail(
                    "chadcn.components: non-root module cannot claim reserved name %s" % tag.name,
                )
            registrations[tag.name] = None
            chadcn_components_repo(
                name = tag.name,
                lock = tag.lock,
            )
        if mod.tags.cli and mod.is_root:
            if len(mod.tags.cli) > 1:
                fail("chadcn.cli: only one CLI registration allowed")
            chadcn_cli_repo(
                name = "chadcn_cli",
                version = mod.tags.cli[0].version,
                sha256 = mod.tags.cli[0].sha256,
            )
    if module_ctx.root_module_has_non_dev_dependency:
        return module_ctx.extension_metadata(
            root_module_direct_deps = "all",
            root_module_direct_dev_deps = [],
            reproducible = True,
        )
    return module_ctx.extension_metadata(
        root_module_direct_deps = [],
        root_module_direct_dev_deps = sorted(registrations.keys()) if not module_ctx.root_module_has_non_dev_dependency else [],
        reproducible = True,
    )

_components_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "lock": attr.label(mandatory = True),
    },
)

_cli_tag = tag_class(
    attrs = {
        "version": attr.string(mandatory = True),
        "sha256": attr.string(mandatory = True),
    },
)

chadcn = module_extension(
    implementation = _chadcn_module_impl,
    tag_classes = {
        "components": _components_tag,
        "cli": _cli_tag,
    },
)
