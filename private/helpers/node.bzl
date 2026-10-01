"""Path derivation for node_modules link targets.

All paths are computed from the label's workspace_root, package, and name.
No depset is materialized for path derivation.
"""

def _execroot_prefix(label):
    """The workspace+package prefix for execroot-relative paths."""
    parts = [p for p in [label.workspace_root, label.package] if p]
    return "/".join(parts) + "/" if parts else ""

def _runfiles_prefix(label):
    """The workspace+package prefix for runfiles-root-relative paths.

    Runfiles address external repositories by canonical name directly
    (no external/ segment), matching File.short_path's ../<canonical>/
    form.
    """
    workspace_root = label.workspace_root
    if workspace_root.startswith("external/"):
        workspace_root = workspace_root[len("external/"):]
    parts = [p for p in [workspace_root, label.package] if p]
    return "/".join(parts) + "/" if parts else ""

def link_path(label, bin_dir_path):
    """The execroot-relative path of any node_modules link target."""
    return bin_dir_path + "/" + _execroot_prefix(label) + label.name

def link_rel(label):
    """The runfiles-root-relative path of any node_modules link target."""
    return _runfiles_prefix(label) + label.name

def runfiles_node_modules_spec(node_modules, deps, target_name):
    """Builds the node_modules spec string passed to run/test drivers.

    Args:
      node_modules: the whole-tree label, or None.
      deps: per-package link labels, possibly empty.
      target_name: the consuming target, for error messages.

    Returns:
      "node_modules:<rel>" for the whole tree, "links:<rel>,<rel>" for
      per-package links, or None when neither is given.
    """
    if node_modules and deps:
        fail("rules_vite %s: pass either node_modules or deps, not both." % target_name)
    if node_modules:
        return "node_modules:" + link_rel(node_modules.label)
    if deps:
        link_relative_paths = []
        for dep in deps:
            if dep.label.name == "node_modules":
                fail(
                    "rules_vite %s: deps expects per-package links like " % target_name +
                    "\":node_modules/<package>\"; got the whole tree %s - " % str(dep.label) +
                    "pass it as node_modules instead.",
                )
            link_relative_paths.append(link_rel(dep.label))
        return "links:" + ",".join(link_relative_paths)
    return None

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

def _common_directory_prefix(prefix, directory):
    """Shrinks prefix until directory falls inside it."""
    for _ in range(32):
        if not prefix or (directory + "/").startswith(prefix + "/"):
            return prefix
        idx = prefix.rfind("/")
        prefix = prefix[:idx] if idx >= 0 else ""
    return prefix

def runfiles_tree_root(files):
    """The deepest common directory of a set of files, runfiles-root-relative.

    Args:
      files: a depset of Files, enumerated once to compute the prefix.

    Returns:
      The common directory prefix ("" for runfiles-root-scoped files).
    """
    prefix = None
    for f in files.to_list():
        short_path = f.short_path
        if short_path.startswith("../"):
            short_path = short_path[3:]
        idx = short_path.rfind("/")
        directory = short_path[:idx] if idx >= 0 else ""
        prefix = directory if prefix == None else _common_directory_prefix(prefix, directory)
        if not prefix:
            break
    return prefix or ""

def strip_injected_path(short_path, strip):
    """Computes the inject-relative destination of an injected file.

    Args:
      short_path: the file's repository-relative path (external prefix
        already stripped).
      strip: the inject_strip prefix, or "" for basename-only.

    Returns:
      A (rel, error) tuple; exactly one of the two is None.
    """
    if strip:
        if not short_path.startswith(strip):
            return (
                None,
                "inject_srcs %s doesn't start with inject_strip %r - fix the strip or the label." % (short_path, strip),
            )
        return (short_path[len(strip):], None)
    return (short_path.rsplit("/", 1)[-1], None)

def staged_injected_files(ctx):
    """Returns manifest entries for injected_srcs with strip validation.

    Each entry carries source (execroot-relative), runfiles_path
    (runfiles-root-relative, for run/test drivers) and destination.

    Args:
      ctx: The rule context (must have injected_srcs, inject_dir,
            and inject_strip attrs).

    Returns:
        A list of {"source", "runfiles_path", "destination"} manifest entries.
    """
    entries = []
    for f in ctx.files.injected_srcs:
        short_path = f.short_path
        runfiles_path = short_path[3:] if short_path.startswith("../") else ctx.workspace_name + "/" + short_path
        if short_path.startswith("../"):
            parts = short_path.split("/", 2)
            if len(parts) > 2:
                short_path = parts[2]
        rel, err = strip_injected_path(short_path, ctx.attr.inject_strip)
        if err:
            fail("rules_vite %s: %s" % (ctx.label.name, err))
        prefix = ctx.label.package + "/" + ctx.attr.inject_dir + "/" if ctx.attr.inject_dir else ""
        entries.append({
            "source": f.path,
            "runfiles_path": runfiles_path,
            "destination": prefix + rel,
        })
    if len(entries) > 1 and not ctx.attr.inject_strip:
        fail(
            "rules_vite %s: multiple injected_srcs need inject_strip to preserve " % ctx.label.name +
            "subdirectories; without it every file flattens to its basename and " +
            "same-named files overwrite each other.",
        )
    return entries
