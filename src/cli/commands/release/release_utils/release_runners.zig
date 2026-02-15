const std = @import("std");
const print = std.debug.print;

const arch = @import("../release.zig");

pub fn compile_and_move(alloc: std.mem.Allocator, architecture: arch.Architectures, out_path: []const u8, bin_name: []const u8, verbose: bool, i: usize, total: usize) !std.process.Child.Term {
    const arch_name = architecture.asString();
    const sep = std.fs.path.sep;

    const full = try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ out_path, sep, arch_name });
    defer alloc.free(full);

    if (verbose) {
        print("Target: {s}\n", .{arch_name});
        print("Out: {s}\n", .{full});
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
        print("Running: zig build --prefix {s} {s} -Doptimize=ReleaseSmall\n", .{ temp_prefix, target_arg });
    }

    const prefix_line = try std.fmt.allocPrint(alloc, "[{d}/{d}] {s}", .{ i, total, arch_name });
    defer alloc.free(prefix_line);

    var build_timer = try std.time.Timer.start();
    const term = try run_with_spinner(alloc, &args, prefix_line, verbose);
    const elapsed_ns = build_timer.read();

    const elapsed_s: f64 = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                print("\r{s} fail (exit {d})\n", .{ prefix_line, code });
                print("Out: {s}\n", .{full});
                print("Hint: run `zemit -v release` to see the full compiler output.\n", .{});

                return error.CompilationFailed;
            }
        },

        .Signal, .Stopped, .Unknown => {
            print("\r{s} INTERRUPTED\n", .{prefix_line});
            print("Out: {s}\n", .{full});
            print("Hint: run `zemit -v release` to see the full compiler output.\n", .{});

            return error.CompilationInterrupted;
        },
    }
    if (verbose) {
        print("Status: ok ({d:.2}s)\n", .{elapsed_s});
    } else {
        print("[{d}/{d}] {s} ok ({d:.2}s)\n", .{ i, total, arch_name, elapsed_s });
    }

    if (verbose) print("\n", .{});

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
            print("ERROR: Binary not found in {s}\n", .{source_bin});

            const bin_dir_path = try std.fmt.allocPrint(alloc, "{s}{c}bin", .{ temp_prefix, sep });
            defer alloc.free(bin_dir_path);

            var bin_dir = std.fs.cwd().openDir(bin_dir_path, .{ .iterate = true }) catch |err| {
                print("ERROR: Unable to open bin directory: {}\n", .{err});
                break :blk false;
            };
            defer bin_dir.close();

            var iter = bin_dir.iterate();
            while (try iter.next()) |entry| {
                print("  - {s}\n", .{entry.name});
            }

            break :blk false;
        };
        break :blk true;
    };

    if (!source_exists) {
        return error.FileNotFound;
    }

    const dest_bin = try std.fmt.allocPrint(alloc, "{s}{c}{s}-{s}{s}", .{ dist_arch_dir, sep, bin_name, arch_name, bin_extension });
    defer alloc.free(dest_bin);

    std.fs.cwd().copyFile(source_bin, std.fs.cwd(), dest_bin, .{}) catch |err| {
        print("ERROR: Failed to copy file: {}\n", .{err});
        return err;
    };

    std.fs.cwd().deleteTree(temp_prefix) catch |err| {
        print("WARN: Unable to remove temporary directory: {}\n", .{err});
    };

    return term;
}

// utilitys
fn is_TTY() bool {
    return std.posix.isatty(std.io.getStdOut().handle);
}

fn run_with_spinner(
    alloc: std.mem.Allocator,
    argv: []const []const u8,
    prefix_line: []const u8,
    verbose: bool,
) !std.process.Child.Term {
    var child = std.process.Child.init(argv, alloc);

    if (verbose) {
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;
    } else {
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
    }

    const animate = (!verbose) and is_TTY();

    try child.spawn();

    if (!animate) {
        return child.wait();
    }

    var state = SpinnerState{};
    var spinner = try std.Thread.spawn(.{}, spinnerThread, .{ &state, prefix_line });
    defer spinner.join();

    const term = try child.wait();

    state.running.store(false, .release);

    return term;
}

const SpinnerState = struct {
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
};

fn spinnerThread(
    state: *SpinnerState,
    prefix_line: []const u8,
) void {
    const frames = [_][]const u8{ ".", "..", "..." };
    var idx: usize = 0;

    const delay_ns: u64 = 500_000_000;

    while (state.running.load(.acquire)) {
        print("\r{s} {s}  ", .{ prefix_line, frames[idx] });
        idx = (idx + 1) % frames.len;
        std.time.sleep(delay_ns);
    }

    print("\r{s}    \r", .{prefix_line});
}
