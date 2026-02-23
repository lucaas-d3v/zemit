const std = @import("std");
const cli = @import("./cli/cli.zig");

// application entry point: initializes memory management and dispatches to the cli module
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    cli.cli(alloc) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        std.process.exit(1);
    };
}
