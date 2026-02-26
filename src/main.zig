const std = @import("std");
const cli = @import("./cli/cli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    cli.runCli(alloc) catch {
        std.process.exit(1);
    };
}
