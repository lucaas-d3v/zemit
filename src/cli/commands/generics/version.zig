const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

pub fn version() void {
    std.debug.print(
        "zemit {s} (zig {s}) {s}-{s}\n",
        .{
            build_options.zemit_version,
            builtin.zig_version_string,
            @tagName(builtin.cpu.arch),
            @tagName(builtin.os.tag),
        },
    );
}
