const std = @import("std");
const config = @import("../../../customization/config_reader.zig");
const release_enums = @import("../release/release_utils/release_enums.zig");
const general_enums = @import("../../../utils/general_enums.zig");

pub fn runTest(alloc: std.mem.Allocator, toml_path: []const u8, release_ctx: *release_enums.ReleaseCtx, io: general_enums.Io) !void {
    const t = config.loadConfig(alloc, toml_path, io) catch return;
    defer _ = t.deinit();

    if (try t.value.isOk(alloc, release_ctx, io)) {
        try io.stdout.print("{s} your zemit.toml is ok.\n", .{io.ok_fmt});
    }
}
