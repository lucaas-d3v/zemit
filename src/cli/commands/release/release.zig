const std = @import("std");

// internals
const checker = @import("../../../utils/checkers.zig");
const utils_release = @import("../../../utils/checkers.zig");
const reader = @import("../../../customization/config_reader.zig");
const generals_enums = @import("../../../utils/general_enums.zig");

// release utils
const release_runner = @import("./release_utils/release_runners.zig");
const release_enums = @import("./release_utils/release_enums.zig");

// commands
const helps = @import("../generics/help_command.zig");
const fmt = @import("../../../utils/stdout_formatter.zig");

pub fn release(alloc: std.mem.Allocator, global_flags: generals_enums.GlobalFlags, io_stds: generals_enums.Io, args: *std.process.ArgIterator, version: []const u8) !void {
    const stdout = io_stds.stdout;
    const stderr = io_stds.stderr;

    // These words are used in some places, it is preferable to create them first to avoid rewriting
    const error_fmt = try fmt.red(alloc, "ERROR", global_flags.color);
    defer alloc.free(error_fmt);

    const ok_fmt = try fmt.green(alloc, "✓", global_flags.color);
    defer alloc.free(ok_fmt);

    const toml_path = "zemit.toml"; // hardcoded for now
    const config_parsed = reader.load(alloc, toml_path) catch |err| {
        std.log.err("{s}: Failed to parse '{s}', check the syntaxe", .{ error_fmt, toml_path });
        return err;
    };
    defer config_parsed.deinit(); // This cleans up the arena allocator

    const path = try std.fmt.allocPrint(alloc, "       Compiles multi-target and places correctly named binaries in '{s}'", .{config_parsed.value.dist.dir});
    while (args.next()) |flag| {
        if (checker.cli_args_equals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("release", &.{ "", "-h, --help" }, &.{ path, "Show this help log" });
            return;
        }

        helps.helpOf("release", &.{ "", "-h, --help" }, &.{ path, "Show this help log" });
        try stderr.print("\nUnknown flag for command release: '{s}'\nUse -h or --help to see options.\n", .{flag});
        return;
    }
    alloc.free(path);

    const dist = config_parsed.value.dist;

    const output_dir = try std.mem.Allocator.dupe(alloc, u8, dist.dir);
    defer alloc.free(output_dir);

    try checker.validate_dist_dir_stop_if_not(alloc, output_dir, stderr, global_flags.color);

    const archs = config_parsed.value.release.targets;

    if (archs.len == 0) {
        try stderr.print("{s}: The architectures list described in 'zemit.toml' cannot be empty.\n", .{error_fmt});
        return;
    }

    for (archs) |target_str| {
        if (target_str.len == 0) {
            try stderr.print("{s}: The architecture described in 'zemit.toml' cannot be empty.\n", .{error_fmt});
            return;
        }

        if (!release_enums.Architectures.exists(target_str)) {
            try stderr.print("{s}: Unknown architecture: '{s}'\n", .{ error_fmt, target_str });
            return;
        }
    }

    if (archs.len == 0) {
        try stderr.print("{s}: No valid target architectures found. Check your zemit.toml configuration.\n", .{error_fmt});
        return;
    }

    var current_directory = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer current_directory.close();

    if (!(try checker.is_valid_project(alloc, current_directory))) {
        try stderr.print("{s}: you are not in a valid zig project (project generated via `zig init`)\n", .{error_fmt});
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

    const d_optimize = config_parsed.value.build.optimize;
    const zig_args = config_parsed.value.build.zig_args;

    if (global_flags.color) {
        const total_as_str = try std.fmt.allocPrint(alloc, "{d}", .{total});
        const a = try fmt.cyan(alloc, total_as_str, global_flags.color);

        defer {
            alloc.free(total_as_str);
            alloc.free(a);
        }

        try stdout.print("\nStarting release for {s} targets...\n\n", .{a});
    } else {
        try stdout.print("\nStarting release for {d} targets...\n\n", .{total});
    }

    var general_release_ctx = release_enums.ReleaseCtx{
        .alloc = alloc,
        .architecture = release_enums.Architectures.none,
        .bin_name = bin_name,
        .color = global_flags.color,
        .d_optimize = d_optimize,
        .out_path = dist_dir_path,
        .full_path = "",
        .version = version,
        .verbose = global_flags.verbose,
        .total = total,
        .zig_args = zig_args,
    };

    var build_timer = try std.time.Timer.start();
    for (1.., archs) |i, architecture| {
        const arch = release_enums.Architectures.fromString(architecture) orelse {
            try stderr.print("{s}: Unknown architecture: '{s}'\n", .{ error_fmt, architecture });
            return;
        };

        general_release_ctx.architecture = arch;

        const exit_code = release_runner.compile_and_move(&general_release_ctx, i) catch return;
        switch (exit_code) {
            .Exited => |code| {
                if (code != 0) {
                    try stderr.print("{s}: We were unable to compile your binary for '{s}'. exit code: {}\n", .{ error_fmt, arch.asString(), code });
                    return;
                }
            },
            .Signal, .Stopped, .Unknown => {
                try stderr.print("{s}: Build process for '{s}' stopped or failed.\n", .{ error_fmt, arch.asString() });
                return;
            },
        }
    }
    const elapsed_ns = build_timer.read();

    const raw_dur = try fmt.fmt_pure_duration(alloc, elapsed_ns);
    defer alloc.free(raw_dur);

    const dur = try fmt.gray(alloc, raw_dur, global_flags.color);
    defer alloc.free(dur);

    if (global_flags.verbose) {
        try stdout.print("{s} Compilation completed! Binaries in: {s} {s}\n", .{ ok_fmt, dist_dir_path, dur });
    } else {
        try stdout.print("\n{s} Compilation completed! Binaries in: {s} {s}\n", .{ ok_fmt, dist_dir_path, dur });
    }

    if (std.io.getStdOut().supportsAnsiEscapeCodes()) {
        var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
        try bw.flush();
    }
}
