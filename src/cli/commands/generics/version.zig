const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

// prints the current zemit version along with zig version and system architecture
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
