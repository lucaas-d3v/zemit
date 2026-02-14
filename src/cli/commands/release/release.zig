const std = @import("std");
const print = std.debug.print;

// internals
const checker = @import("../../../utils/checkers.zig");

// release utils
const utils = @import("./release_utils/release_checkers.zig");

// commands
const helps = @import("../generics/help_command.zig");

pub fn release(args: *std.process.ArgIterator) !void {
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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak_status = gpa.deinit();
        if (leak_status == .leak) std.debug.print("Memory Leak detectado!\n", .{});
    }

    const alloc = gpa.allocator();

    var this_dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer this_dir.close();

    if (!(try utils.is_valid_project(alloc, this_dir))) {
        print("ERROR: you are not in a valid zig project (project generated via `zig init`)\n", .{});
        return;
    }
}
