const std = @import("std");

pub fn str_equals(str_a: []const u8, str_b: []const u8) bool {
    return std.mem.eql(u8, str_a, str_b);
}

pub fn cli_args_equals(arg: []const u8, expected_commands: []const []const u8) bool {
    for (expected_commands) |command| {
        if (str_equals(arg, command)) {
            return true;
        }
    }

    return false;
}
