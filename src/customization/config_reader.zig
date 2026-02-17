const std = @import("std");
const toml = @import("toml");

pub const Rulease = struct {
    targets: ?[]const []const u8 = null,
};

pub const Config = struct {
    release: Rulease = .{},
};

pub fn load(allocator: std.mem.Allocator, toml_path: []const u8) !toml.Parsed(Config) {
    const file = std.fs.cwd().openFile(toml_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            const arena = std.heap.ArenaAllocator.init(allocator);
            return toml.Parsed(Config){
                .arena = arena,
                .value = .{},
            };
        }
        return err;
    };
    defer file.close();

    const file_content: []const u8 = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(file_content);

    var parser = toml.Parser(Config).init(allocator);
    defer parser.deinit();

    return try parser.parseString(file_content);
}
