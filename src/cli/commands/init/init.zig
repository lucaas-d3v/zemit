const std = @import("std");
const general_enums = @import("../../../utils/general_enums.zig");
const checker = @import("../../../utils/checkers.zig");
const helps = @import("../../commands/generics/help_command.zig");

pub fn runInit(
    args: *std.process.ArgIterator,
    io: general_enums.Io,
) !void {
    while (args.next()) |flag| {
        if (checker.cliArgsEquals(flag, &.{ "-h", "--help" })) {
            helps.helpOf("init", &.{ "", "-h, --help" }, &.{ "Generates the zemit.toml configuration file", "Show this help log." }, io);
            return;
        }

        helps.helpOf("init", &.{ "", "-h, --help" }, &.{ "Generates the zemit.toml configuration file", "Show this help log." }, io);
        try io.stderr.print("Unknown flag for command init: '{s}'\nUse -h or --help to see options.\n", .{flag});
        return;
    }

    const default_config_content =
        \\[build]
        \\optimize = "ReleaseSmall"
        \\zig_args = [""]
        \\
        \\[release]
        \\targets = [
        \\    "x86_64-linux-gnu",
        \\    "x86_64-linux-musl",
        \\    "aarch64-linux-gnu",
        \\    "aarch64-linux-musl",
        \\    "arm-linux-gnueabihf",
        \\    "arm-linux-musleabihf",
        \\    "riscv64-linux-gnu",
        \\    "riscv64-linux-musl",
        \\    "x86_64-windows-gnu",
        \\    "x86_64-windows-msvc",
        \\    "x86_64-macos",
        \\    "aarch64-macos",
        \\]
        \\
        \\[dist]
        \\dir = "zemit/docs"
        \\layout = "by_target"
        \\name_template = "{bin}-{version}-{target}{ext}"
        \\
        \\[checksums]
        \\enabled = true
        \\algorithm = "sha256"
        \\file = "checksums.txt"
    ;

    const file = std.fs.cwd().createFile("zemit.toml", .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) {
            try io.stderr.print("{s}: 'zemit.toml' already exists in the current directory. Initialization aborted.\n", .{io.warn_fmt});
            return;
        }

        try io.stderr.print("{s}: Failed to create 'zemit.toml': {}\n", .{ io.error_fmt, err });
        return err;
    };
    defer file.close();

    try file.writeAll(default_config_content);

    try io.stdout.print("{s} 'zemit.toml' successfully generated!\n", .{io.ok_fmt});
}
