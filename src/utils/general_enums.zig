const std = @import("std");

pub const Io = struct {
    stdout: *std.io.Writer,
    stderr: *std.io.Writer,
    error_fmt: []const u8,
    ok_fmt: []const u8,
    warn_fmt: []const u8,
};

pub const GlobalFlags = struct {
    color: bool,
    verbose: bool,
};
