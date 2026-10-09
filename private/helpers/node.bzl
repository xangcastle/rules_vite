"""Path derivation for node_modules link targets.

All paths are computed from the label's workspace_root, package, and name.
No depset is materialized for path derivation.
"""

def _execroot_prefix(label):
    """The workspace+package prefix for execroot-relative paths."""
    parts = [p for p in [label.workspace_root, label.package] if p]
    return "/".join(parts) + "/" if parts else ""

def _runfiles_prefix(label, workspace_name):
    """The repository+package prefix for runfiles-root-relative paths.

    Runfiles address external repositories by canonical name (no external/
    segment) and the main repository by workspace_name.
    """
    repository = label.workspace_root
    if repository.startswith("external/"):
        repository = repository[len("external/"):]
    parts = [p for p in [repository or workspace_name, label.package] if p]
    return "/".join(parts) + "/"

def link_path(label, bin_dir_path):
    """The execroot-relative path of any node_modules link target."""
    return bin_dir_path + "/" + _execroot_prefix(label) + label.name

def link_runfiles_path(label, workspace_name):
    """The runfiles-root-relative path of any node_modules link target."""
    return _runfiles_prefix(label, workspace_name) + label.name

def external_link_error(label, target_name):
    """Rejects node_modules links from other repositories for vite_run.

    The dev server links node_modules at the link's own path inside the
    workspace; a link from another repository has no such path.

    Args:
      label: the node_modules or per-package link label.
      target_name: the consuming target, for the message.

    Returns:
      None when the link belongs to the main repository, else the failure
      message.
    """
    if label.workspace_root:
        return (
            "rules_vite %s: vite_run links node_modules into the workspace, " % target_name +
            "so %s from another repository cannot be linked; " % str(label) +
            "link the packages with npm_link_all_packages in this repository."
        )
    return None

def runfiles_node_modules_spec(node_modules, deps, workspace_name, target_name):
    """Builds the node_modules spec string passed to run/test drivers.

    Args:
      node_modules: the whole-tree label, or None.
      deps: per-package link labels, possibly empty.
      workspace_name: the main repository's runfiles directory name.
      target_name: the consuming target, for error messages.

    Returns:
      "node_modules:<path>" for the whole tree, "links:<path>,<path>" for
      per-package links (runfiles-root-relative), or None when neither is
      given.
    """
    if node_modules and deps:
        fail("rules_vite %s: pass either node_modules or deps, not both." % target_name)
    if node_modules:
        return "node_modules:" + link_runfiles_path(node_modules.label, workspace_name)
    if deps:
        link_runfiles_paths = []
        for dep in deps:
            if dep.label.name == "node_modules":
                fail(
                    "rules_vite %s: deps expects per-package links like " % target_name +
                    "\":node_modules/<package>\"; got the whole tree %s - " % str(dep.label) +
                    "pass it as node_modules instead.",
                )
            link_runfiles_paths.append(link_runfiles_path(dep.label, workspace_name))
        return "links:" + ",".join(link_runfiles_paths)
    return None

def link_package_name(label):
    """The package name stripped of the node_modules/ prefix."""
    if not label.name.startswith("node_modules/"):
        fail(
            "rules_vite: expected a node_modules link label like " +
            "\":node_modules/<package>\", got %s" % str(label),
        )
    return label.name[len("node_modules/"):]

def package_entry_path(node_modules_label, dep_labels, package_name, entry, workspace_name, target_name):
    """The runfiles path of a script inside one linked npm package.

    Derived from the same node_modules the target links, so a nested pnpm
    importer (node_modules linked in a sub-package) resolves its own vite or
    vitest instead of the workspace root's.

    Args:
      node_modules_label: the whole-tree link label, or None in deps mode.
      dep_labels: per-package link labels (deps mode).
      package_name: npm package holding the script, e.g. "vitest".
      entry: path of the script inside that package, e.g. "vitest.mjs".
      workspace_name: the main repository's runfiles directory name.
      target_name: the consuming target, for the error message.

    Returns:
      The runfiles-root-relative path of the script.
    """
    if node_modules_label:
        return link_runfiles_path(node_modules_label, workspace_name) + "/" + package_name + "/" + entry
    for label in dep_labels:
        if label.name == "node_modules/" + package_name:
            return link_runfiles_path(label, workspace_name) + "/" + entry
    fail(
        "rules_vite %s: deps must include the %s link " % (target_name, package_name) +
        "(\":node_modules/%s\"), or pass node_modules instead." % package_name,
    )

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

def runfiles_tree_root(files, workspace_name):
    """The deepest common directory of a set of files, runfiles-root-relative.

    Args:
      files: a depset of Files, enumerated once to compute the prefix.
      workspace_name: the main repository's runfiles directory name.

    Returns:
      The common directory prefix ("" when the files span repositories).
    """
    prefix = None
    for f in files.to_list():
        runfiles_path = f.short_path[3:] if f.short_path.startswith("../") else workspace_name + "/" + f.short_path
        idx = runfiles_path.rfind("/")
        directory = runfiles_path[:idx]
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

def foreign_src_error(short_path, target_name):
    """Rejects srcs from other repositories before they reach the stage.

    The stage mirrors the consuming repository's layout; an external file's
    short_path (../<repo>/...) would resolve outside the stage directory.
    External sources belong in injected_srcs, which re-roots them.

    Args:
      short_path: the src file's short_path.
      target_name: the consuming target, for the message.

    Returns:
      None when stageable, else the failure message.
    """
    if short_path.startswith("../"):
        return (
            "rules_vite %s: src %s comes from another repository; srcs must " % (target_name, short_path) +
            "belong to the consuming repository. Pass it through injected_srcs " +
            "(with inject_dir/inject_strip) instead."
        )
    return None

def overlay_root_error(root, target_name):
    """Rejects shared_srcs that share no common runfiles directory.

    An empty root, or a bare repository directory such as "_main", would make
    the dev server mirror the whole runfiles tree of that scope (the linked
    node_modules included) into the workspace.

    Args:
      root: the value computed by runfiles_tree_root.
      target_name: the consuming target, for the message.

    Returns:
      None when usable, else the failure message.
    """
    if not root or "/" not in root:
        return (
            "rules_vite %s: shared_srcs have no common directory below a " % target_name +
            "repository root (got %r); pass one filegroup rooted at the shared component tree." % root
        )
    return None

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
