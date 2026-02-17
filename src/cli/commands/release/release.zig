const std = @import("std");

// internals
const checker = @import("../../../utils/checkers.zig");
const r_checker = @import("./release_utils/release_checkers.zig");
const reader = @import("../../../customization/config_reader.zig");

// release utils
const utils = @import("./release_utils/release_checkers.zig");
const runner = @import("./release_utils/release_runners.zig");

// commands
const helps = @import("../generics/help_command.zig");
const fmt = @import("../../../utils/stdout_formatter.zig");

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

    pub fn fromString(input: []const u8) ?Architectures {
        if (std.mem.eql(u8, input, "x86_64-linux-gnu")) return .x86_64_linux_gnu;
        if (std.mem.eql(u8, input, "x86_64-linux-musl")) return .x86_64_linux_musl;
        if (std.mem.eql(u8, input, "aarch64-linux-gnu")) return .aarch64_linux_gnu;
        if (std.mem.eql(u8, input, "aarch64-linux-musl")) return .aarch64_linux_musl;
        if (std.mem.eql(u8, input, "arm-linux-gnueabihf")) return .arm_linux_gnueabihf;
        if (std.mem.eql(u8, input, "arm-linux-musleabihf")) return .arm_linux_musleabihf;
        if (std.mem.eql(u8, input, "riscv64-linux-gnu")) return .riscv64_linux_gnu;
        if (std.mem.eql(u8, input, "riscv64-linux-musl")) return .riscv64_linux_musl;
        if (std.mem.eql(u8, input, "x86_64-windows-gnu")) return .x86_64_windows_gnu;
        if (std.mem.eql(u8, input, "x86_64-windows-msvc")) return .x86_64_windows_msvc;
        if (std.mem.eql(u8, input, "x86_64-macos")) return .x86_64_macos;
        if (std.mem.eql(u8, input, "aarch64-macos")) return .aarch64_macos;
        return null;
    }
};

pub fn release(alloc: std.mem.Allocator, args: *std.process.ArgIterator, version: []const u8, verbose: bool) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    // flags para 'release'
    const is_tty = r_checker.is_TTY();
    var color = is_tty;

    const env_no_color = std.process.getEnvVarOwned(alloc, "NO_COLOR") catch null;
    if (env_no_color) |val| {
        defer alloc.free(val);
        color = false;
    }

    while (args.next()) |flag| {
        if (checker.cli_args_equals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("release", &.{"-h, --help"}, &.{"compiles multi-target and places correctly named binaries in dist/"});
            return;
        }

        if (checker.cli_args_equals(flag, &.{"--no-color"})) {
            color = false;
            continue;
        }

        helps.helpOf("release", &.{"-h, --help"}, &.{"compiles multi-target and places correctly named binaries in dist/"});
        try stderr.print("\nUnknown flag for command release: '{s}'\n", .{flag});
        return;
    }

    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    const toml_path = "zemit.toml";

    const config_parsed = reader.load(alloc, toml_path) catch |err| {
        std.log.err("ERROR: Failed to parse '{s}', check the syntaxe", .{toml_path});
        return err;
    };
    defer config_parsed.deinit(); // This cleans up the arena allocator

    const target_strings = config_parsed.value.release.targets orelse blk: {
        try stdout.print("Falling back to default architectures...\n", .{});
        const defaults = std.enums.values(Architectures);

        var arch_strings = try std.ArrayList([]const u8).initCapacity(alloc, defaults.len);
        for (defaults) |arch| {
            arch_strings.appendAssumeCapacity(arch.asString());
        }

        break :blk try arch_strings.toOwnedSlice();
    };

    var archs = std.ArrayList(Architectures).init(alloc);
    defer archs.deinit();

    for (target_strings) |target_str| {
        const arch = Architectures.fromString(target_str) orelse {
            try stderr.print("Unknown architecture: '{s}'\n", .{target_str});
            return;
        };
        try archs.append(arch);
    }

    if (archs.items.len == 0) {
        try stderr.print("ERROR: No valid target architectures found. Check your zemit.toml configuration.\n", .{});
        return;
    }

    if (!(try utils.is_valid_project(alloc, dir))) {
        try stderr.print("ERROR: you are not in a valid zig project (project generated via `zig init`)\n", .{});
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

    const total = archs.items.len;
    const bin_name = std.fs.path.basename(full_path_dir);

    try stdout.print("\nStarting release for {d} targets...\n\n", .{total});
    var build_timer = try std.time.Timer.start();

    for (1.., archs.items) |i, architecture| {
        const exit_code = runner.compile_and_move(alloc, architecture, dist_dir_path, bin_name, version, verbose, i, total, color) catch return;

        switch (exit_code) {
            .Exited => |code| {
                if (code != 0) {
                    try stderr.print("ERROR: We were unable to compile your binary for '{s}'. exit code: {}\n", .{ architecture.asString(), code });
                    return;
                }
            },
            .Signal, .Stopped, .Unknown => {
                try stderr.print("ERROR: Build process for '{s}' stopped or failed.\n", .{architecture.asString()});
                return;
            },
        }
    }
    const elapsed_ns = build_timer.read();

    const ok = try fmt.green(alloc, "✓", is_tty);
    defer alloc.free(ok);

    const raw_dur = try fmt.fmt_duration(alloc, elapsed_ns);
    defer alloc.free(raw_dur);

    const dur = try fmt.gray(alloc, raw_dur, color);
    defer alloc.free(dur);

    if (verbose) {
        try stdout.print("{s} Compilation completed! Binaries in: {s} {s}\n", .{ ok, dist_dir_path, dur });
    } else {
        try stdout.print("\n{s} Compilation completed! Binaries in: {s} {s}\n", .{ ok, dist_dir_path, dur });
    }
}
