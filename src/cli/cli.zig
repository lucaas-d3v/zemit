const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

// internals
const checker = @import("../utils/checkers.zig");

// commands
const helps = @import("./commands/generics/help_command.zig");
const version = @import("./commands/generics/version.zig");
const release = @import("./commands/release/release.zig");
const clean = @import("./commands/clean/clean.zig");

pub fn cli(alloc: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // bin name

    var verbose: bool = false;
    var command: ?[]const u8 = null;

    // global flags
    while (args.next()) |arg| {
        if (checker.cli_args_equals(arg, &.{ "-h", "--help" })) {
            helps.help(alloc);
            return;
        }

        if (checker.cli_args_equals(arg, &.{ "-V", "--version" })) {
            version.version(build_options.zemit_version);
            return;
        }

        if (checker.cli_args_equals(arg, &.{ "-v", "--verbose" })) {
            verbose = true;
            continue;
        }

        command = arg;
        break;
    }

    const cmd = command orelse {
        helps.help(alloc);
        return;
    };

    // dispatch
    if (checker.str_equals(cmd, "release")) {
        try release.release(alloc, &args, build_options.zemit_version, verbose);
        return;
    }

    if (checker.str_equals(cmd, "clean")) {
        try clean.clean(alloc, &args, "zemit.toml", verbose);
        return;
    }

    helps.help(alloc);
    const stderr = std.io.getStdErr().writer();
    try stderr.print("\nError: Unknown command '{s}'\n", .{cmd});
}
