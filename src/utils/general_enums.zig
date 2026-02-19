const std = @import("std");

pub const Io = struct {
    stdout: std.io.AnyWriter,
    stderr: std.io.AnyWriter,
};
