const std = @import("std");

pub const ReleaseCtx = struct {
    alloc: std.mem.Allocator,
    architecture: Architectures,
    out_path: []const u8,
    full_path: []const u8,
    bin_name: []const u8,
    version: []const u8,
    d_optimize: []const u8,
    zig_args: []const []const u8,
    verbose: bool,
    total: usize,
    color: bool,
};

pub const ArgvBundle = struct {
    args: std.ArrayList([]const u8),
    owned: std.ArrayList([]u8),

    pub fn init(alloc: std.mem.Allocator) ArgvBundle {
        return .{
            .args = std.ArrayList([]const u8).init(alloc),
            .owned = std.ArrayList([]u8).init(alloc),
        };
    }

    pub fn deinit(self: *ArgvBundle) void {
        // free owned strings
        for (self.owned.items) |s| self.args.allocator.free(s);
        self.owned.deinit();
        self.args.deinit();
    }

    pub fn ownDup(self: *ArgvBundle, bytes: []const u8) ![]const u8 {
        const duped = try self.args.allocator.dupe(u8, bytes);
        errdefer self.args.allocator.free(duped);
        try self.owned.append(duped);
        return duped;
    }

    pub fn ownFmt(self: *ArgvBundle, comptime fmt_str: []const u8, args: anytype) ![]const u8 {
        const s = try std.fmt.allocPrint(self.args.allocator, fmt_str, args);
        errdefer self.args.allocator.free(s);
        try self.owned.append(s);
        return s;
    }
};

pub const Architectures = enum {
    x86_64_linux_gnu,
    x86_64_linux_musl,

    aarch64_linux_gnu,
    aarch64_linux_musl,

    arm_linux_gnueabihf,
    arm_linux_musleabihf,

    riscv64_linux_gnu,
    riscv64_linux_musl,

    x86_64_windows_gnu,
    x86_64_windows_msvc,

    x86_64_macos,
    aarch64_macos,

    none,

    pub fn asString(self: Architectures) []const u8 {
        return switch (self) {
            .x86_64_linux_gnu => "x86_64-linux-gnu",
            .x86_64_linux_musl => "x86_64-linux-musl",
            .aarch64_linux_gnu => "aarch64-linux-gnu",
            .aarch64_linux_musl => "aarch64-linux-musl",
            .arm_linux_gnueabihf => "arm-linux-gnueabihf",
            .arm_linux_musleabihf => "arm-linux-musleabihf",
            .riscv64_linux_gnu => "riscv64-linux-gnu",
            .riscv64_linux_musl => "riscv64-linux-musl",
            .x86_64_windows_gnu => "x86_64-windows-gnu",
            .x86_64_windows_msvc => "x86_64-windows-msvc",
            .x86_64_macos => "x86_64-macos",
            .aarch64_macos => "aarch64-macos",
            .none => "",
        };
    }

    pub fn exists(name: []const u8) bool {
        return TargetMap.has(name);
    }

    pub fn fromString(input: []const u8) ?Architectures {
        return TargetMap.get(input);
    }
};

const TargetMap = std.StaticStringMap(Architectures).initComptime(blk: {
    const fields = @typeInfo(Architectures).Enum.fields;
    var pairs: [fields.len]struct { []const u8, Architectures } = undefined;
    for (fields, 0..) |field, i| {
        const enum_val: Architectures = @enumFromInt(field.value);
        pairs[i] = .{ enum_val.asString(), enum_val };
    }
    break :blk pairs;
});

pub const IoCtx = struct {
    ok_fmt: []const u8,
    warn_fmt: []const u8,
    error_fmt: []const u8,

    source_bin: []const u8,
    sep: u8,
    temp_prefix: []const u8,
    dest_bin: []const u8,
    stderr: std.io.AnyWriter,
};

pub const DistDirError = error{
    Empty,
    Dot,
    AbsolutePath,
    Traversal,
    ZigOut,
    TildeNotAllowed,
    InvalidByte,
    BackslashNotAllowed,
};
