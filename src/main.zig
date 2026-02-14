const std = @import("std");
const cli = @import("./cli/cli.zig");

pub fn main() !void {
    try cli.cli();
}
