# This package contains Rust protobuf runtime implementation built on top of the C++ backend.

load("@rules_rust//rust:defs.bzl", "rust_library", "rust_test")

rust_library(
    name = "cc",
    srcs = ["cc.rs"],
    visibility = ["//src/google/protobuf:__subpackages__"],
)

rust_test(
    name = "cc_test",
    crate = ":cc",
)
