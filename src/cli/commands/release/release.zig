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

const TargetMap = std.StaticStringMap(Architectures).initComptime(blk: {
    const fields = @typeInfo(Architectures).Enum.fields;
    var pairs: [fields.len]struct { []const u8, Architectures } = undefined;
    for (fields, 0..) |field, i| {
        const enum_val: Architectures = @enumFromInt(field.value);
        pairs[i] = .{ enum_val.asString(), enum_val };
    }
    break :blk pairs;
});

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

    pub fn exists(name: []const u8) bool {
        return TargetMap.has(name);
    }

    pub fn fromString(input: []const u8) ?Architectures {
        return TargetMap.get(input);
    }
};

pub fn release(alloc: std.mem.Allocator, args: *std.process.ArgIterator, version: []const u8, verbose: bool) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    // flags for 'release'
    const is_tty = r_checker.is_TTY();
    var color = is_tty;

    const env_no_color = std.process.getEnvVarOwned(alloc, "NO_COLOR") catch null;
    if (env_no_color) |val| {
        defer alloc.free(val);
        color = false;
    }

    while (args.next()) |flag| {
        if (checker.cli_args_equals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("release", &.{ "-h, --help", "--no-color" }, &.{ "compiles multi-target and places correctly named binaries in dist/", "disables color elements and animations" });
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

    // These words are used in some places, it is preferable to create them first to avoid rewriting
    const ERROR = try fmt.red(alloc, "ERROR", is_tty);
    defer alloc.free(ERROR);

    const OK = try fmt.green(alloc, "✓", is_tty);
    defer alloc.free(OK);

    const toml_path = "zemit.toml"; // hardcoded for now
    const config_parsed = reader.load(alloc, toml_path) catch |err| {
        std.log.err("{s}: Failed to parse '{s}', check the syntaxe", .{ ERROR, toml_path });
        return err;
    };
    defer config_parsed.deinit(); // This cleans up the arena allocator

    const dist = config_parsed.value.dist;

    const output_dir = try std.mem.Allocator.dupe(alloc, u8, dist.dir);
    defer alloc.free(output_dir);

    const archs = config_parsed.value.release.targets;

    if (archs.len == 0) {
        try stderr.print("{s}: The architectures list described in 'zemit.toml' cannot be empty.\n", .{ERROR});
        return;
    }

    for (archs) |target_str| {
        if (target_str.len == 0) {
            try stderr.print("{s}: The architecture described in 'zemit.toml' cannot be empty.\n", .{ERROR});
            return;
        }

        if (!Architectures.exists(target_str)) {
            try stderr.print("{s}: Unknown architecture: '{s}'\n", .{ ERROR, target_str });
            return;
        }
    }

    if (archs.len == 0) {
        try stderr.print("{s}: No valid target architectures found. Check your zemit.toml configuration.\n", .{ERROR});
        return;
    }

    var current_directory = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer current_directory.close();

    if (!(try utils.is_valid_project(alloc, current_directory))) {
        try stderr.print("{s}: you are not in a valid zig project (project generated via `zig init`)\n", .{ERROR});
        return;
    }

    std.fs.cwd().makePath(output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    const dist_dir_path = try current_directory.realpathAlloc(alloc, output_dir);
    defer alloc.free(dist_dir_path);

    const full_path_dir = try current_directory.realpathAlloc(alloc, ".");
    defer alloc.free(full_path_dir);

    const total = archs.len;
    const bin_name = std.fs.path.basename(full_path_dir);

    const total_as_str = try std.fmt.allocPrint(alloc, "{d}", .{total});
    const a = try fmt.cyan(alloc, total_as_str, is_tty);

    defer {
        alloc.free(total_as_str);
        alloc.free(a);
    }

    const d_optimize = config_parsed.value.build.optimize;
    const zig_args = config_parsed.value.build.zig_args;

    try stdout.print("\nStarting release for {s} targets...\n\n", .{a});

    var build_timer = try std.time.Timer.start();
    for (1.., archs) |i, architecture| {
        const arch = Architectures.fromString(architecture) orelse {
            try stderr.print("{s}: Unknown architecture: '{s}'\n", .{ ERROR, architecture });
            return;
        };

        const exit_code = runner.compile_and_move(alloc, arch, dist_dir_path, bin_name, version, d_optimize, zig_args, verbose, i, total, color) catch return;
        switch (exit_code) {
            .Exited => |code| {
                if (code != 0) {
                    try stderr.print("{s}: We were unable to compile your binary for '{s}'. exit code: {}\n", .{ ERROR, arch.asString(), code });
                    return;
                }
            },
            .Signal, .Stopped, .Unknown => {
                try stderr.print("{s}: Build process for '{s}' stopped or failed.\n", .{ ERROR, arch.asString() });
                return;
            },
        }
    }
    const elapsed_ns = build_timer.read();

    const raw_dur = try fmt.fmt_duration(alloc, elapsed_ns);
    defer alloc.free(raw_dur);

    const dur = try fmt.gray(alloc, raw_dur, color);
    defer alloc.free(dur);

    if (verbose) {
        try stdout.print("{s} Compilation completed! Binaries in: {s} {s}\n", .{ OK, dist_dir_path, dur });
    } else {
        try stdout.print("\n{s} Compilation completed! Binaries in: {s} {s}\n", .{ OK, dist_dir_path, dur });
    }

    if (std.io.getStdOut().supportsAnsiEscapeCodes()) {
        var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
        try bw.flush();
    }
}
