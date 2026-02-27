const std = @import("std");
const hash = std.crypto.hash.sha2;
const fmt = @import("../../../../utils/stdout_formatter.zig");
const utils = @import("../../../../utils/checkers.zig");
const release_enums = @import("./release_enums.zig");
const generals_enums = @import("../../../../utils/general_enums.zig");
pub const parser = @import("../../../../customization/name_template_parser.zig");
const config = @import("../../../../customization/config_reader.zig");

const SpinnerState = struct {
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
};

pub fn compileAndMove(release_ctx: *release_enums.ReleaseCtx, io: generals_enums.Io, global_flags: generals_enums.GlobalFlags, i: usize) !std.process.Child.Term {
    const arch_name = release_ctx.architecture.asString();
    const sep = std.fs.path.sep;

    const full = try std.fmt.allocPrint(release_ctx.alloc, "{s}{c}{s}-{s}-{s}", .{ release_ctx.out_path, sep, release_ctx.bin_name, release_ctx.version, arch_name });
    defer release_ctx.alloc.free(full);

    release_ctx.full_path = full;

    if (release_ctx.verbose) {
        try io.stdout.print("Layout: {s}\n", .{release_ctx.layout.getName()});
        try io.stdout.print("Target: {s}\n", .{arch_name});
        try io.stdout.print("Out: {s}\n", .{full});
    }

    const temp_prefix = try prepareTempPrefix(release_ctx.alloc, arch_name);
    defer release_ctx.alloc.free(temp_prefix);

    try prepareTempDir(temp_prefix);

    var argv_bundle = try buildArgv(release_ctx, temp_prefix, arch_name);
    defer argv_bundle.deinit();

    if (release_ctx.verbose) {
        try io.stdout.print("Running: ", .{});
        for (argv_bundle.args.items) |arg| try io.stdout.print("{s} ", .{arg});
        try io.stdout.print("\n", .{});
    }

    const prefix_line = try std.fmt.allocPrint(release_ctx.alloc, "[{d}/{d}] {s}", .{ i, release_ctx.total, arch_name });
    defer release_ctx.alloc.free(prefix_line);

    var build_timer = try std.time.Timer.start();
    const term = try runBuild(release_ctx, prefix_line, argv_bundle.args.items, io, full);
    const elapsed_ns = build_timer.read();

    if (release_ctx.verbose) {
        try io.stdout.print("Status: {s} ", .{io.ok_fmt});
        try fmt.printDuration(io.stdout, elapsed_ns, global_flags.color);
        try io.stdout.print("\n\n", .{});
    } else {
        try io.stdout.print("[{d}/{d}] {s} {s} ", .{ i, release_ctx.total, arch_name, io.ok_fmt });
        try fmt.printDuration(io.stdout, elapsed_ns, global_flags.color);
        try io.stdout.print("\n", .{});
    }

    const dist_arch_dir = if (release_ctx.layout == .by_target)
        try std.fmt.allocPrint(release_ctx.alloc, "{s}{c}{s}", .{ release_ctx.out_path, sep, arch_name })
    else
        try release_ctx.alloc.dupe(u8, release_ctx.out_path);
    defer release_ctx.alloc.free(dist_arch_dir);

    if (release_ctx.layout == .by_target) {
        std.fs.cwd().makePath(dist_arch_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
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
        .stderr = io.stderr,
        .sep = sep,
        .temp_prefix = temp_prefix,
        .dest_bin = "",
    };

    const source_bin = try getSourceBin(release_ctx, temp_prefix, bin_extension, sep);
    defer release_ctx.alloc.free(source_bin);
    io_ctx.source_bin = source_bin;

    const ctx = parser.Context{
        .bin = release_ctx.bin_name,
        .version = release_ctx.version,
        .ext = bin_extension,
        .target = arch_name,
    };

    const parsed_filename = try parser.formatBinaryName(release_ctx.alloc, release_ctx.name_tamplate, ctx, io_ctx);
    defer release_ctx.alloc.free(parsed_filename);

    const full_dest_path = try std.fs.path.join(release_ctx.alloc, &[_][]const u8{ dist_arch_dir, parsed_filename });
    defer release_ctx.alloc.free(full_dest_path);

    io_ctx.dest_bin = full_dest_path;
    try moveAndDeleteTempDir(io_ctx);

    return term;
}

pub fn prepareTempPrefix(alloc: std.mem.Allocator, arch_name: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(alloc, "zig-out-{s}", .{arch_name});
}

pub fn prepareTempDir(temp_prefix: []const u8) !void {
    std.fs.cwd().makePath(temp_prefix) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

fn buildArgv(release_ctx: *release_enums.ReleaseCtx, temp_prefix: []const u8, arch_name: []const u8) !release_enums.ArgvBundle {
    var b = release_enums.ArgvBundle.init(release_ctx.alloc);
    errdefer b.deinit();

    const target_arg = try b.ownFmt("-Dtarget={s}", .{arch_name});
    const d_optimize_fmt = try b.ownFmt("-Doptimize={s}", .{@tagName(release_ctx.d_optimize)});

    try b.args.append("zig");
    try b.args.append("build");
    try b.args.append("--prefix");
    try b.args.append(temp_prefix);
    try b.args.append(target_arg);
    try b.args.append(d_optimize_fmt);
    try b.args.appendSlice(release_ctx.zig_args);

    return b;
}

fn runBuild(release_ctx: *release_enums.ReleaseCtx, prefix_line: []const u8, full_argv: []const []const u8, io: generals_enums.Io, full: []const u8) !std.process.Child.Term {
    const term = try runWithSpinner(release_ctx, prefix_line, full_argv, release_ctx.color);

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                const fail = try fmt.allocRedText(release_ctx.alloc, "fail", release_ctx.color);
                defer release_ctx.alloc.free(fail);
                try io.stderr.print("\r{s} {s} (exit {d})\nOut: {s}\nHint: run `zemit -v release` to see the full compiler output.\n", .{ prefix_line, fail, code, full });
                return error.CompilationFailed;
            }
        },
        .Signal, .Stopped, .Unknown => {
            const inter = try fmt.allocRedText(release_ctx.alloc, "INTERRUPTED", release_ctx.color);
            defer release_ctx.alloc.free(inter);
            try io.stderr.print("\r{s} {s}\nOut: {s}\nHint: run `zemit -v release` to see the full compiler output.\n", .{ prefix_line, inter, full });
            return error.CompilationInterrupted;
        },
    }
    return term;
}

fn runWithSpinner(release_ctx: *release_enums.ReleaseCtx, prefix_line: []const u8, argv: []const []const u8, color: bool) !std.process.Child.Term {
    var child = std.process.Child.init(argv, release_ctx.alloc);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = if (release_ctx.verbose) .Inherit else .Ignore;

    const animate = (!release_ctx.verbose) and utils.isTty();
    try child.spawn();

    if (!animate) return child.wait();

    const state = try release_ctx.alloc.create(SpinnerState);
    state.* = SpinnerState{};
    defer release_ctx.alloc.destroy(state);

    var spinner = try std.Thread.spawn(.{}, spinnerThread, .{ state, prefix_line, color });
    const term = try child.wait();
    state.running.store(false, .release);
    spinner.join();

    return term;
}

fn spinnerThread(state: *SpinnerState, prefix_line: []const u8, color: bool) void {
    const stdout = std.io.getStdOut().writer();
    const frames: []const []const u8 = if (color)
        &[_][]const u8{ "\x1b[35m.\x1b[0m", "\x1b[35m..\x1b[0m", "\x1b[35m...\x1b[0m" }
    else
        &[_][]const u8{ ".", "..", "..." };

    var idx: usize = 0;
    const polling_delay_ns: u64 = 15_000_000;
    const frames_per_tick = 30;
    var tick: usize = 0;

    while (state.running.load(.acquire)) {
        if (tick == 0) {
            stdout.print("\r\x1b[2K{s} {s}", .{ prefix_line, frames[idx] }) catch {};
            idx = (idx + 1) % frames.len;
        }
        std.time.sleep(polling_delay_ns);
        tick += 1;
        if (tick >= frames_per_tick) tick = 0;
    }
    stdout.print("\r\x1b[2K", .{}) catch {};
}

pub fn getSourceBin(release_ctx: *release_enums.ReleaseCtx, temp_prefix: []const u8, bin_extension: []const u8, sep: u8) ![]const u8 {
    return try std.fmt.allocPrint(release_ctx.alloc, "{s}{c}bin{c}{s}{s}", .{ temp_prefix, sep, sep, release_ctx.bin_name, bin_extension });
}

pub fn moveAndDeleteTempDir(io_ctx: release_enums.IoCtx) !void {
    std.fs.cwd().copyFile(io_ctx.source_bin, std.fs.cwd(), io_ctx.dest_bin, .{}) catch |err| {
        try io_ctx.stderr.print("{s}: Failed to copy file: {}\n", .{ io_ctx.error_fmt, err });
        return err;
    };
    std.fs.cwd().deleteTree(io_ctx.temp_prefix) catch |err| {
        try io_ctx.stderr.print("{s}: Unable to remove temporary directory: {}\n", .{ io_ctx.warn_fmt, err });
    };
}

fn processAndWriteHash(comptime HasherType: type, file: std.fs.File, disk_writer: anytype, basename: []const u8) !void {
    var hasher = HasherType.init(.{});
    var buffer: [4096 * 2]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break;
        hasher.update(buffer[0..bytes_read]);
    }

    var digest: [HasherType.digest_length]u8 = undefined;
    hasher.final(&digest);
    try disk_writer.print("{s}  {s}\n", .{ std.fmt.fmtSliceHexLower(&digest), basename });
}

pub fn writeChecksumsContentOf(alloc: std.mem.Allocator, sub_path: []const u8, files: *std.fs.Dir.Walker, checksums: config.Checksums) !void {
    const out_path = try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ sub_path, std.fs.path.sep, checksums.file });
    defer alloc.free(out_path);

    const out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();
    const disk_writer = out_file.writer();

    while (try files.next()) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.eql(u8, entry.basename, checksums.file)) continue;

        const file = try entry.dir.openFile(entry.basename, .{});
        defer file.close();

        switch (checksums.algorithm) {
            .sha256 => try processAndWriteHash(hash.Sha256, file, disk_writer, entry.basename),
            .sha512 => try processAndWriteHash(hash.Sha512, file, disk_writer, entry.basename),
            .none => {},
        }
    }
}
