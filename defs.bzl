"""Public API for rules_vite: Vite build, Vitest test, dev server, and node
CLI rules for Bazel with bzlmod.

vite is not vendored by this ruleset. The consumer's `npm_translate_lock`
repository provides it, so plugin peer-dependency versions always match the
application (vite 5/6/7 may coexist in one build graph).

Label arguments are plain strings resolved against the consuming package.
The default `node_modules` label follows the standard rules_js convention
(`npm_link_all_packages` named "node_modules" at the workspace root).
"""

load("//private:build.bzl", _vite_build = "vite_build")
load("//private:cli.bzl", _node_cli = "node_cli")
load("//private:run.bzl", _vite_run = "vite_run")
load("//private:test.bzl", _vitest_test = "vitest_test")

vite_build = _vite_build
node_cli = _node_cli
vite_run = _vite_run
vitest_test = _vitest_test
