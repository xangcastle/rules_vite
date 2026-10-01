"""Analysis and unit tests for vite_build wiring and fail() paths.

The ViteBuild action's block-network execution requirement is not
assertable here: skylib 1.9.0's analysistest Action introspection exposes
no execution_requirements field. The requirement itself is exercised by
every sandboxed e2e build.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//private:validation.bzl", "vite_build_validation_error")
load("//private/helpers:node.bzl", "foreign_src_error", "overlay_root_error", "runfiles_node_modules_spec", "strip_injected_path")

def _subject_ok_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    files = target[DefaultInfo].files.to_list()
    asserts.true(env, len(files) >= 1, "the target must have an output")
    asserts.true(
        env,
        files[0].is_directory,
        "the default output must be the out_dir TreeArtifact",
    )
    actions = analysistest.target_actions(env)
    build_actions = [a for a in actions if a.mnemonic == "ViteBuild"]
    asserts.equals(env, 1, len(build_actions), "ViteBuild action count")
    argv = build_actions[0].argv
    asserts.true(
        env,
        len([a for a in argv if "vite_driver.mjs" in a]) == 1,
        "the action must run node on the vite driver",
    )
    asserts.true(
        env,
        len([a for a in argv if "subject_ok_manifest.json" in a]) == 1,
        "the action must receive the staged manifest",
    )
    return analysistest.end(env)

def _subject_strip_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "inject_strip")
    return analysistest.end(env)

_subject_ok_test = analysistest.make(_subject_ok_impl)

_subject_strip_test = analysistest.make(
    _subject_strip_impl,
    expect_failure = True,
)

def _validation_impl(ctx):
    env = unittest.begin(ctx)

    asserts.true(
        env,
        vite_build_validation_error("app", "dist", [], [], None) == None,
        "valid deps mode",
    )
    asserts.true(
        env,
        vite_build_validation_error("app", "dist", ["--x"], [], "//:node_modules") == None,
        "valid tree mode",
    )
    asserts.true(
        env,
        vite_build_validation_error("app", "/abs", [], [], None) != None,
        "absolute out_dir must fail",
    )
    asserts.true(
        env,
        vite_build_validation_error("app", "", [], [], None) != None,
        "empty out_dir must fail",
    )
    asserts.true(
        env,
        vite_build_validation_error("app", "dist", "--host", [], None) != None,
        "string args must fail",
    )
    asserts.true(
        env,
        vite_build_validation_error("app", "dist", [], ["//:x"], "//:node_modules") != None,
        "deps plus node_modules must fail",
    )

    rel, err = strip_injected_path("components/src/ui/button.tsx", "components/src/")
    asserts.equals(env, "ui/button.tsx", rel, "strip keeps subdirectories")
    asserts.true(env, err == None, "matching strip has no error")

    rel, err = strip_injected_path("components/src/ui/button.tsx", "")
    asserts.equals(env, "button.tsx", rel, "empty strip falls back to basename")
    asserts.true(env, err == None, "basename strip has no error")

    rel, err = strip_injected_path("components/src/ui/button.tsx", "wrong/")
    asserts.true(env, rel == None, "mismatching strip yields no path")
    asserts.true(env, err != None, "mismatching strip must error")

    asserts.true(env, foreign_src_error("apps/web/src/main.tsx", "t") == None, "own-repo src is stageable")
    asserts.true(env, foreign_src_error("../shadcn+/components/ui/button.tsx", "t") != None, "external src must fail")

    asserts.true(env, overlay_root_error("rules_vite++shadcn+shadcn/components", "t") == None, "rooted overlay is usable")
    asserts.true(env, overlay_root_error("", "t") != None, "empty overlay root must fail")
    asserts.true(env, overlay_root_error("_main", "t") != None, "bare repository overlay root must fail")

    return unittest.end(env)

_validation_test = unittest.make(_validation_impl)

def _nm_spec_impl(ctx):
    env = unittest.begin(ctx)

    nm = struct(label = Label("//:node_modules"))
    vite = struct(label = Label("//:node_modules/vite"))
    asserts.equals(env, "node_modules:node_modules", runfiles_node_modules_spec(nm, [], "t"), "tree spec")
    asserts.equals(env, "links:node_modules/vite", runfiles_node_modules_spec(None, [vite], "t"), "links spec")
    asserts.true(env, runfiles_node_modules_spec(None, [], "t") == None, "neither yields None")

    return unittest.end(env)

_nm_spec_test = unittest.make(_nm_spec_impl)

def rule_validation_test_suite(name = "rule_validation_tests"):
    _subject_ok_test(
        name = "subject_ok_test",
        target_under_test = ":subject_ok",
    )
    _subject_strip_test(
        name = "subject_strip_test",
        target_under_test = ":subject_strip",
    )
    _validation_test(name = name + "_validation")
    _nm_spec_test(name = name + "_nm_spec")
