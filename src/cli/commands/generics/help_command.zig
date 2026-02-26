const std = @import("std");
const reader = @import("../../../customization/config_reader.zig");
const general_enums = @import("../../../utils/general_enums.zig");

pub fn help(io: general_enums.Io, config: reader.toml.Parsed(reader.Config)) void {
    const path = config.value.dist.dir;

    io.stdout.print("Usage: zemit [global options] <command> [command options]\n\n", .{}) catch {};
    io.stdout.print("Available commands\n", .{}) catch {};
    io.stdout.print("    release:              Compiles multi-target and places correctly named binaries in '{s}'\n", .{path}) catch {};
    io.stdout.print("    clean:                Clears the output directory of multi-targets in '{s}'\n\n", .{path}) catch {};
    io.stdout.print("General Commands\n", .{}) catch {};
    io.stdout.print("    -h, --help:           Show this help log.\n", .{}) catch {};
    io.stdout.print("    -V, --version:        Show zemit version.\n", .{}) catch {};
    io.stdout.print("    -v, --verbose:        Enable verbose mode.\n", .{}) catch {};
    io.stdout.print("    -nc, --no-color:      Disables color elements and animations.\n", .{}) catch {};
}

pub fn helpOf(command_name: []const u8, flags: []const []const u8, descriptions: []const []const u8, io: general_enums.Io) void {
    io.stdout.print("Usage of {s}: \n\n", .{command_name}) catch {};

    for (flags, descriptions) |flag, desc| {
        if (flag.len == 0) {
            io.stdout.print("     {s}                                {s}\n", .{ command_name, desc }) catch {};
            continue;
        }
        io.stdout.print("     {s}   < {s} >                      {s}\n", .{ command_name, flag, desc }) catch {};
    }
}
