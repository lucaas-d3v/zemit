const std = @import("std");

pub const Io = struct {
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,
    error_fmt: []const u8,
};

pub const GlobalFlags = struct {
    color: bool,
    verbose: bool,
};
