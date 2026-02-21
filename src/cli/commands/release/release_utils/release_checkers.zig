const std = @import("std");

// internals
const utils = @import("../../../../utils/checkers.zig");
const release_enums = @import("./release_enums.zig");

const ValidProject = struct {
    build_zig: bool,
    zon_build_zig: bool,

    fn is_valid(self: ValidProject) bool {
        return self.build_zig and self.zon_build_zig;
    }
};

pub fn is_valid_project(alloc: std.mem.Allocator, dir: std.fs.Dir) !bool {
    const stdout = std.io.getStdOut().writer();

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

    if (utils.file_exists(dir, build_zig_file)) {
        valid_p.build_zig = true;
    } else {
        try stdout.print("Info: build.zig não encontrado em {s}\n", .{full_path_dir});
        return false;
    }

    if (utils.file_exists(dir, zon_build_zig_file)) {
        valid_p.zon_build_zig = true;
    } else {
        try stdout.print("Info: build.zig.zon não encontrado.\n", .{});
        return false;
    }

    return valid_p.is_valid();
}

pub fn validate_dist_dir(dir: []const u8) release_enums.DistDirError!void {
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
    if (containsDotDotSegment(dir)) return error.Traversal;

    if (std.mem.indexOf(u8, dir, "//") != null) return error.InvalidByte;

    if (dir[dir.len - 1] == ' ') return error.InvalidByte;
}

fn containsDotDotSegment(dir: []const u8) bool {
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
