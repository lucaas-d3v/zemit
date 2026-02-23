const std = @import("std");

// configures the build graph, dependencies, and compilation artifacts for zemit
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip_opt = b.option(bool, "strip", "Strip debug symbols") orelse false;

    // executable definition
    const exe = b.addExecutable(.{
        .name = "zemit",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // binary size and performance optimizations
    exe.root_module.strip = strip_opt;
    exe.link_gc_sections = true;
    exe.link_function_sections = true;
    exe.link_data_sections = true;

    // external dependencies
    const toml_dep = b.dependency("zig-toml", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("toml", toml_dep.module("zig-toml"));

    // build-time constants injection
    const opts = b.addOptions();
    opts.addOption([]const u8, "zemit_version", "0.2.3");
    exe.root_module.addImport("build_options", opts.createModule());

    // installation
    b.installArtifact(exe);
}
