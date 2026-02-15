const std = @import("std");
const print = std.debug.print;

// internals
const checker = @import("../../../utils/checkers.zig");

// release utils
const utils = @import("./release_utils/release_checkers.zig");
const runner = @import("./release_utils/release_runners.zig");

// commands
const helps = @import("../generics/help_command.zig");

pub const Architectures = enum {
    x86_64_linux_gnu,
    x86_64_linux_musl,

    aarch64_linux_gnu,
    aarch64_linux_musl,

    arm_linux_gnueabihf,
    arm_linux_musleabihf,

    riscv64_linux_gnu,
    riscv64_linux_musl,

    x86_64_windows_gnu,
    x86_64_windows_msvc,

    x86_64_macos,
    aarch64_macos,

    pub fn asString(self: Architectures) []const u8 {
        return switch (self) {
            .x86_64_linux_gnu => "x86_64-linux-gnu",
            .x86_64_linux_musl => "x86_64-linux-musl",

            .aarch64_linux_gnu => "aarch64-linux-gnu",
            .aarch64_linux_musl => "aarch64-linux-musl",

            .arm_linux_gnueabihf => "arm-linux-gnueabihf",
            .arm_linux_musleabihf => "arm-linux-musleabihf",

            .riscv64_linux_gnu => "riscv64-linux-gnu",
            .riscv64_linux_musl => "riscv64-linux-musl",

            .x86_64_windows_gnu => "x86_64-windows-gnu",
            .x86_64_windows_msvc => "x86_64-windows-msvc",

            .x86_64_macos => "x86_64-macos",
            .aarch64_macos => "aarch64-macos",
        };
    }
};

pub fn release(alloc: std.mem.Allocator, args: *std.process.ArgIterator, verbose: bool) !void {
    // flags para 'release'
    while (args.next()) |flag| {
        if (checker.cli_args_equals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("release", &.{"-h, --help"}, &.{"compiles multi-target and places correctly named binaries in dist/"});
            return;
        }

        helps.helpOf("release", &.{"-h, --help"}, &.{"compiles multi-target and places correctly named binaries in dist/"});
        print("\nUnknown flag for command release: '{s}'\n", .{flag});
        return;
    }

    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    if (!(try utils.is_valid_project(alloc, dir))) {
        print("ERROR: you are not in a valid zig project (project generated via `zig init`)\n", .{});
        return;
    }

    std.fs.cwd().makePath(".zemit/dist") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const dist_dir_path = try dir.realpathAlloc(alloc, ".zemit/dist");
    defer alloc.free(dist_dir_path);

    const full_path_dir = try dir.realpathAlloc(alloc, ".");
    defer alloc.free(full_path_dir);

    const bin_name = std.fs.path.basename(full_path_dir);
    print("\nStarting release for {d} targets...\n\n", .{std.enums.values(Architectures).len});
    var build_timer = try std.time.Timer.start();

    for (std.enums.values(Architectures)) |architecture| {
        const exit_code = runner.compile_and_move(alloc, architecture, dist_dir_path, bin_name, verbose) catch return;

        switch (exit_code) {
            .Exited => |code| {
                if (code != 0) {
                    print("ERROR: We were unable to compile your binary for '{s}'. exit code: {}\n", .{ architecture.asString(), code });
                    return;
                }
            },
            .Signal, .Stopped, .Unknown => {
                print("ERROR: Build process for '{s}' stopped or failed.\n", .{architecture.asString()});
                return;
            },
        }
    }
    const elapsed_ns = build_timer.read();

    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    print("\n✓ Compilation completed! Binaries in: {s} ({d:.2}s)\n", .{ dist_dir_path, elapsed_s });
}
