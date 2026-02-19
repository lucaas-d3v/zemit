const std = @import("std");

// internals
const utils = @import("../../../../utils/checkers.zig");

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
