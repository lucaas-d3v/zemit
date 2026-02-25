const std = @import("std");
const hash = std.crypto.hash.sha2;

const arch = @import("../release.zig");
const checker = @import("../../../../utils/checkers.zig");
const fmt = @import("../../../../utils/stdout_formatter.zig");
const utils = @import("../../../../utils/checkers.zig");

const release_enums = @import("./release_enums.zig");
const generals_enums = @import("../../../../utils/general_enums.zig");

pub const parser = @import("../../../../customization/name_template_parser.zig");
const config = @import("../../../../customization/config_reader.zig");

// internal state for the compilation progress spinner
const SpinnerState = struct {
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
};

// orchestrates the compilation, progress reporting, and final binary relocation
pub fn compile_and_move(
    release_ctx: *release_enums.ReleaseCtx,
    io: *generals_enums.Io,
    i: usize,
) !std.process.Child.Term {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const arch_name = release_ctx.architecture.asString();
    const sep = std.fs.path.sep;

    const full = try std.fmt.allocPrint(release_ctx.alloc, "{s}{c}{s}-{s}-{s}", .{ release_ctx.out_path, sep, release_ctx.bin_name, release_ctx.version, arch_name });
    defer release_ctx.alloc.free(full);

    release_ctx.full_path = full;

    if (release_ctx.verbose) {
        try stdout.print("Layout: {s}\n", .{release_ctx.layout.getName()});
        try stdout.print("Target: {s}\n", .{arch_name});
        try stdout.print("Out: {s}\n", .{full});
    }

    const temp_prefix = try prepare_temp_prefix(release_ctx.alloc, arch_name);
    defer release_ctx.alloc.free(temp_prefix);

    try prepare_temp_dir(temp_prefix);

    var argv_bundle = try build_argv(release_ctx, temp_prefix, arch_name);
    defer argv_bundle.deinit();

    const full_argv = argv_bundle.args.items;

    if (release_ctx.verbose) {
        try stdout.print("Running: ", .{});

        for (full_argv) |arg| {
            try stdout.print("{s} ", .{arg});
        }

        try stdout.print("\n", .{});
    }

    const prefix_line = try std.fmt.allocPrint(release_ctx.alloc, "[{d}/{d}] {s}", .{ i, release_ctx.total, arch_name });
    defer release_ctx.alloc.free(prefix_line);

    var build_timer = try std.time.Timer.start();
    const term = try run_build(release_ctx, prefix_line, full_argv, stderr.any(), full);
    const elapsed_ns = build_timer.read();

    const dur = try fmt.fmt_duration(release_ctx, elapsed_ns);
    defer release_ctx.alloc.free(dur);

    // generate hash and write in checksums_builder

    if (release_ctx.verbose) {
        try stdout.print("Status: {s} {s}\n", .{ io.ok_fmt, dur });
    } else {
        try stdout.print("[{d}/{d}] {s} {s} {s}\n", .{ i, release_ctx.total, arch_name, io.ok_fmt, dur });
    }

    if (release_ctx.verbose) try stdout.print("\n", .{});

    const dist_arch_dir = if (release_ctx.layout == release_enums.ReleaseLayout.BY_TARGET)
        try std.fmt.allocPrint(release_ctx.alloc, "{s}{c}{s}", .{ release_ctx.out_path, sep, arch_name })
    else
        try release_ctx.alloc.dupe(u8, release_ctx.out_path);

    defer release_ctx.alloc.free(dist_arch_dir);

    if (release_ctx.layout == release_enums.ReleaseLayout.BY_TARGET) {
        std.fs.cwd().makePath(dist_arch_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => {
                return err;
            },
        };
    }

    const bin_extension = switch (release_ctx.architecture) {
        .x86_64_windows_gnu, .x86_64_windows_msvc => ".exe",
        else => "",
    };

    var io_ctx = release_enums.IoCtx{
        .ok_fmt = io.ok_fmt,
        .warn_fmt = io.warn_fmt,
        .error_fmt = io.error_fmt,

        .source_bin = "",

        .stderr = stderr.any(),
        .sep = sep,
        .temp_prefix = temp_prefix,
        .dest_bin = "",
    };

    const source_bin = try get_source_bin(release_ctx, temp_prefix, bin_extension, sep);
    defer release_ctx.alloc.free(source_bin);
    io_ctx.source_bin = source_bin;

    const ctx = parser.Context{
        .bin = release_ctx.bin_name,
        .version = release_ctx.version,
        .ext = bin_extension,
        .target = arch_name,
    };

    const parsed_filename = try parser.format_binary_name(release_ctx.alloc, release_ctx.name_tamplate, ctx, io_ctx);
    defer release_ctx.alloc.free(parsed_filename);

    const full_dest_path = try std.fs.path.join(release_ctx.alloc, &[_][]const u8{
        dist_arch_dir,
        parsed_filename,
    });
    defer release_ctx.alloc.free(full_dest_path);

    io_ctx.dest_bin = full_dest_path;

    try move_and_delete_temp_dir(io_ctx);

    return term;
}

// creates a formatted string for the temporary build output directory
pub fn prepare_temp_prefix(alloc: std.mem.Allocator, arch_name: []const u8) ![]const u8 {
    const temp_prefix = try std.fmt.allocPrint(alloc, "zig-out-{s}", .{arch_name});
    errdefer alloc.free(temp_prefix);

    return temp_prefix;
}

// ensures the temporary directory exists on the filesystem
pub fn prepare_temp_dir(temp_prefix: []const u8) !void {
    std.fs.cwd().makePath(temp_prefix) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            return err;
        },
    };
}

// constructs the zig build command arguments based on context and target
fn build_argv(
    release_ctx: *release_enums.ReleaseCtx,
    temp_prefix: []const u8,
    arch_name: []const u8,
) !release_enums.ArgvBundle {
    var b = release_enums.ArgvBundle.init(release_ctx.alloc);
    errdefer b.deinit();

    const target_arg = try b.ownFmt("-Dtarget={s}", .{arch_name});
    const d_optimize_fmt = try b.ownFmt("-Doptimize={s}", .{release_ctx.d_optimize});

    try b.args.append("zig");
    try b.args.append("build");
    try b.args.append("--prefix");
    try b.args.append(temp_prefix);
    try b.args.append(target_arg);
    try b.args.append(d_optimize_fmt);

    try b.args.appendSlice(release_ctx.zig_args);

    return b;
}

// handles the execution of the build command and validates the process exit status
fn run_build(release_ctx: *release_enums.ReleaseCtx, prefix_line: []const u8, full_argv: []const []const u8, stderr: std.io.AnyWriter, full: []const u8) !std.process.Child.Term {
    const term = try run_with_spinner(release_ctx, prefix_line, full_argv, release_ctx.color);

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                const fail = try fmt.red(release_ctx.alloc, "fail", release_ctx.color);
                defer release_ctx.alloc.free(fail);

                try stderr.print("\r{s} {s} (exit {d})\n", .{ prefix_line, fail, code });
                try stderr.print("Out: {s}\n", .{full});
                try stderr.print("Hint: run `zemit -v release` to see the full compiler output.\n", .{});

                return error.CompilationFailed;
            }
        },
        .Signal, .Stopped, .Unknown => {
            const inter = try fmt.red(release_ctx.alloc, "INTERRUPTED", release_ctx.color);
            defer release_ctx.alloc.free(inter);

            try stderr.print("\r{s} {s}\n", .{ prefix_line, inter });
            try stderr.print("Out: {s}\n", .{full});
            try stderr.print("Hint: run `zemit -v release` to see the full compiler output.\n", .{});

            return error.CompilationInterrupted;
        },
    }

    return term;
}

// runs the compilation process while displaying an animated spinner in the terminal
fn run_with_spinner(release_ctx: *release_enums.ReleaseCtx, prefix_line: []const u8, argv: []const []const u8, color: bool) !std.process.Child.Term {
    var child = std.process.Child.init(argv, release_ctx.alloc);

    child.stdout_behavior = .Inherit;
    child.stderr_behavior = if (release_ctx.verbose) .Inherit else .Ignore;

    const animate = (!release_ctx.verbose) and utils.is_TTY();

    try child.spawn();

    if (!animate) {
        return child.wait();
    }

    const state = try release_ctx.alloc.create(SpinnerState);
    state.* = SpinnerState{};
    defer release_ctx.alloc.destroy(state);

    var spinner = try std.Thread.spawn(.{}, spinnerThread, .{ state, prefix_line, color });

    const term = try child.wait();
    state.running.store(false, .release);

    spinner.join();
    return term;
}

// background thread function that renders the spinner animation frames
fn spinnerThread(
    state: *SpinnerState,
    prefix_line: []const u8,
    color: bool,
) void {
    const stdout = std.io.getStdOut().writer();

    const frames: []const []const u8 = if (color)
        &[_][]const u8{ "\x1b[35m.\x1b[0m", "\x1b[35m..\x1b[0m", "\x1b[35m...\x1b[0m" }
    else
        &[_][]const u8{ ".", "..", "..." };

    var idx: usize = 0;

    const delay_ns: u64 = 450_000_000;

    while (state.running.load(.acquire)) {
        stdout.print("\r\x1b[2K{s} {s}", .{ prefix_line, frames[idx] }) catch {};
        idx = (idx + 1) % frames.len;
        std.time.sleep(delay_ns);
    }

    stdout.print("\r\x1b[2K", .{}) catch {};
}

// returns the path to the expected binary after a successful zig build
pub fn get_source_bin(release_ctx: *release_enums.ReleaseCtx, temp_prefix: []const u8, bin_extension: []const u8, sep: u8) ![]const u8 {
    const source_bin = try std.fmt.allocPrint(release_ctx.alloc, "{s}{c}bin{c}{s}{s}", .{ temp_prefix, sep, sep, release_ctx.bin_name, bin_extension });
    errdefer release_ctx.alloc.free(source_bin);

    return source_bin;
}

// verifies if the source binary exists and lists the directory content on failure
pub fn ensure_source_exists_or_list_bin_dir(release_ctx: *release_enums.ReleaseCtx, io_ctx: release_enums.IoCtx) !bool {
    const ERROR = try fmt.red(release_ctx.alloc, "ERROR", release_ctx.color);
    defer release_ctx.alloc.free(ERROR);

    const source_exists = blk: {
        std.fs.cwd().access(io_ctx.source_bin, .{}) catch {
            try io_ctx.stderr.print("{s}: Binary not found in {s}\n", .{ ERROR, io_ctx.source_bin });

            const bin_dir_path = try std.fmt.allocPrint(release_ctx.alloc, "{s}{c}bin", .{ io_ctx.temp_prefix, io_ctx.sep });
            defer release_ctx.alloc.free(bin_dir_path);

            var bin_dir = std.fs.cwd().openDir(bin_dir_path, .{ .iterate = true }) catch |err| {
                try io_ctx.stderr.print("{s}: Unable to open bin directory: {}\n", .{ ERROR, err });
                break :blk false;
            };
            defer bin_dir.close();

            var iter = bin_dir.iterate();
            while (try iter.next()) |entry| {
                try io_ctx.stderr.print("  - {s}\n", .{entry.name});
            }

            break :blk false;
        };
        break :blk true;
    };

    return source_exists;
}

// copies the compiled binary to the destination and removes temporary build artifacts
pub fn move_and_delete_temp_dir(io_ctx: release_enums.IoCtx) !void {
    std.fs.cwd().copyFile(io_ctx.source_bin, std.fs.cwd(), io_ctx.dest_bin, .{}) catch |err| {
        try io_ctx.stderr.print("{s}: Failed to copy file: {}\n", .{ io_ctx.error_fmt, err });
        return err;
    };

    std.fs.cwd().deleteTree(io_ctx.temp_prefix) catch |err| {
        try io_ctx.stderr.print("{s}: Unable to remove temporary directory: {}\n", .{ io_ctx.warn_fmt, err });
    };
}

pub fn write_checksums_content_of(alloc: std.mem.Allocator, sub_path: []const u8, files: *std.fs.Dir.Walker, checksums: release_enums.ChecksumsCtx) !void {
    const is_sha256 = std.mem.eql(u8, checksums.checksums.algorithm, "sha256");
    const is_sha512 = std.mem.eql(u8, checksums.checksums.algorithm, "sha512");

    while (try files.next()) |entry| {
        if (entry.kind != .file) {
            continue;
        }

        const file = try entry.dir.openFile(entry.basename, .{});
        defer file.close();

        var buffer: [4096]u8 = undefined;

        if (is_sha256) {
            var hasher = hash.Sha256.init(.{});

            while (true) {
                const bytes_read = try file.read(&buffer);
                if (bytes_read == 0) break;
                hasher.update(buffer[0..bytes_read]);
            }

            var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
            hasher.final(&digest);

            try format_and_write(alloc, &digest, entry.basename, checksums);
        } else if (is_sha512) {
            var hasher = hash.Sha512.init(.{});

            while (true) {
                const bytes_read = try file.read(&buffer);
                if (bytes_read == 0) break;
                hasher.update(buffer[0..bytes_read]);
            }

            var digest: [std.crypto.hash.sha2.Sha512.digest_length]u8 = undefined;
            hasher.final(&digest);

            try format_and_write(alloc, &digest, entry.basename, checksums);
        }
    }

    try save_file(alloc, sub_path, checksums);
}

fn format_and_write(alloc: std.mem.Allocator, digest: []const u8, file_name: []const u8, checksums: release_enums.ChecksumsCtx) !void {
    const content = try std.fmt.allocPrint(alloc, "{s} {s}\n", .{ std.fmt.fmtSliceHexLower(digest), std.fs.path.basename(file_name) });
    defer alloc.free(content);

    _ = try checksums.checksums_writer.write(content);
}

fn save_file(alloc: std.mem.Allocator, sub_path: []const u8, checksums: release_enums.ChecksumsCtx) !void {
    const out_path = try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ sub_path, std.fs.path.sep, checksums.checksums.file });
    defer alloc.free(out_path);

    const out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();

    try out_file.writeAll(checksums.checksums_builder.items);
    try out_file.writeAll("\n");
}
