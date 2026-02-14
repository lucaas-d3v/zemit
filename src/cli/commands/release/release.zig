const std = @import("std");
const print = std.debug.print;

// internals
const checker = @import("../../../utils/checkers.zig");

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

    print("Releasing...\n", .{});
}
