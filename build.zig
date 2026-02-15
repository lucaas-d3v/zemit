const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const strip_opt = b.option(bool, "strip", "Strip debug symbols") orelse false;

    const exe = b.addExecutable(.{
        .name = "zemit",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // exe.root_module.strip = strip_opt;
    // exe.link_gc_sections = true;
    // exe.link_function_sections = true;
    // exe.link_data_sections = true;

    const opts = b.addOptions();
    opts.addOption([]const u8, "zemit_version", "0.1.2");
    exe.root_module.addImport("build_options", opts.createModule());

    b.installArtifact(exe);
}
