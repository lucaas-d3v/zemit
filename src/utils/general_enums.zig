const std = @import("std");

// encapsulates standard output streams and pre-formatted status indicators
pub const Io = struct {
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,
    error_fmt: []const u8,
    ok_fmt: []const u8,
    warn_fmt: []const u8,
};

// holds global configuration flags that affect overall program behavior
pub const GlobalFlags = struct {
    color: bool,
    verbose: bool,
};
