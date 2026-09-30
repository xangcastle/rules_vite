"""Writes the sorted relative paths of a target's files as a snapshot."""

def _repo_tree_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    paths = []
    for f in ctx.attr.srcs[DefaultInfo].files.to_list():
        p = f.short_path
        if p.startswith("../"):
            p = p.split("/", 2)[2]
        paths.append(p)
    paths = sorted(paths)
    content = ""
    for p in paths:
        content += p + "\n"
    ctx.actions.write(out, content)
    return [DefaultInfo(files = depset([out]))]

repo_tree = rule(
    implementation = _repo_tree_impl,
    attrs = {
        "srcs": attr.label(mandatory = True),
        "out": attr.string(mandatory = True),
    },
)
