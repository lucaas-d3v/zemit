const std = @import("std");
const arch = @import("../release.zig");

pub fn compile_and_move(alloc: std.mem.Allocator, architecture: arch.Architectures, out_path: []const u8, bin_name: []const u8, verbose: bool) !std.process.Child.Term {
    const arch_name = architecture.asString();
    const sep = std.fs.path.sep;

    const full = try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ out_path, sep, arch_name });
    defer alloc.free(full);

    if (verbose) {
        std.debug.print("Target: {s}\n", .{arch_name});
        std.debug.print("Out: {s}\n", .{full});
    }

    const temp_prefix = try std.fmt.allocPrint(alloc, "zig-out-{s}", .{arch_name});
    defer alloc.free(temp_prefix);

    std.fs.cwd().makePath(temp_prefix) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            return err;
        },
    };

    const target_arg = try std.fmt.allocPrint(alloc, "-Dtarget={s}", .{arch_name});
    defer alloc.free(target_arg);

    const args = [_][]const u8{
        "zig",
        "build",
        "--prefix",
        temp_prefix,
        target_arg,
        "-Doptimize=ReleaseSmall",
    };

    if (verbose) {
        std.debug.print("Running: zig build --prefix {s} {s} -Doptimize=ReleaseSmall\n", .{ temp_prefix, target_arg });
    }

    var child = std.process.Child.init(&args, alloc);

    if (verbose) {
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
    } else {
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
    }

    var build_timer = try std.time.Timer.start();
    const term = try child.spawnAndWait();
    const elapsed_ns = build_timer.read();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("\nERROR: build failed for {s}. Run: zemit -v release\n", .{arch_name});
                std.debug.print("Out: {s}\n", .{full});
                std.debug.print("Hint: run `zemit -v release` to see the full zig build output.\n", .{});

                return error.CompilationFailed;
            }
        },
        else => {
            return error.CompilationFailed;
        },
    }

    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    std.debug.print("[{s}] ok ({d:.2}s)\n", .{ arch_name, elapsed_s });

    if (verbose) std.debug.print("\n", .{});

    const dist_arch_dir = try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ out_path, sep, arch_name });
    defer alloc.free(dist_arch_dir);

    std.fs.cwd().makePath(dist_arch_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            return err;
        },
    };

    const bin_extension = switch (architecture) {
        .x86_64_windows_gnu, .x86_64_windows_msvc => ".exe",
        else => "",
    };
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
