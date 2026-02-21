const std = @import("std");

// internals
const reader = @import("../../../customization/config_reader.zig");
const fmt = @import("../../../utils/stdout_formatter.zig");

const utils = @import("../../../utils/checkers.zig");
const checker = @import("../../../utils/checkers.zig");
const helps = @import("../../commands/generics/help_command.zig");
const general_enums = @import("../../../utils/general_enums.zig");

pub fn clean(alloc: std.mem.Allocator, global_flags: general_enums.GlobalFlags, args: *std.process.ArgIterator, toml_path: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var dry_run = false;

    const error_fmt = try fmt.red(alloc, "ERROR", global_flags.color);
    defer alloc.free(error_fmt);

    const ok_fmt = try fmt.green(alloc, "✓", global_flags.color);
    defer alloc.free(ok_fmt);

    const config_parsed = reader.load(alloc, toml_path) catch |err| {
        try stderr.print("{s}: Failed to parse '{s}', check the syntaxe", .{ error_fmt, toml_path });
        return err;
    };
    defer config_parsed.deinit(); // this cleans up the arena allocator

    const zemit_dir = config_parsed.value.dist.dir;
    const path = try std.fmt.allocPrint(alloc, "       Clears the output directory of multi-targets in '{s}'", .{zemit_dir});
    defer alloc.free(path);

    while (args.next()) |flag| {
        if (checker.cli_args_equals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("clean", &.{ "", "-d, --dry-run", "-h, --help" }, &.{ path, "Preview of what will be cleaned", "Show this help log." });
            return;
        }

        if (checker.cli_args_equals(flag, &.{ "-d", "--dry-run" })) {
            dry_run = true;
            continue;
        }

        helps.helpOf("clean", &.{ "", "-d, --dry-run", "-h, --help" }, &.{ path, "Preview of what will be cleaned", "Show this help log." });
        try stderr.print("Unknown flag for command clean: '{s}'\nUse -h or --help to see options.\n", .{flag});
        return;
    }

    var current_dir = try std.fs.cwd().openDir(".", .{});
    defer current_dir.close();

    try checker.validate_dist_dir_stop_if_not(alloc, zemit_dir, stderr.any(), global_flags.color);

    if (dry_run) {
        const sep = std.fs.path.sep;
        var out_dir = current_dir.openDir(zemit_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                try stdout.print("Nothing to clean: '{s}' does not exist.\n", .{zemit_dir});
                return;
            }
            return err;
        };
        defer out_dir.close();

        var iter = try out_dir.walk(alloc);
        defer iter.deinit();

        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                continue;
            }

            try stdout.print("Would be removed: ", .{});
            try stdout.print("'{s}{c}{s}'\n", .{ zemit_dir, sep, entry.path });
        }
        return;
    }

    // check if the folder exists before deleting
    current_dir.access(zemit_dir, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            try stdout.print("Nothing to clean: '{s}' directory not found.\n", .{zemit_dir});
            return;
        },
        else => return err,
    };

    try stdout.print("Cleaning output directory: '{s}'\n", .{zemit_dir});
    current_dir.deleteTree(zemit_dir) catch |err| {
        try stderr.print("{s}: Failed to clean directory '{s}': {}\n", .{ error_fmt, zemit_dir, err });
        return;
    };

    if (global_flags.verbose) {
        try stdout.print("{s} Cleaned: '{s}'\n", .{ ok_fmt, zemit_dir });
    } else {
        try stdout.print("\n{s} Cleaned: '{s}'!\n", .{ ok_fmt, zemit_dir });
    }
}
