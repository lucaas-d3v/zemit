const std = @import("std");
pub const toml = @import("toml");

const chcker = @import("../utils/checkers.zig");
const fmt = @import("../utils/stdout_formatter.zig");

const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");
const release = @import("../cli/commands/release/release_utils/release_runners.zig");

pub const Build = struct {
    optimize: []const u8 = "ReleaseSmall",
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
    layout: []const u8 = "by_target",
    name_template: []const u8 = "{bin}-{version}-{target}{ext}",
};

pub const Checksums = struct {
    enabled: bool = true,
    algorithms: []const []const u8 = &.{"sha256"},
    file: []const u8 = "checksums.txt",
};

pub const Config = struct {
    build: Build = .{},
    release: Release = .{},
    dist: Dist = .{},
    checksums: Checksums = .{},

    pub fn is_ok(self: Config, alloc: std.mem.Allocator, release_ctx: *release_enums.ReleaseCtx) !bool {
        const stderr = std.io.getStdErr().writer().any();
        const error_fmt = try fmt.red(alloc, "ERROR", release_ctx.color);
        defer alloc.free(error_fmt);

        const ok_fmt = try fmt.green(alloc, "✓", release_ctx.color);
        defer alloc.free(ok_fmt);

        const warn_fmt = try fmt.yellow(alloc, "WARN", release_ctx.color);
        defer alloc.free(warn_fmt);

        const io = release_enums.IoCtx{
            .ok_fmt = ok_fmt,
            .error_fmt = error_fmt,
            .warn_fmt = warn_fmt,

            .dest_bin = "",
            .sep = chcker.sep,
            .source_bin = "",
            .stderr = stderr,
            .temp_prefix = "",
        };

        // build
        if (!(try is_valid_build(self.build, io))) {
            return false;
        }

        // release
        if (!(try is_valid_release(self.release, io))) {
            return false;
        }

        // dist
        if (!(try is_valid_dist(alloc, self.dist, io, release_ctx))) {
            return false;
        }

        // checksums after
        return true;
    }

    fn is_valid_build(b: Build, io: release_enums.IoCtx) !bool {
        if (chcker.str_equals(b.optimize, "ReleaseSmall")) return true;
        if (chcker.str_equals(b.optimize, "ReleaseFast")) return true;
        if (chcker.str_equals(b.optimize, "ReleaseSafe")) return true;
        if (chcker.str_equals(b.optimize, "Debug")) return true;

        try io.stderr.print("{s} Unknow Optimize '{s}'\n", .{ io.error_fmt, b.optimize });
        try io.stderr.print("Check your zemit.toml.\n", .{});
        return false;
    }

    fn is_valid_release(r: Release, io: release_enums.IoCtx) !bool {
        for (r.targets) |target| {
            if (target.len == 0) {
                try io.stderr.print("{s}: The architecture described in 'zemit.toml' cannot be empty.\n", .{io.error_fmt});
                return false;
            }

            if (!release_enums.Architectures.exists(target)) {
                try io.stderr.print("{s}: Unknown architecture: '{s}'\n", .{ io.error_fmt, target });
                return false;
            }
        }

        return true;
    }

    fn is_valid_dist(alloc: std.mem.Allocator, d: Dist, io: release_enums.IoCtx, release_ctx: *release_enums.ReleaseCtx) !bool {
        const color = chcker.is_color(alloc);

        // dir
        try chcker.validate_dist_dir_stop_if_not(alloc, d.dir, io.stderr, color);

        // layout
        if (try chcker.to_release_layout(d.layout, io.stderr, io.error_fmt) == .none) {
            return false;
        }

        // name_tmeplate
        const arch_name = release_ctx.architecture.asString();
        const dist_arch_dir = if (release_ctx.layout == release_enums.ReleaseLayout.BY_TARGET)
            try std.fmt.allocPrint(alloc, "{s}{c}{s}", .{ release_ctx.out_path, chcker.sep, arch_name })
        else
            try alloc.dupe(u8, release_ctx.out_path);
        defer alloc.free(dist_arch_dir);

        const bin_extension = switch (release_ctx.architecture) {
            .x86_64_windows_gnu, .x86_64_windows_msvc => ".exe",
            else => "",
        };

        const temp_prefix = try release.prepare_temp_prefix(alloc, arch_name);
        defer alloc.free(temp_prefix);

        var io_ctx = release_enums.IoCtx{
            .ok_fmt = io.ok_fmt,
            .warn_fmt = io.warn_fmt,
            .error_fmt = io.error_fmt,

            .source_bin = "",
            .stderr = io.stderr,
            .sep = chcker.sep,
            .temp_prefix = temp_prefix,
            .dest_bin = "",
        };

        const source_bin = try release.get_source_bin(release_ctx, temp_prefix, bin_extension, chcker.sep);
        defer alloc.free(source_bin);
        io_ctx.source_bin = source_bin;

        const ctx = release.parser.Context{
            .bin = release_ctx.bin_name,
            .version = release_ctx.version,
            .ext = bin_extension,
            .target = arch_name,
        };

        const parsed_filename = release.parser.format_binary_name(alloc, release_ctx.name_tamplate, ctx, io_ctx) catch {
            return false;
        };
        defer alloc.free(parsed_filename);

        const full_dest_path = try std.fs.path.join(alloc, &[_][]const u8{
            dist_arch_dir,
            parsed_filename,
        });
        defer alloc.free(full_dest_path);

        return true;
    }
};

pub fn load(allocator: std.mem.Allocator, toml_path: []const u8) !toml.Parsed(Config) {
    const file = std.fs.cwd().openFile(toml_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            const arena = std.heap.ArenaAllocator.init(allocator);

            return toml.Parsed(Config){
                .arena = arena,
                .value = Config{},
            };
        }
        return err;
    };
    defer file.close();

    var parser = toml.Parser(Config).init(allocator);
    defer parser.deinit();

    const file_content = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_content);

    return try parser.parseString(file_content);
}
