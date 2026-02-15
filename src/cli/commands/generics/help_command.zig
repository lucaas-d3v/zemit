const std = @import("std");
const print = std.debug.print;

pub fn help() void {
    print("Usage: zemit [global options] <command> [command options]\n\n", .{});

    print("Available commands\n", .{});
    print("    release:              Compiles multi-target and places correctly named binaries in dist/\n\n", .{});

    print("General Commands\n", .{});
    print("    -h, --help:           Show this help log.\n", .{});
    print("    -V, --version:        Show zemit version.\n", .{});
    print("    -v, --verbose:        Enable verbose mode.\n", .{});
}

pub fn helpOf(command_name: []const u8, flags: []const []const u8, descriptions: []const []const u8) void {
    print("Usage of {s}: \n\n", .{command_name});

    for (flags, descriptions) |flag, desc| {
        print("     {s}   < {s} >                      {s}\n", .{ command_name, flag, desc });
    }
}
