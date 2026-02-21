const std = @import("std");

// internals
const checker = @import("../../../utils/checkers.zig");
const utils_release = @import("../../../utils/checkers.zig");
const reader = @import("../../../customization/config_reader.zig");
const generals_enums = @import("../../../utils/general_enums.zig");

// release utils
const release_checker = @import("./release_utils/release_checkers.zig");
const release_runner = @import("./release_utils/release_runners.zig");
const release_enums = @import("./release_utils/release_enums.zig");

// commands
const helps = @import("../generics/help_command.zig");
const fmt = @import("../../../utils/stdout_formatter.zig");

pub fn release(alloc: std.mem.Allocator, io_stds: generals_enums.Io, args: *std.process.ArgIterator, version: []const u8, verbose: bool) !void {
    const stdout = io_stds.stdout;
    const stderr = io_stds.stderr;

    // flags for 'release'
    const is_tty = utils_release.is_TTY();
    var color = is_tty;

    const env_no_color = std.process.getEnvVarOwned(alloc, "NO_COLOR") catch null;
    if (env_no_color) |val| {
        defer alloc.free(val);
        color = false;
    }

    // These words are used in some places, it is preferable to create them first to avoid rewriting
    const error_fmt = try fmt.red(alloc, "ERROR", color);
    defer alloc.free(error_fmt);

    const ok_fmt = try fmt.green(alloc, "✓", color);
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
            helps.helpOf("release", &.{ "", "-h, --help", "--no-color" }, &.{ path, "Show this help log", "Disables color elements and animations" });
            return;
        }

        if (checker.cli_args_equals(flag, &.{"--no-color"})) {
            color = false;
            continue;
        }

        helps.helpOf("release", &.{ "", "-h, --help", "--no-color" }, &.{ path, "Show this help log", "Disables color elements and animations" });
        try stderr.print("\nUnknown flag for command release: '{s}'\nUse -h or --help to see options.\n", .{flag});
        return;
    }
    alloc.free(path);

    const dist = config_parsed.value.dist;

    const output_dir = try std.mem.Allocator.dupe(alloc, u8, dist.dir);
    defer alloc.free(output_dir);

    release_checker.validate_dist_dir(output_dir) catch |err| {
        switch (err) {
            error.Empty => try stderr.print("{s}: dist.dir cannot be empty.\n", .{error_fmt}),
            error.Dot => try stderr.print("{s}: dist.dir cannot be '.' or './'. Choose a subdirectory.\n", .{error_fmt}),
            error.AbsolutePath => try stderr.print("{s}: dist.dir must be a relative path (absolute paths are not allowed).\n", .{error_fmt}),
            error.Traversal => try stderr.print("{s}: dist.dir cannot contain '..' path traversal.\n", .{error_fmt}),
            error.ZigOut => try stderr.print("{s}: dist.dir cannot be 'zig-out'. Use 'zig-out/<folder>'.\n", .{error_fmt}),
            error.TildeNotAllowed => try stderr.print("{s}: dist.dir cannot start with '~'. Use a relative path.\n", .{error_fmt}),
            error.BackslashNotAllowed => try stderr.print("{s}: dist.dir cannot contain '\\\\'. Use '/' separators.\n", .{error_fmt}),
            error.InvalidByte => try stderr.print("{s}: dist.dir contains invalid characters.\n", .{error_fmt}),
        }
        return error.InvalidConfig;
    };

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

    if (!(try release_checker.is_valid_project(alloc, current_directory))) {
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

    if (color) {
        const total_as_str = try std.fmt.allocPrint(alloc, "{d}", .{total});
        const a = try fmt.cyan(alloc, total_as_str, is_tty);

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
        .color = color,
        .d_optimize = d_optimize,
        .out_path = dist_dir_path,
        .full_path = "",
        .version = version,
        .verbose = verbose,
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

    const dur = try fmt.gray(alloc, raw_dur, color);
    defer alloc.free(dur);

    if (verbose) {
        try stdout.print("{s} Compilation completed! Binaries in: {s} {s}\n", .{ ok_fmt, dist_dir_path, dur });
    } else {
        try stdout.print("\n{s} Compilation completed! Binaries in: {s} {s}\n", .{ ok_fmt, dist_dir_path, dur });
    }

    if (std.io.getStdOut().supportsAnsiEscapeCodes()) {
        var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
        try bw.flush();
    }
}
