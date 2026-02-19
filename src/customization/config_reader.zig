const std = @import("std");
const toml = @import("toml");

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
    dir: []const u8 = ".zemit/dist",
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
