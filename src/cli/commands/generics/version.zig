const std = @import("std");
const builtin = @import("builtin");

pub fn printVersion(z_version: []const u8) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(
        "zemit {s} (zig {s}) {s}-{s}\n",
        .{ z_version, builtin.zig_version_string, @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) },
    ) catch {};
}
