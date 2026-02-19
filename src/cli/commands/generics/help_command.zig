const std = @import("std");
const reader = @import("../../../customization/config_reader.zig");

pub fn help(alloc: std.mem.Allocator) void {
    const config = reader.load(alloc, "zemit.toml") catch {
        return;
    };
    defer config.deinit();

    const path = config.value.dist.dir;

    const stdout = std.io.getStdOut().writer();

    stdout.print("Usage: zemit [global options] <command> [command options]\n\n", .{}) catch {};

    stdout.print("Available commands\n", .{}) catch {};
    stdout.print("    release:              Compiles multi-target and places correctly named binaries in '{s}'\n", .{path}) catch {};
    stdout.print("    clean:                Clears the output directory of multi-targets in '{s}'\n\n", .{path}) catch {};

    stdout.print("General Commands\n", .{}) catch {};
    stdout.print("    -h, --help:           Show this help log.\n", .{}) catch {};
    stdout.print("    -V, --version:        Show zemit version.\n", .{}) catch {};
    stdout.print("    -v, --verbose:        Enable verbose mode.\n", .{}) catch {};
}

pub fn helpOf(command_name: []const u8, flags: []const []const u8, descriptions: []const []const u8) void {
    const stdout = std.io.getStdOut().writer();

    stdout.print("Usage of {s}: \n\n", .{command_name}) catch {};

    for (flags, descriptions) |flag, desc| {
        if (flag.len == 0) {
            stdout.print("     {s}                                {s}\n", .{ command_name, desc }) catch {};
            continue;
        }
        stdout.print("     {s}   < {s} >                      {s}\n", .{ command_name, flag, desc }) catch {};
    }
}
