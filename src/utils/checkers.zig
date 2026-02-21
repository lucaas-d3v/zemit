const std = @import("std");

const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");
const fmt = @import("../utils/stdout_formatter.zig");

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

fn reverse_str(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, input.len);

    for (input, 0..) |char, i| {
        result[input.len - 1 - i] = char;
    }
    return result;
}

const ValidProject = struct {
    build_zig: bool,
    zon_build_zig: bool,

    fn is_valid(self: ValidProject) bool {
        return self.build_zig and self.zon_build_zig;
    }
};

pub fn is_valid_project(alloc: std.mem.Allocator, dir: std.fs.Dir) !bool {
    var valid_p = ValidProject{
        .build_zig = false,
        .zon_build_zig = false,
    };

    const full_path_dir = try dir.realpathAlloc(alloc, ".");
    defer alloc.free(full_path_dir);

    const sep = std.fs.path.sep;

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

pub fn validate_dist_dir_stop_if_not(alloc: std.mem.Allocator, dir: []const u8, stderr: std.io.AnyWriter, color: bool) !void {
    check_dir_rules(dir) catch |err| {
        try comunicate_error(alloc, err, stderr, color);
    };
}

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
    // Retorna um erro genérico após logar a mensagem específica
    return error.InvalidConfig;
}

fn check_dir_rules(dir: []const u8) !void {
    if (dir.len == 0) return error.Empty;

    // block NUL and weird bytes that can mess with OS APIs/logs
    for (dir) |c| {
        if (c == 0) return error.InvalidByte;
    }

    // common "current directory" forms
    if (std.mem.eql(u8, dir, ".") or std.mem.eql(u8, dir, "./")) return error.Dot;

    // reject "~" expansions (CLI tools shouldn't silently depend on shell expansion rules)
    if (dir[0] == '~') return error.TildeNotAllowed;

    // reject backslashes to avoid Windows-style confusion on *nix and path spoofing
    if (std.mem.indexOfScalar(u8, dir, '\\') != null) return error.BackslashNotAllowed;

    // absolute paths are dangerous for "clean" command
    if (std.fs.path.isAbsolute(dir)) return error.AbsolutePath;

    // normalize "zig-out" and "zig-out/" special case (your tool uses zig-out internally)
    if (std.mem.eql(u8, dir, "zig-out") or std.mem.eql(u8, dir, "zig-out/")) return error.ZigOut;

    // block any parent traversal:
    // - ".."
    // - "../x"
    // - "x/.."
    // - "x/../y"
    if (contains_dot_dot_segment(dir)) return error.Traversal;

    if (std.mem.indexOf(u8, dir, "//") != null) return error.InvalidByte;

    if (dir[dir.len - 1] == ' ') return error.InvalidByte;
}

fn contains_dot_dot_segment(dir: []const u8) bool {
    const sep = std.fs.path.sep;
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

pub fn to_release_layout(layout: []const u8) release_enums.ReleaseLayout {
    if (str_equals(layout, "by_target")) return release_enums.ReleaseLayout.BY_TARGET;
    if (str_equals(layout, "flat")) return release_enums.ReleaseLayout.FLAT;

    return release_enums.ReleaseLayout.none;
}
