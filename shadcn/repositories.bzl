"""Repository rules for shadcn component downloads.

shadcn_components_repo downloads registry JSON pinned by sha256, extracts
the component source files from files[].content into a tree that mirrors
the registry layout (ui/, lib/, hooks/), rewrites registry-internal
imports to relative paths, and exposes the tree both as one filegroup and
as per-component js_library targets. shadcn_cli_repo fetches the shadcn
CLI npm tarball.
"""

def _lock_urls(entry, name):
    urls = entry.get("urls")
    if urls:
        return urls
    if entry.get("url"):
        return [entry["url"]]
    fail("shadcn lock entry %s needs url or urls" % name)

def _registry_rel(path):
    """Strips the leading registry/<style>/ segments from a registry file path."""
    parts = path.split("/")
    if len(parts) > 2 and parts[0] == "registry":
        return "/".join(parts[2:])
    return path

def _dirname(p):
    """The directory portion of a slash path, or "" at the root."""
    idx = p.rfind("/")
    return p[:idx] if idx >= 0 else ""

def _rewrite_registry_imports(content, from_dir):
    """Rewrites "@/registry/<style>/<dir>/<name>" import specifiers to relative paths.

    Args:
      content: the component source.
      from_dir: the directory (tree-relative, no trailing slash) the file
        lives in; "" for the tree root.

    Returns:
      The source with registry-internal specifiers replaced by relative
      ones that resolve inside the extracted tree.
    """
    token = "\"@/registry/"
    parts = content.split(token)
    out = [parts[0]]
    for part in parts[1:]:
        end = part.find("\"")
        if end < 0:
            out.append(part)
            continue
        spec = part[:end]
        parts_of_spec = spec.split("/")
        target_dir = "/".join(parts_of_spec[1:-1])
        name = parts_of_spec[-1]
        if target_dir == from_dir:
            rel = "./" + name
        elif from_dir == "":
            rel = target_dir + "/" + name
        else:
            rel = "../" * (from_dir.count("/") + 1) + target_dir + "/" + name
        out.append("\"" + rel + "\"" + part[end + 1:])
    return "".join(out)

def _extract(rctx, name, entry, seen, owners):
    """Downloads a component JSON and extracts its files into the tree.

    Args:
      rctx: the repository context.
      name: the component name in the lock.
      entry: the lock entry (url/urls + sha256).
      seen: mutable set of already-extracted component names.
      owners: mutable dict of tree path -> component name, for collision
        detection.

    Returns:
      The list of registry dependencies declared by the component.
    """
    if name in seen:
        return []
    seen[name] = True

    urls = _lock_urls(entry, name)
    raw = rctx.download(
        url = urls,
        sha256 = entry["sha256"],
        output = "_raw/%s.json" % name,
    )
    if not raw.success:
        fail("shadcn: failed to download %s from %s" % (name, urls[0]))

    spec = json.decode(rctx.read("_raw/%s.json" % name))

    for f in spec.get("files", []):
        content = f.get("content", "")
        if not content:
            continue
        rel = _registry_rel(f["path"])
        if rel in owners and owners[rel] != name:
            fail(
                "shadcn: %s and %s both provide %s; the lock entries overlap." % (owners[rel], name, rel),
            )
        owners[rel] = name
        rctx.file(
            "components/%s" % rel,
            _rewrite_registry_imports(content, _dirname(rel)),
            executable = False,
        )

    return spec.get("registryDependencies", [])

def _process_component(rctx, name, components, seen, owners):
    """Extracts one component and, transitively, its registry dependencies."""
    if name in seen:
        return
    entry = components.get(name)
    if not entry:
        fail(
            "shadcn: %s is required by another component but missing " % name +
            "from the lock; add its url and sha256.",
        )
    if not entry.get("sha256"):
        fail("shadcn lock entry %s needs sha256" % name)
    pending = list(_extract(rctx, name, entry, seen, owners))
    for _ in range(64):
        if not pending:
            return
        current = pending.pop(0)
        if current in seen:
            continue
        current_entry = components.get(current)
        if not current_entry:
            fail(
                "shadcn: %s is required by another component but missing " % current +
                "from the lock; add its url and sha256.",
            )
        pending.extend(_extract(rctx, current, current_entry, seen, owners))

def _shadcn_components_repo_impl(rctx):
    lock = json.decode(rctx.read(rctx.attr.lock))
    components = lock.get("components", {})

    seen = {}
    owners = {}
    for name in sorted(components.keys()):
        _process_component(rctx, name, components, seen, owners)

    files_by_target = {}
    for rel, owner in owners.items():
        files_by_target.setdefault(owner, []).append(rel)

    build_parts = [
        "load(\"@rules_vite//private/helpers:js_library.bzl\", \"js_library\")",
        "exports_files(glob([\"components/**\"]))",
        "exports_files([\"BUILD.bazel\"], [\"//visibility:public\"])",
        "filegroup(name = \"all_files\", srcs = glob([\"components/**\"]), visibility = [\"//visibility:public\"])",
    ]
    for name in sorted(files_by_target.keys()):
        srcs = ",".join(["\"components/%s\"" % rel for rel in sorted(files_by_target[name])])
        build_parts.append(
            "js_library(name = \"%s\", srcs = [%s], visibility = [\"//visibility:public\"])" % (name, srcs),
        )

    rctx.file("BUILD.bazel", "\n".join(build_parts) + "\n")
    rctx.delete("_raw")

shadcn_components_repo = repository_rule(
    implementation = _shadcn_components_repo_impl,
    attrs = {
        "lock": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
    },
)

def _shadcn_cli_repo_impl(rctx):
    if not rctx.attr.sha256:
        fail("shadcn cli requires the npm tarball sha256; pin it in the tag")
    rctx.download_and_extract(
        url = "https://registry.npmjs.org/shadcn/-/shadcn-%s.tgz" % rctx.attr.version,
        sha256 = rctx.attr.sha256,
    )
    rctx.file(
        "BUILD.bazel",
        "exports_files(glob([\"package/**\"]))\n" +
        "filegroup(name = \"cli_files\", srcs = glob([\"package/**\"]), visibility = [\"//visibility:public\"])\n",
    )

shadcn_cli_repo = repository_rule(
    implementation = _shadcn_cli_repo_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "sha256": attr.string(mandatory = True),
    },
)
