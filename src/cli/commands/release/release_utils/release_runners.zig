const std = @import("std");

const arch = @import("../release.zig");
const checker = @import("./release_checkers.zig");
const fmt = @import("../../../../utils/stdout_formatter.zig");

pub fn compile_and_move(alloc: std.mem.Allocator, architecture: arch.Architectures, out_path: []const u8, bin_name: []const u8, version: []const u8, verbose: bool, i: usize, total: usize, color: bool) !std.process.Child.Term {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const arch_name = architecture.asString();
    const sep = std.fs.path.sep;

    const full = try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ out_path, sep, arch_name });
    defer alloc.free(full);

    if (verbose) {
        try stdout.print("Target: {s}\n", .{arch_name});
        try stdout.print("Out: {s}\n", .{full});
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
        try stdout.print("Running: zig build --prefix {s} {s} -Doptimize=ReleaseSmall\n", .{ temp_prefix, target_arg });
    }

    const prefix_line = try std.fmt.allocPrint(alloc, "[{d}/{d}] {s}", .{ i, total, arch_name });
    defer alloc.free(prefix_line);

    var build_timer = try std.time.Timer.start();
    const term = try run_with_spinner(alloc, &args, prefix_line, verbose);
    const elapsed_ns = build_timer.read();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                const fail = try fmt.red(alloc, "fail", color);
                defer alloc.free(fail);

                try stderr.print("\r{s} {s} (exit {d})\n", .{ prefix_line, fail, code });
                try stderr.print("Out: {s}\n", .{full});
                try stderr.print("Hint: run `zemit -v release` to see the full compiler output.\n", .{});

                return error.CompilationFailed;
            }
        },
        .Signal, .Stopped, .Unknown => {
            const inter = try fmt.red(alloc, "INTERRUPTED", color);
            defer alloc.free(inter);

            try stderr.print("\r{s} {s}\n", .{ prefix_line, inter });
            try stderr.print("Out: {s}\n", .{full});
            try stderr.print("Hint: run `zemit -v release` to see the full compiler output.\n", .{});

            return error.CompilationInterrupted;
        },
    }

    const dur_raw = try fmt.fmt_duration(alloc, elapsed_ns);
    defer alloc.free(dur_raw);

    const dur = try fmt.gray(alloc, dur_raw, color);
    defer alloc.free(dur);

    const ok = try fmt.green(alloc, "ok", color);
    defer alloc.free(ok);

    if (verbose) {
        try stdout.print("Status: {s} {s}\n", .{ ok, dur });
    } else {
        try stdout.print("[{d}/{d}] {s} {s} {s}\n", .{ i, total, arch_name, ok, dur });
    }

    if (verbose) try stdout.print("\n", .{});

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
            try stderr.print("ERROR: Binary not found in {s}\n", .{source_bin});

            const bin_dir_path = try std.fmt.allocPrint(alloc, "{s}{c}bin", .{ temp_prefix, sep });
            defer alloc.free(bin_dir_path);

            var bin_dir = std.fs.cwd().openDir(bin_dir_path, .{ .iterate = true }) catch |err| {
                try stderr.print("ERROR: Unable to open bin directory: {}\n", .{err});
                break :blk false;
            };
            defer bin_dir.close();

            var iter = bin_dir.iterate();
            while (try iter.next()) |entry| {
                try stderr.print("  - {s}\n", .{entry.name});
            }

            break :blk false;
        };
        break :blk true;
    };

    if (!source_exists) {
        return error.FileNotFound;
    }

    const dest_bin = try std.fmt.allocPrint(alloc, "{s}{c}{s}-{s}-{s}{s}", .{ dist_arch_dir, sep, bin_name, version, arch_name, bin_extension });
    defer alloc.free(dest_bin);

    std.fs.cwd().copyFile(source_bin, std.fs.cwd(), dest_bin, .{}) catch |err| {
        try stderr.print("ERROR: Failed to copy file: {}\n", .{err});
        return err;
    };

    std.fs.cwd().deleteTree(temp_prefix) catch |err| {
        try stderr.print("WARN: Unable to remove temporary directory: {}\n", .{err});
    };

    return term;
}

fn run_with_spinner(
    alloc: std.mem.Allocator,
    argv: []const []const u8,
    prefix_line: []const u8,
    verbose: bool,
) !std.process.Child.Term {
    var child = std.process.Child.init(argv, alloc);

    child.stdout_behavior = .Inherit;
    child.stderr_behavior = if (verbose) .Inherit else .Ignore;

    const animate = (!verbose) and checker.is_TTY();

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
    const stdout = std.io.getStdOut().writer();

    const frames = [_][]const u8{ ".", "..", "..." };
    var idx: usize = 0;

    const delay_ns: u64 = 450_000_000;

    while (state.running.load(.acquire)) {
        stdout.print("\r\x1b[2K{s} {s}", .{ prefix_line, frames[idx] }) catch {};
        idx = (idx + 1) % frames.len;
        std.time.sleep(delay_ns);
    }

    stdout.print("\r\x1b[2K", .{}) catch {};
}
