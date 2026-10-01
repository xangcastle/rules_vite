"""Pure validation helpers for the vite_build macro.

Each function returns None when valid and a failure message string
otherwise; the macros call fail() with that message. Keeping the checks
pure lets the unit suites cover every fail() path.
"""

def vite_build_validation_error(name, out_dir, args, deps, node_modules):
    """Validates the vite_build macro arguments.

    Args:
      name: target name, for messages.
      out_dir: the declared output directory.
      args: extra argv entries.
      deps: per-package node_modules links.
      node_modules: the whole linked tree.

    Returns:
      None when valid, else the failure message.
    """
    if not out_dir or out_dir.startswith("/"):
        return "vite_build(%s): out_dir must be a package-relative directory, got %r" % (name, out_dir)
    if type(args) != "list" or not all([type(a) == "string" for a in args]):
        return "vite_build(%s): args must be a list of strings (argv), got %r" % (name, args)
    if deps and node_modules:
        return "vite_build(%s): pass either deps or node_modules, not both" % name
    return None
