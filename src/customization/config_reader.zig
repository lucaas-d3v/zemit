const std = @import("std");
pub const toml = @import("toml");

const checker = @import("../utils/checkers.zig");
const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");
const release = @import("../cli/commands/release/release_utils/release_runners.zig");
const generals_enums = @import("../utils/general_enums.zig");

pub const Build = struct {
    optimize: std.builtin.OptimizeMode = .ReleaseSmall,
    zig_args: []const []const u8 = &.{},
};

pub const Release = struct {
    targets: []const []const u8 = &.{
        "x86_64-linux-gnu",
        "x86_64-linux-musl",
        "aarch64-linux-gnu",
        "aarch64-linux-musl",
        "arm-linux-gnueabihf",
        "arm-linux-musleabihf",
        "riscv64-linux-gnu",
        "riscv64-linux-musl",
        "x86_64-windows-gnu",
        "x86_64-windows-msvc",
        "x86_64-macos",
        "aarch64-macos",
    },
};

pub const Dist = struct {
    dir: []const u8 = "zemit/docs",
    layout: release_enums.ReleaseLayout = .by_target,
    name_template: []const u8 = "{bin}-{version}-{target}{ext}",
};

pub const Checksums = struct {
    enabled: bool = true,
    algorithm: release_enums.Hashes = .sha256,
    file: []const u8 = "checksums.txt",
};

pub const Config = struct {
    build: Build = .{},
    release: Release = .{},
    dist: Dist = .{},
    checksums: Checksums = .{},

    pub fn isOk(self: Config, alloc: std.mem.Allocator, release_ctx: *release_enums.ReleaseCtx, io: generals_enums.Io) !bool {
        var io_ctx = release_enums.IoCtx{
            .ok_fmt = io.ok_fmt,
            .error_fmt = io.error_fmt,
            .warn_fmt = io.warn_fmt,
            .dest_bin = "",
            .sep = checker.sep,
            .source_bin = "",
            .stderr = io.stderr,
            .temp_prefix = "",
        };

        if (!(try isValidRelease(self.release, io_ctx))) return false;
        if (!(try isValidDist(alloc, self.dist, &io_ctx, release_ctx, io))) return false;
        if (!(try isValidChecksums(self.checksums, io_ctx))) return false;

        return true;
    }
};

fn isValidChecksums(c: Checksums, io: release_enums.IoCtx) !bool {
    if (c.file.len == 0) {
        try io.stderr.print("{s}: The name of checksums file cannot be empty.\n", .{io.error_fmt});
        return false;
    }

    const dot_pos = std.mem.indexOf(u8, c.file, ".");
    if (dot_pos) |ex_pos| {
        const ext = c.file[@as(u16, @intCast(ex_pos)) + 1 ..];
        if (!checker.strEquals(ext, "txt")) {
            try io.stderr.print("{s}: The extension '{s}' is not supported for checksums file.\n", .{ io.error_fmt, ext });
            return false;
        }
    } else {
        try io.stderr.print("{s}: The name of checksums file needs an extension.\n", .{io.error_fmt});
        return false;
    }
    return true;
}

fn isValidRelease(r: Release, io: release_enums.IoCtx) !bool {
    for (r.targets) |target| {
        if (target.len == 0) {
            try io.stderr.print("{s}: The architecture described in 'zemit.toml' cannot be empty.\n", .{io.error_fmt});
            return false;
        }
        if (!release_enums.Architectures.exists(target)) {
            try io.stderr.print("{s}: Unknown architecture: '{s}'.\n", .{ io.error_fmt, target });
            return false;
        }
    }
    return true;
}

fn isValidDist(alloc: std.mem.Allocator, d: Dist, io_ctx_: *release_enums.IoCtx, release_ctx: *release_enums.ReleaseCtx, io: generals_enums.Io) !bool {
    try checker.validateDistDirStopIfNot(d.dir, io);

    const arch_name = release_ctx.architecture.asString();
    const dist_arch_dir = if (release_ctx.layout == .by_target)
        try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ release_ctx.out_path, checker.sep, arch_name })
    else
        try alloc.dupe(u8, release_ctx.out_path);
    defer alloc.free(dist_arch_dir);

    const bin_extension = switch (release_ctx.architecture) {
        .x86_64_windows_gnu, .x86_64_windows_msvc => ".exe",
        else => "",
    };

    const temp_prefix = try release.prepareTempPrefix(alloc, arch_name);
    defer alloc.free(temp_prefix);

    io_ctx_.temp_prefix = temp_prefix;
    const source_bin = try release.getSourceBin(release_ctx, temp_prefix, bin_extension, checker.sep);
    defer alloc.free(source_bin);
    io_ctx_.source_bin = source_bin;

    const ctx = release.parser.Context{
        .bin = release_ctx.bin_name,
        .version = release_ctx.version,
        .ext = bin_extension,
        .target = arch_name,
    };

    const parsed_filename = release.parser.formatBinaryName(alloc, release_ctx.name_tamplate, ctx, io_ctx_.*) catch return false;
    defer alloc.free(parsed_filename);

    const full_dest_path = try std.fs.path.join(alloc, &[_][]const u8{ dist_arch_dir, parsed_filename });
    defer alloc.free(full_dest_path);

    return true;
}

pub fn loadConfig(allocator: std.mem.Allocator, toml_path: []const u8, io: generals_enums.Io) !toml.Parsed(Config) {
    const file = std.fs.cwd().openFile(toml_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try io.stderr.print("{s}: Configuration file '{s}' not found.\nHint: Create a 'zemit.toml' file in the root of your project.\n", .{ io.error_fmt, toml_path });
            return error.ConfigNotFound;
        }
        try io.stderr.print("{s}: Unable to open '{s}': {}\n", .{ io.error_fmt, toml_path, err });
        return err;
    };
    defer file.close();

    var parser = toml.Parser(Config).init(allocator);
    defer parser.deinit();

    const file_content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_content);

    return parser.parseString(file_content) catch {
        try io.stderr.print("{s}: TOML syntax error in '{s}'.\n", .{ io.error_fmt, toml_path });
        if (parser.error_info) |err| {
            try io.stderr.print("Reason:\n", .{});
            for (err.struct_mapping) |value| try io.stderr.print("{s}\n", .{value});
            try io.stderr.print("\nAt line {d} and column {d}\n", .{ err.parse.line, err.parse.pos });
        }
        return error.ParseFailed;
    };
}
