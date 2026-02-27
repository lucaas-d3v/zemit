const std = @import("std");
const checker = @import("../../../utils/checkers.zig");
const reader = @import("../../../customization/config_reader.zig");
const generals_enums = @import("../../../utils/general_enums.zig");
const release_runner = @import("./release_utils/release_runners.zig");
const release_enums = @import("./release_utils/release_enums.zig");
const helps = @import("../generics/help_command.zig");
const fmt = @import("../../../utils/stdout_formatter.zig");

pub fn runRelease(
    alloc: std.mem.Allocator,
    global_flags: generals_enums.GlobalFlags,
    io: generals_enums.Io,
    args: *std.process.ArgIterator,
    release_ctx: release_enums.ReleaseCtx,
    config_parsed: reader.toml.Parsed(reader.Config),
) !void {
    const path = try std.fmt.allocPrint(alloc, "       Compiles multi-target and places correctly named binaries in '{s}'", .{config_parsed.value.dist.dir});
    while (args.next()) |flag| {
        if (checker.cliArgsEquals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("release", &.{ "", "-h, --help" }, &.{ path, "Show this help log" }, io);
            return;
        }
        helps.helpOf("release", &.{ "", "-h, --help" }, &.{ path, "Show this help log" }, io);
        try io.stderr.print("\nUnknown flag for command release: '{s}'\nUse -h or --help to see options.\n", .{flag});
        return;
    }
    alloc.free(path);

    const output_dir = config_parsed.value.dist.dir;
    try checker.validateDistDirStopIfNot(output_dir, io);

    const archs = config_parsed.value.release.targets;
    if (archs.len == 0) {
        try io.stderr.print("{s}: The architectures list described in 'zemit.toml' cannot be empty.\n", .{io.error_fmt});
        return;
    }

    var current_directory = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer current_directory.close();

    if (!(try checker.isValidProject(alloc, current_directory))) {
        try io.stderr.print("{s}: you are not in a valid zig project (project generated via `zig init`)\n", .{io.error_fmt});
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

    var general_release_ctx = release_enums.ReleaseCtx{
        .alloc = alloc,
        .architecture = .none,
        .out_path = dist_dir_path,
        .full_path = "",
        .bin_name = bin_name,
        .version = release_ctx.version,
        .d_optimize = config_parsed.value.build.optimize,
        .zig_args = config_parsed.value.build.zig_args,
        .layout = release_ctx.layout,
        .checksums = config_parsed.value.checksums,
        .name_tamplate = config_parsed.value.dist.name_template,
        .verbose = global_flags.verbose,
        .total = total,
        .color = global_flags.color,
    };

    if (!(try config_parsed.value.isOk(alloc, &general_release_ctx, io))) return;

    if (global_flags.color) {
        const total_as_str = try std.fmt.allocPrint(alloc, "{d}", .{total});
        defer alloc.free(total_as_str);
        try io.stdout.print("Starting release for ", .{});
        try fmt.printCyan(io.stdout, total_as_str, global_flags.color);
        try io.stdout.print(" targets...\n\n", .{});
    } else {
        try io.stdout.print("Starting release for {d} targets...\n\n", .{total});
    }

    var build_timer = try std.time.Timer.start();
    for (1.., archs) |i, architecture| {
        const arch_enum = release_enums.Architectures.fromString(architecture) orelse {
            try io.stderr.print("{s}: Unknown architecture: '{s}'\n", .{ io.error_fmt, architecture });
            return;
        };

        general_release_ctx.architecture = arch_enum;
        const exit_code = release_runner.compileAndMove(&general_release_ctx, io, global_flags, i) catch return;
        switch (exit_code) {
            .Exited => |code| {
                if (code != 0) {
                    try io.stderr.print("{s}: We were unable to compile your binary for '{s}'. exit code: {}\n", .{ io.error_fmt, arch_enum.asString(), code });
                    return;
                }
            },
            .Signal, .Stopped, .Unknown => {
                try io.stderr.print("{s}: Build process for '{s}' stopped or failed.\n", .{ io.error_fmt, arch_enum.asString() });
                return;
            },
        }
    }
    const elapsed_ns = build_timer.read();

    var out_dir_files = try std.fs.openDirAbsolute(general_release_ctx.out_path, .{ .iterate = true });
    defer out_dir_files.close();

    var files = try out_dir_files.walk(alloc);
    defer files.deinit();

    if (general_release_ctx.checksums.enabled) {
        var checksum_timer = try std.time.Timer.start();
        try release_runner.writeChecksumsContentOf(alloc, general_release_ctx.out_path, &files, general_release_ctx.checksums);
        const checksum_elapsed_ns = checksum_timer.read();

        const break_char = if (global_flags.verbose) "" else "\n";
        try io.stdout.print("{s}{s} Checksums file '{s}' created ", .{ break_char, io.ok_fmt, general_release_ctx.checksums.file });
        try fmt.printDuration(io.stdout, checksum_elapsed_ns, global_flags.color);
        if (global_flags.verbose) try io.stdout.print("\n", .{});
    }

    const start_char = if (global_flags.verbose) "" else "\n";
    try io.stdout.print("{s}{s} Compilation completed! Binaries in: {s} ", .{ start_char, io.ok_fmt, dist_dir_path });
    try fmt.printDuration(io.stdout, elapsed_ns, global_flags.color);
    try io.stdout.print("\n", .{});
}
