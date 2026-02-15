const std = @import("std");
const arch = @import("../release.zig");

pub fn compile_and_move(alloc: std.mem.Allocator, architecture: arch.Architectures, out_path: []const u8, bin_name: []const u8) !std.process.Child.Term {
    std.debug.print("Compiling for: {s}\n", .{out_path});

    const temp_prefix = try std.fmt.allocPrint(alloc, "zig-out-{s}", .{architecture.asString()});
    defer alloc.free(temp_prefix);

    std.fs.cwd().makePath(temp_prefix) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            return err;
        },
    };

    const target_arg = try std.fmt.allocPrint(alloc, "-Dtarget={s}", .{architecture.asString()});
    defer alloc.free(target_arg);

    const args = [_][]const u8{
        "zig",
        "build",
        "--prefix",
        temp_prefix,
        target_arg,
        "-Doptimize=ReleaseSmall",
    };

    std.debug.print("Running: zig build --prefix {s} {s} -Doptimize=ReleaseSmall\n", .{ temp_prefix, target_arg });
    var child = std.process.Child.init(&args, alloc);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                return error.CompilationFailed;
            }
        },
        else => {
            return error.CompilationFailed;
        },
    }

    std.debug.print("✓ Compilation completed successfully!\n", .{});
    const arch_name = architecture.asString();
    const sep = std.fs.path.sep;

    const dist_arch_dir = try std.fmt.allocPrint(alloc, ".zemit{c}dist{c}{s}", .{ sep, sep, arch_name });
    defer alloc.free(dist_arch_dir);

    std.fs.cwd().makePath(dist_arch_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            return err;
        },
    };

    const bin_extension = if (std.mem.indexOf(u8, arch_name, "windows") != null) ".exe" else "";
    const source_bin = try std.fmt.allocPrint(alloc, "{s}{c}bin{c}{s}{s}", .{ temp_prefix, sep, sep, bin_name, bin_extension });
    defer alloc.free(source_bin);

    const source_exists = blk: {
        std.fs.cwd().access(source_bin, .{}) catch {
            std.debug.print("ERROR: Binary not found in {s}\n", .{source_bin});

            const bin_dir_path = try std.fmt.allocPrint(alloc, "{s}{c}bin", .{ temp_prefix, sep });
            defer alloc.free(bin_dir_path);

            var bin_dir = std.fs.cwd().openDir(bin_dir_path, .{ .iterate = true }) catch |err| {
                std.debug.print("ERROR: Unable to open bin directory: {}\n", .{err});
                break :blk false;
            };
            defer bin_dir.close();

            var iter = bin_dir.iterate();
            while (try iter.next()) |entry| {
                std.debug.print("  - {s}\n", .{entry.name});
            }

            break :blk false;
        };
        break :blk true;
    };

    if (!source_exists) {
        return error.FileNotFound;
    }

    const dest_bin = try std.fmt.allocPrint(alloc, "{s}{c}{s}{s}", .{ dist_arch_dir, sep, bin_name, bin_extension });
    defer alloc.free(dest_bin);

    std.fs.cwd().copyFile(source_bin, std.fs.cwd(), dest_bin, .{}) catch |err| {
        std.debug.print("ERROR: Failed to copy file: {}\n", .{err});
        return err;
    };

    std.fs.cwd().deleteTree(temp_prefix) catch |err| {
        std.debug.print("WARN: Unable to remove temporary directory: {}\n", .{err});
    };

    return term;
}
