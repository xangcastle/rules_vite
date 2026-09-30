"""Unit tests for the path derivation helpers in private/helpers/node.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//private/helpers:node.bzl", "link_path", "link_rel")

def _fake_label(repo, package, name):
    return Label("@@{}//{}:{}".format(repo, package, name))

def _label_helpers_test_impl(ctx):
    env = unittest.begin(ctx)

    # Root-package npm_link_all_packages links at bin/node_modules.
    root = _fake_label("rules_vite", "", "node_modules")
    asserts.equals(env, "bin/node_modules", link_path(root, "bin"))
    asserts.equals(env, "node_modules", link_rel(root))

    # Nested workspace packages link inside their own package dir.
    nested = _fake_label("rules_vite", "bazel/rbe/ui", "node_modules")
    asserts.equals(env, "bin/bazel/rbe/ui/node_modules", link_path(nested, "bin"))
    asserts.equals(env, "bazel/rbe/ui/node_modules", link_rel(nested))

    # Per-package links keep the node_modules/ prefix for runfiles paths.
    link = _fake_label("rules_vite", "", "node_modules/vite")
    asserts.equals(env, "node_modules/vite", link_rel(link))

    # Scoped packages keep their slash in the name part.
    scoped = _fake_label("rules_vite", "", "node_modules/@vitejs/plugin-react")
    asserts.equals(env, "node_modules/@vitejs/plugin-react", link_rel(scoped))

    return unittest.end(env)

_label_helpers_test = unittest.make(_label_helpers_test_impl)

def node_helpers_test_suite():
    unittest.suite(
        "node_helpers_test_suite",
        _label_helpers_test,
    )
