const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

pub fn version(zVersion: []const u8) void {
    const stdout = std.io.getStdOut().writer();

    stdout.print(
        "zemit {s} (zig {s}) {s}-{s}\n",
        .{
            zVersion,
            builtin.zig_version_string,
            @tagName(builtin.cpu.arch),
            @tagName(builtin.os.tag),
        },
    ) catch {};
}
