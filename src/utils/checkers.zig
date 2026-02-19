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

pub fn contais(allocator: std.mem.Allocator, str_a: []const u8, expected_str: []const u8) !bool {
    if (str_a.len < expected_str.len) return false;

    var i: usize = 0;
    while (i <= str_a.len - expected_str.len) : (i += 1) {
        // sliding window
        const likely_str = str_a[i .. i + expected_str.len];

        if (str_equals(expected_str, likely_str)) return true;

        const inverted = try reverse_str(allocator, likely_str);
        defer allocator.free(inverted);

        if (str_equals(expected_str, inverted)) return true;
    }

    return false;
}

pub fn file_exists(dir: std.fs.Dir, file_path: []const u8) bool {
    dir.access(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return false;
        return false;
    };
    return true;
}

pub fn is_TTY() bool {
    return std.posix.isatty(std.io.getStdOut().handle);
}

// utils
fn reverse_str(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, input.len);

    for (input, 0..) |char, i| {
        result[input.len - 1 - i] = char;
    }
    return result;
}
