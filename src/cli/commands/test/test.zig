const std = @import("std");
const config = @import("../../../customization/config_reader.zig");
const release_enums = @import("../release/release_utils/release_enums.zig");
const general_enums = @import("../../../utils/general_enums.zig");

pub fn test_(alloc: std.mem.Allocator, toml_path: []const u8, release_ctx: *release_enums.ReleaseCtx, io: general_enums.Io) !void {
    const t = try config.load(alloc, toml_path);
    if (try t.value.is_ok(alloc, release_ctx)) {
        try io.stdout.print("{s}: your zemit.toml is ok.\n", .{io.ok_fmt});
    }

    defer _ = t.deinit();
}
