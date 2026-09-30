"""Path derivation for node_modules link targets.

All paths are computed from the label's workspace_root, package, and name.
No depset is materialized for path derivation.
"""

def _prefix(label):
    """The workspace+package prefix shared by execroot and runfiles paths."""
    parts = [p for p in [label.workspace_root, label.package] if p]
    return "/".join(parts) + "/" if parts else ""

def link_path(label, bin_dir_path):
    """The execroot-relative path of any node_modules link target."""
    return bin_dir_path + "/" + _prefix(label) + label.name

def link_rel(label):
    """The cwd/runfiles-relative path of any node_modules link target."""
    return _prefix(label) + label.name

def link_package_name(label):
    """The package name stripped of the node_modules/ prefix."""
    if not label.name.startswith("node_modules/"):
        fail(
            "rules_vite: expected a node_modules link label like " +
            "\":node_modules/<package>\", got %s" % str(label),
        )
    return label.name[len("node_modules/"):]

def validate_link_label(label, target_name):
    """Fails at analysis time if the label doesn't match the convention."""
    if not label.name.startswith("node_modules") and label.name != "node_modules":
        fail(
            "rules_vite %s: expected a node_modules link label like " % target_name +
            "\":node_modules\" or \":node_modules/<package>\", got %s" % str(label),
        )

def staged_injected_files(ctx):
    """Returns manifest entries for injected_srcs with strip validation.

    Fails loudly when inject_strip doesn't match: a silent basename
    fallback lets two index.tsx from different subdirectories collide.

    Args:
        ctx: The rule context (must have injected_srcs, inject_dir,
            and inject_strip attrs).

    Returns:
        A list of {"src": path, "dst": path} manifest entries.
    """
    entries = []
    for f in ctx.files.injected_srcs:
        sp = f.short_path
        if sp.startswith("../"):
            parts = sp.split("/", 2)
            if len(parts) > 2:
                sp = parts[2]
        if ctx.attr.inject_strip:
            strip = ctx.attr.inject_strip
            if not sp.startswith(strip):
                fail(
                    "rules_vite %s: inject_srcs %s doesn't start with " % (ctx.label.name, sp) +
                    "inject_strip %r - fix the strip or the label." % strip,
                )
            rel = sp[len(strip):]
        else:
            rel = f.basename
        prefix = ctx.label.package + "/" + ctx.attr.inject_dir + "/" if ctx.attr.inject_dir else ""
        entries.append({"src": f.path, "dst": prefix + rel})
    return entries
