const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

// internals
const checker = @import("../utils/checkers.zig");
const generals_enums = @import("../utils/general_enums.zig");

// commands
const helps = @import("./commands/generics/help_command.zig");
const version = @import("./commands/generics/version.zig");
const release = @import("./commands/release/release.zig");
const clean = @import("./commands/clean/clean.zig");

pub fn cli(alloc: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // bin name

    var command: ?[]const u8 = null;

    const is_tty = checker.is_TTY();
    var color = is_tty;

    const env_no_color = std.process.getEnvVarOwned(alloc, "NO_COLOR") catch null;
    if (env_no_color) |val| {
        defer alloc.free(val);
        color = false;
    }

    var global_flags = generals_enums.GlobalFlags{
        .color = color,
        .verbose = false,
    };

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
            global_flags.verbose = true;
            continue;
        }

        if (checker.cli_args_equals(arg, &.{ "-nc", "--no-color" })) {
            global_flags.color = false;
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
        var io = generals_enums.Io{
            .stdout = std.io.getStdOut().writer().any(),
            .stderr = std.io.getStdErr().writer().any(),
            .error_fmt = "",
        };

        release.release(alloc, global_flags, &io, &args, build_options.zemit_version) catch |err| {
            switch (err) {
                error.InvalidConfig => try io.stderr.print("Check your zemit.toml.\n", .{}),
                else => {},
            }

            return;
        };

        return;
    }

    if (checker.str_equals(cmd, "clean")) {
        try clean.clean(alloc, global_flags, &args, "zemit.toml");
        return;
    }

    helps.help(alloc);
    const stderr = std.io.getStdErr().writer();
    try stderr.print("\nError: Unknown command '{s}'\n", .{cmd});
}
