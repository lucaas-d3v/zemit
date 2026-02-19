const std = @import("std");

// internals
const reader = @import("../../../customization/config_reader.zig");
const fmt = @import("../../../utils/stdout_formatter.zig");

const utils = @import("../../../utils/checkers.zig");
const checker = @import("../../../utils/checkers.zig");
const helps = @import("../../commands/generics/help_command.zig");

pub fn clean(alloc: std.mem.Allocator, args: *std.process.ArgIterator, toml_path: []const u8, verbose: bool) !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const is_tty = utils.is_TTY();
    var dry_run = false;

    const ERROR = try fmt.red(alloc, "ERROR", is_tty);
    defer alloc.free(ERROR);

    const OK = try fmt.green(alloc, "✓", is_tty);
    defer alloc.free(OK);

    const config_parsed = reader.load(alloc, toml_path) catch |err| {
        try stderr.print("{s}: Failed to parse '{s}', check the syntaxe", .{ ERROR, toml_path });
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
        try stderr.print("{s}: Failed to clean directory '{s}': {}\n", .{ ERROR, zemit_dir, err });
        return;
    };

    if (verbose) {
        try stdout.print("{s} Cleaned: '{s}'\n", .{ OK, zemit_dir });
    } else {
        try stdout.print("\n{s} Cleaned: '{s}'!\n", .{ OK, zemit_dir });
    }
}
