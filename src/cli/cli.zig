const std = @import("std");
const print = std.debug.print;

// internals
const checker = @import("../utils/checkers.zig");

// commands
const helps = @import("./commands/generics/help_command.zig");
const version = @import("./commands/generics/version.zig");

const release = @import("./commands/release/release.zig");

pub fn cli() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak_status = gpa.deinit();
        if (leak_status == .leak) std.debug.print("Memory Leak detected!\n", .{});
    }
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // bin name

    var verbose: bool = false;
    var command: ?[]const u8 = null;

    // global flags
    while (args.next()) |arg| {
        if (checker.cli_args_equals(arg, &.{ "-h", "--help" })) {
            helps.help();
            return;
        }

        if (checker.cli_args_equals(arg, &.{ "-V", "--version" })) {
            version.version();
            return;
        }

        if (checker.cli_args_equals(arg, &.{ "-v", "--verbose" })) {
            verbose = true;
            continue;
        }

        // Se chegou aqui, não é uma flag - deve ser o comando
        command = arg;
        break;
    }

    // Se não encontrou comando, mostra help
    const cmd = command orelse {
        helps.help();
        return;
    };

    // dispatch
    if (checker.str_equals(cmd, "release")) {
        try release.release(alloc, &args, verbose);
        return;
    }

    helps.help();
    print("\nUnknown command: '{s}'\n", .{cmd});
}
