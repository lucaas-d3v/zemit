const std = @import("std");
const print = std.debug.print;

// internals
const checker = @import("../utils/checkers.zig");

// commands
const helps = @import("./commands/generics/help_command.zig");
const version = @import("./commands/generics/version.zig");

const release = @import("./commands/release/release.zig");

pub fn cli() !void {
    var args = std.process.args();
    _ = args.next(); // bin name

    // if there are no arguments
    const first_arg = args.next() orelse {
        helps.help();
        return;
    };

    if (checker.str_equals(first_arg, "release")) {
        try release.release(&args);
        return;
    }

    // generals
    if (checker.cli_args_equals(first_arg, &.{ "-h", "--help" })) {
        helps.help();
        return;
    }

    if (checker.cli_args_equals(first_arg, &.{ "-v", "--version" })) {
        version.version("v0.0.1-dev");
        return;
    }

    helps.help();
    print("\nUnknown command: '{s}'\n", .{first_arg});
}
