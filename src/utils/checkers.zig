const std = @import("std");
const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");
const generals_enums = @import("../utils/general_enums.zig");

pub const sep = std.fs.path.sep;

const ValidProject = struct {
    build_zig: bool,
    zon_build_zig: bool,

    fn isValid(self: ValidProject) bool {
        return self.build_zig and self.zon_build_zig;
    }
};

pub fn strEquals(str_a: []const u8, str_b: []const u8) bool {
    return std.mem.eql(u8, str_a, str_b);
}

pub fn cliArgsEquals(arg: []const u8, expected_commands: []const []const u8) bool {
    for (expected_commands) |command| {
        if (strEquals(arg, command)) return true;
    }
    return false;
}

pub fn contains(str_a: []const u8, expected_str: []const u8) bool {
    if (str_a.len < expected_str.len) return false;

    var i: usize = 0;
    while (i <= str_a.len - expected_str.len) : (i += 1) {
        const likely_str = str_a[i .. i + expected_str.len];

        if (strEquals(expected_str, likely_str)) return true;

        var match_reverse = true;
        for (expected_str, 0..) |expected_char, j| {
            if (expected_char != likely_str[likely_str.len - 1 - j]) {
                match_reverse = false;
                break;
            }
        }
        if (match_reverse) return true;
    }
    return false;
}

pub fn isTty() bool {
    return std.posix.isatty(std.io.getStdOut().handle);
}

pub fn isColor(alloc: std.mem.Allocator) bool {
    const is_tty = isTty();
    var color = is_tty;

    const env_no_color = std.process.getEnvVarOwned(alloc, "NO_COLOR") catch null;
    if (env_no_color) |val| {
        defer alloc.free(val);
        color = false;
    }

    return color;
}

pub fn fileExists(dir: std.fs.Dir, file_path: []const u8) bool {
    dir.access(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return false;
        return false;
    };
    return true;
}

pub fn isValidProject(alloc: std.mem.Allocator, dir: std.fs.Dir) !bool {
    var valid_p = ValidProject{ .build_zig = false, .zon_build_zig = false };

    const full_path_dir = try dir.realpathAlloc(alloc, ".");
    defer alloc.free(full_path_dir);

    const build_zig_file = try std.fmt.allocPrint(alloc, "{s}{c}build.zig", .{ full_path_dir, sep });
    defer alloc.free(build_zig_file);

    const zon_build_zig_file = try std.fmt.allocPrint(alloc, "{s}{c}build.zig.zon", .{ full_path_dir, sep });
    defer alloc.free(zon_build_zig_file);

    if (fileExists(dir, build_zig_file)) {
        valid_p.build_zig = true;
    } else return false;

    if (fileExists(dir, zon_build_zig_file)) {
        valid_p.zon_build_zig = true;
    } else return false;

    return valid_p.isValid();
}

pub fn validateDistDirStopIfNot(dir: []const u8, io: generals_enums.Io) !void {
    checkDirRules(dir) catch |err| {
        try comunicateError(err, io);
    };
}

fn comunicateError(err: release_enums.DistDirError, io: generals_enums.Io) !void {
    switch (err) {
        error.Empty => try io.stderr.print("{s}: dist.dir cannot be empty.\n", .{io.error_fmt}),
        error.Dot => try io.stderr.print("{s}: dist.dir cannot be '.' or './'. Choose a subdirectory.\n", .{io.error_fmt}),
        error.AbsolutePath => try io.stderr.print("{s}: dist.dir must be a relative path.\n", .{io.error_fmt}),
        error.Traversal => try io.stderr.print("{s}: dist.dir cannot contain '..' path traversal.\n", .{io.error_fmt}),
        error.ZigOut => try io.stderr.print("{s}: dist.dir cannot be 'zig-out'.\n", .{io.error_fmt}),
        error.TildeNotAllowed => try io.stderr.print("{s}: dist.dir cannot start with '~'.\n", .{io.error_fmt}),
        error.BackslashNotAllowed => try io.stderr.print("{s}: dist.dir cannot contain '\\\\'.\n", .{io.error_fmt}),
        error.InvalidByte => try io.stderr.print("{s}: dist.dir contains invalid characters.\n", .{io.error_fmt}),
    }
    return error.InvalidConfig;
}

fn checkDirRules(dir: []const u8) !void {
    if (dir.len == 0) return error.Empty;
    for (dir) |c| {
        if (c == 0) return error.InvalidByte;
    }
    if (std.mem.eql(u8, dir, ".") or std.mem.eql(u8, dir, "./")) return error.Dot;
    if (dir[0] == '~') return error.TildeNotAllowed;
    if (std.mem.indexOfScalar(u8, dir, '\\') != null) return error.BackslashNotAllowed;
    if (std.fs.path.isAbsolute(dir)) return error.AbsolutePath;
    if (std.mem.eql(u8, dir, "zig-out") or std.mem.eql(u8, dir, "zig-out/")) return error.ZigOut;
    if (containsDotDotSegment(dir)) return error.Traversal;
    if (std.mem.indexOf(u8, dir, "//") != null) return error.InvalidByte;
    if (dir[dir.len - 1] == ' ') return error.InvalidByte;
}

fn containsDotDotSegment(dir: []const u8) bool {
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
