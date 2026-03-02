const std = @import("std");
const builtin = @import("builtin");

pub fn printVersion(z_version: []const u8) !void {
    var buffer: [1024]u8 = undefined;

    var stdout = std.fs.File.stdout().writer(&buffer);
    defer _ = stdout.interface.flush() catch {};

    stdout.interface.print(
        "zemit {s} (zig {s}) {s}-{s}\n",
        .{ z_version, builtin.zig_version_string, @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) },
    ) catch {};
}
