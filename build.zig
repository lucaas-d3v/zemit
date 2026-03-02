const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    const is_debug = optimize == .Debug;
    const is_release_small = optimize == .ReleaseSmall;

    const opts = b.addOptions();
    opts.addOption([]const u8, "zemit_version", "0.3.0");

    const exe = b.addExecutable(.{
        .name = "zemit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.strip = is_release_small;

    if (!is_debug) {
        exe.root_module.omit_frame_pointer = true;
    }

    const toml_dep = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("toml", toml_dep.module("toml"));
    exe.root_module.addImport("build_options", opts.createModule());

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
