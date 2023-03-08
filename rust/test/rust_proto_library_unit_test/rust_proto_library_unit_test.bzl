"""This module contains unit tests for rust_proto_library and its aspect."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(":defs.bzl", "ActionsInfo", "attach_aspect")
load("//rust:defs.bzl", "rust_proto_library")
load("@rules_rust//rust:defs.bzl", "rust_binary")

def _find_action_with_mnemonic(actions, mnemonic):
    action = [a for a in actions if a.mnemonic == mnemonic]
    if not action:
        fail("Couldn't find action with mnemonic {} among {}".format(mnemonic, actions))
    return action[0]

def _find_rust_lib_input(inputs, target_name):
    inputs = inputs.to_list()
    input = [i for i in inputs if i.basename.startswith("lib" + target_name) and
                                  (i.basename.endswith(".rlib") or i.basename.endswith(".rmeta"))]
    if not input:
        fail("Couldn't find lib{}-<hash>.rlib or lib{}-<hash>.rmeta among {}".format(
            target_name,
            target_name,
            [i.basename for i in inputs],
        ))
    return input[0]

def _find_cc_object_input(inputs, target_name):
    inputs = inputs.to_list()
    input = [i for i in inputs if (
        i.basename.startswith(target_name) or i.basename.startswith("lib" + target_name)
    ) and (
        i.basename.endswith(".o") or i.basename.endswith(".a") or i.basename.endswith(".lib")
    )]
    if not input:
        fail("Couldn't find object or lib with {} in its name among {}".format(
            target_name,
            [i.basename for i in inputs],
        ))
    return input[0]

####################################################################################################

def _rust_compilation_action_has_runtime_as_input_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actions = target_under_test[ActionsInfo].actions
    rustc_action = _find_action_with_mnemonic(actions, "Rustc")
    _find_rust_lib_input(rustc_action.inputs, "protobuf")
    asserts.true(env, rustc_action.outputs.to_list()[0].path.endswith(".rlib"))

    return analysistest.end(env)

rust_compilation_action_has_runtime_as_input_test = analysistest.make(
    _rust_compilation_action_has_runtime_as_input_test_impl,
)

def _test_rust_compilation_action_has_runtime_as_input():
    native.proto_library(name = "some_proto", srcs = ["some_proto.proto"])
    attach_aspect(name = "some_proto_with_aspect", dep = ":some_proto")

    rust_compilation_action_has_runtime_as_input_test(
        name = "rust_compilation_action_has_runtime_as_input_test",
        target_under_test = ":some_proto_with_aspect",
        # TODO(b/270274576): Enable testing on arm once we have a Rust Arm toolchain.
        tags = ["not_build:arm"],
    )

####################################################################################################

def _rust_compilation_action_has_deps_as_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actions = target_under_test[ActionsInfo].actions
    rustc_action = _find_action_with_mnemonic(actions, "Rustc")
    _find_rust_lib_input(rustc_action.inputs, "parent")

    return analysistest.end(env)

rust_compilation_action_has_deps_as_input_test = analysistest.make(
    _rust_compilation_action_has_deps_as_inputs_test_impl,
)

def _test_rust_compilation_action_has_deps_as_input():
    attach_aspect(name = "child_proto_with_aspect", dep = ":child_proto")

    rust_compilation_action_has_deps_as_input_test(
        name = "rust_compilation_action_has_deps_as_input_test",
        target_under_test = ":child_proto_with_aspect",
        # TODO(b/270274576): Enable testing on arm once we have a Rust Arm toolchain.
        tags = ["not_build:arm"],
    )

####################################################################################################

def _final_linking_has_upb_gencode_objects_as_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actions = target_under_test.actions
    rustc_action = _find_action_with_mnemonic(actions, "Rustc")
    _find_cc_object_input(rustc_action.inputs, "parent")
    _find_cc_object_input(rustc_action.inputs, "child")

    return analysistest.end(env)

final_linking_has_upb_gencode_objects_as_inputs_test = analysistest.make(
    _final_linking_has_upb_gencode_objects_as_inputs_test_impl,
)

def _test_final_linking_has_upb_gencode_objects_as_inputs():
    rust_proto_library(name = "child_rust_proto", deps = [":child_proto"], tags = ["manual"])
    rust_binary(
        name = "binary_using_rust_proto",
        srcs = ["empty.rs"],
        deps = [":child_rust_proto"],
        tags = ["manual"],
    )

    final_linking_has_upb_gencode_objects_as_inputs_test(
        name = "final_linking_has_upb_gencode_objects_as_inputs_test",
        target_under_test = ":binary_using_rust_proto",
        # TODO(b/270274576): Enable testing on arm once we have a Rust Arm toolchain.
        tags = ["not_build:arm"],
    )

####################################################################################################

def rust_proto_library_unit_test(name):
    """Sets up rust_proto_library_unit_test test suite.

    Args:
      name: name of the test suite"""
    native.proto_library(name = "parent_proto", srcs = ["parent.proto"])
    native.proto_library(name = "child_proto", srcs = ["child.proto"], deps = [":parent_proto"])

    _test_rust_compilation_action_has_runtime_as_input()
    _test_rust_compilation_action_has_deps_as_input()
    _test_final_linking_has_upb_gencode_objects_as_inputs()

    native.test_suite(
        name = name,
        tests = [
            ":rust_compilation_action_has_runtime_as_input_test",
            ":rust_compilation_action_has_deps_as_input_test",
            ":final_linking_has_upb_gencode_objects_as_inputs_test",
        ],
    )
