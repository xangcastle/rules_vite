"""Unit tests for the path derivation helpers in private/helpers/node.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//private/helpers:node.bzl", "link_path", "link_runfiles_path")

def _fake_label(package, name):
    return Label("@@//{}:{}".format(package, name) if package else "@@//:{}".format(name))

def _label_helpers_test_impl(ctx):
    env = unittest.begin(ctx)

    root = _fake_label("", "node_modules")
    asserts.equals(env, "bin/node_modules", link_path(root, "bin"))
    asserts.equals(env, "_main/node_modules", link_runfiles_path(root, "_main"))

    nested = _fake_label("bazel/rbe/ui", "node_modules")
    asserts.equals(env, "bin/bazel/rbe/ui/node_modules", link_path(nested, "bin"))
    asserts.equals(env, "_main/bazel/rbe/ui/node_modules", link_runfiles_path(nested, "_main"))

    link = _fake_label("", "node_modules/vite")
    asserts.equals(env, "_main/node_modules/vite", link_runfiles_path(link, "_main"))

    scoped = _fake_label("", "node_modules/@vitejs/plugin-react")
    asserts.equals(env, "_main/node_modules/@vitejs/plugin-react", link_runfiles_path(scoped, "_main"))

    external = Label("@aspect_rules_js//tools:node_modules/vite")
    asserts.equals(env, "aspect_rules_js+/tools/node_modules/vite", link_runfiles_path(external, "_main"))

    return unittest.end(env)

_label_helpers_test = unittest.make(_label_helpers_test_impl)

def node_helpers_test_suite():
    unittest.suite(
        "node_helpers_test_suite",
        _label_helpers_test,
    )
