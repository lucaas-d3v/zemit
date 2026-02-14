const std = @import("std");

pub fn version(v: []const u8) void {
    std.debug.print("zemit - {s}\n", .{v});
}
