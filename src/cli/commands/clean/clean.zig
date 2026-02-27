const std = @import("std");
const reader = @import("../../../customization/config_reader.zig");
const checker = @import("../../../utils/checkers.zig");
const helps = @import("../../commands/generics/help_command.zig");
const general_enums = @import("../../../utils/general_enums.zig");

pub fn runClean(alloc: std.mem.Allocator, global_flags: general_enums.GlobalFlags, args: *std.process.ArgIterator, io: general_enums.Io, config: reader.toml.Parsed(reader.Config)) !void {
    var dry_run = false;

    const zemit_dir = config.value.dist.dir;
    const path = try std.fmt.allocPrint(alloc, "       Clears the output directory of multi-targets in '{s}'", .{zemit_dir});
    defer alloc.free(path);

    while (args.next()) |flag| {
        if (checker.cliArgsEquals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("clean", &.{ "", "-d, --dry-run", "-h, --help" }, &.{ path, "Preview of what will be cleaned", "Show this help log." }, io);
            return;
        }

        if (checker.cliArgsEquals(flag, &.{ "-d", "--dry-run" })) {
            dry_run = true;
            continue;
        }

        helps.helpOf("clean", &.{ "", "-d, --dry-run", "-h, --help" }, &.{ path, "Preview of what will be cleaned", "Show this help log." }, io);
        try io.stderr.print("Unknown flag for command clean: '{s}'\nUse -h or --help to see options.\n", .{flag});
        return;
    }

    var current_dir = try std.fs.cwd().openDir(".", .{});
    defer current_dir.close();

    try checker.validateDistDirStopIfNot(zemit_dir, io);

    if (dry_run) {
        const sep = std.fs.path.sep;
        var out_dir = current_dir.openDir(zemit_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                try io.stdout.print("Nothing to clean: '{s}' does not exist.\n", .{zemit_dir});
                return;
            }
            return err;
        };
        defer out_dir.close();

        var iter = try out_dir.walk(alloc);
        defer iter.deinit();

        while (try iter.next()) |entry| {
            if (entry.kind == .directory) continue;
            try io.stdout.print("Would be removed: '{s}{c}{s}'\n", .{ zemit_dir, sep, entry.path });
        }
        return;
    }

    current_dir.access(zemit_dir, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            try io.stdout.print("Nothing to clean: '{s}' directory not found.\n", .{zemit_dir});
            return;
        },
        else => return err,
    };

    try io.stdout.print("Cleaning output directory: '{s}'\n", .{zemit_dir});
    current_dir.deleteTree(zemit_dir) catch |err| {
        try io.stderr.print("{s}: Failed to clean directory '{s}': {}\n", .{ io.error_fmt, zemit_dir, err });
        return;
    };

    if (global_flags.verbose) {
        try io.stdout.print("{s} Cleaned: '{s}'\n", .{ io.ok_fmt, zemit_dir });
    } else {
        try io.stdout.print("\n{s} Cleaned: '{s}'!\n", .{ io.ok_fmt, zemit_dir });
    }
}
