const std = @import("std");
const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");
const fmt = @import("../utils/stdout_formatter.zig");

pub const sep = std.fs.path.sep;

// helper structure to verify if a directory contains a valid zig project
const ValidProject = struct {
    build_zig: bool,
    zon_build_zig: bool,

    fn is_valid(self: ValidProject) bool {
        return self.build_zig and self.zon_build_zig;
    }
};

// --- String Helpers ---

// compares two byte slices for equality
pub fn str_equals(str_a: []const u8, str_b: []const u8) bool {
    return std.mem.eql(u8, str_a, str_b);
}

// checks if a command-line argument matches any of the expected command strings
pub fn cli_args_equals(arg: []const u8, expected_commands: []const []const u8) bool {
    for (expected_commands) |command| {
        if (str_equals(arg, command)) {
            return true;
        }
    }
    return false;
}

// checks if a string contains a specific substring, including a reverse check
pub fn contais(allocator: std.mem.Allocator, str_a: []const u8, expected_str: []const u8) !bool {
    if (str_a.len < expected_str.len) return false;

    var i: usize = 0;
    while (i <= str_a.len - expected_str.len) : (i += 1) {
        const likely_str = str_a[i .. i + expected_str.len];

        if (str_equals(expected_str, likely_str)) return true;

        const inverted = try reverse_str(allocator, likely_str);
        defer allocator.free(inverted);

        if (str_equals(expected_str, inverted)) return true;
    }

    return false;
}

// creates a new string with the characters in reverse order
fn reverse_str(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, input.len);
    for (input, 0..) |char, i| {
        result[input.len - 1 - i] = char;
    }
    return result;
}

// --- System & Terminal ---

// checks if the current stdout is a terminal (TTY)
pub fn is_TTY() bool {
    return std.posix.isatty(std.io.getStdOut().handle);
}

// determines if color output should be enabled based on TTY and environment variables
pub fn is_color(alloc: std.mem.Allocator) bool {
    const is_tty = is_TTY();
    var color = is_tty;

    const env_no_color = std.process.getEnvVarOwned(alloc, "NO_COLOR") catch null;
    if (env_no_color) |val| {
        defer alloc.free(val);
        color = false;
    }

    return color;
}

// checks if a file exists within a given directory
pub fn file_exists(dir: std.fs.Dir, file_path: []const u8) bool {
    dir.access(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return false;
        return false;
    };
    return true;
}

// --- Project Validation ---

// verifies if the current directory is a valid zig project (has build.zig and build.zig.zon)
pub fn is_valid_project(alloc: std.mem.Allocator, dir: std.fs.Dir) !bool {
    var valid_p = ValidProject{
        .build_zig = false,
        .zon_build_zig = false,
    };

    const full_path_dir = try dir.realpathAlloc(alloc, ".");
    defer alloc.free(full_path_dir);

    const build_zig_file = try std.fmt.allocPrint(alloc, "{s}{c}build.zig", .{ full_path_dir, sep });
    defer alloc.free(build_zig_file);

    const zon_build_zig_file = try std.fmt.allocPrint(alloc, "{s}{c}build.zig.zon", .{ full_path_dir, sep });
    defer alloc.free(zon_build_zig_file);

    if (file_exists(dir, build_zig_file)) {
        valid_p.build_zig = true;
    } else {
        return false;
    }

    if (file_exists(dir, zon_build_zig_file)) {
        valid_p.zon_build_zig = true;
    } else {
        return false;
    }

    return valid_p.is_valid();
}

// maps a string to a ReleaseLayout enum
pub fn to_release_layout(layout: []const u8, stderr: std.io.AnyWriter, error_fmt: []const u8) !release_enums.ReleaseLayout {
    if (str_equals(layout, "by_target")) return release_enums.ReleaseLayout.BY_TARGET;
    if (str_equals(layout, "flat")) return release_enums.ReleaseLayout.FLAT;

    try stderr.print("{s}: Unknown layout '{s}'.\nCheck your zemit.toml.\n", .{ error_fmt, layout });
    return release_enums.ReleaseLayout.none;
}

// --- Path Safety & Rules ---

// validates the distribution directory and reports errors if rules are violated
pub fn validate_dist_dir_stop_if_not(alloc: std.mem.Allocator, dir: []const u8, stderr: std.io.AnyWriter, color: bool) !void {
    check_dir_rules(dir) catch |err| {
        try comunicate_error(alloc, err, stderr, color);
    };
}

// prints specific error messages for directory validation failures
fn comunicate_error(alloc: std.mem.Allocator, err: release_enums.DistDirError, stderr: std.io.AnyWriter, color: bool) !void {
    const error_fmt = try fmt.red(alloc, "ERROR", color);
    defer alloc.free(error_fmt);

    switch (err) {
        error.Empty => try stderr.print("{s}: dist.dir cannot be empty.\n", .{error_fmt}),
        error.Dot => try stderr.print("{s}: dist.dir cannot be '.' or './'. Choose a subdirectory.\n", .{error_fmt}),
        error.AbsolutePath => try stderr.print("{s}: dist.dir must be a relative path.\n", .{error_fmt}),
        error.Traversal => try stderr.print("{s}: dist.dir cannot contain '..' path traversal.\n", .{error_fmt}),
        error.ZigOut => try stderr.print("{s}: dist.dir cannot be 'zig-out'.\n", .{error_fmt}),
        error.TildeNotAllowed => try stderr.print("{s}: dist.dir cannot start with '~'.\n", .{error_fmt}),
        error.BackslashNotAllowed => try stderr.print("{s}: dist.dir cannot contain '\\\\'.\n", .{error_fmt}),
        error.InvalidByte => try stderr.print("{s}: dist.dir contains invalid characters.\n", .{error_fmt}),
    }
    return error.InvalidConfig;
}

// applies security and formatting rules to a directory path string
fn check_dir_rules(dir: []const u8) !void {
    if (dir.len == 0) return error.Empty;

    for (dir) |c| {
        if (c == 0) return error.InvalidByte;
    }

    if (std.mem.eql(u8, dir, ".") or std.mem.eql(u8, dir, "./")) return error.Dot;
    if (dir[0] == '~') return error.TildeNotAllowed;
    if (std.mem.indexOfScalar(u8, dir, '\\') != null) return error.BackslashNotAllowed;
    if (std.fs.path.isAbsolute(dir)) return error.AbsolutePath;
    if (std.mem.eql(u8, dir, "zig-out") or std.mem.eql(u8, dir, "zig-out/")) return error.ZigOut;

    if (contains_dot_dot_segment(dir)) return error.Traversal;
    if (std.mem.indexOf(u8, dir, "//") != null) return error.InvalidByte;
    if (dir[dir.len - 1] == ' ') return error.InvalidByte;
}

// detects illegal ".." segments in a path to prevent directory traversal
fn contains_dot_dot_segment(dir: []const u8) bool {
    var start: usize = 0;
    while (start <= dir.len) {
        const next = std.mem.indexOfScalarPos(u8, dir, start, sep) orelse dir.len;
        const seg = dir[start..next];

        if (seg.len == 2 and seg[0] == '.' and seg[1] == '.') return true;

        if (next == dir.len) break;
        start = next + 1;
    }
    return false;
}
