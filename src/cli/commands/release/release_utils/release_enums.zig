const std = @import("std");
const config = @import("../../../../customization/config_reader.zig");

// defines how the final binaries will be structured in the output directory
pub const ReleaseLayout = enum {
    BY_TARGET,
    FLAT,
    none,

    // returns the string representation of the layout type
    pub fn getName(self: ReleaseLayout) []const u8 {
        return switch (self) {
            .BY_TARGET => "by_target",
            .FLAT => "flat",
            .none => "none",
        };
    }
};

// holds the global state and configuration for a release execution
pub const ReleaseCtx = struct {
    alloc: std.mem.Allocator,

    architecture: Architectures,

    out_path: []const u8,
    full_path: []const u8,
    bin_name: []const u8,
    version: []const u8,

    d_optimize: []const u8,
    zig_args: []const []const u8,
    layout: ReleaseLayout,

    name_tamplate: []const u8,

    check_sum: config.Checksums,

    verbose: bool,
    total: usize,
    color: bool,
};

// context for input/output operations and terminal formatting during release
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

// manages command line arguments and their memory lifecycle
pub const ArgvBundle = struct {
    args: std.ArrayList([]const u8),
    owned: std.ArrayList([]u8),

    // initializes a new argument bundle with the provided allocator
    pub fn init(alloc: std.mem.Allocator) ArgvBundle {
        return .{
            .args = std.ArrayList([]const u8).init(alloc),
            .owned = std.ArrayList([]u8).init(alloc),
        };
    }

    // releases all allocated memory for both the list and the strings themselves
    pub fn deinit(self: *ArgvBundle) void {
        for (self.owned.items) |s| self.args.allocator.free(s);
        self.owned.deinit();
        self.args.deinit();
    }

    // duplicates a string and stores it for automatic cleanup on deinit
    pub fn ownDup(self: *ArgvBundle, bytes: []const u8) ![]const u8 {
        const duped = try self.args.allocator.dupe(u8, bytes);
        errdefer self.args.allocator.free(duped);
        try self.owned.append(duped);
        return duped;
    }

    // formats a string and stores it for automatic cleanup on deinit
    pub fn ownFmt(self: *ArgvBundle, comptime fmt_str: []const u8, args: anytype) ![]const u8 {
        const s = try std.fmt.allocPrint(self.args.allocator, fmt_str, args);
        errdefer self.args.allocator.free(s);
        try self.owned.append(s);
        return s;
    }
};

// supported target architectures and operating systems
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

    // converts the architecture enum to its corresponding Zig target string
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

    // checks if a given architecture string is supported
    pub fn exists(name: []const u8) bool {
        return TargetMap.has(name);
    }

    // retrieves the architecture enum from its string representation
    pub fn fromString(input: []const u8) ?Architectures {
        return TargetMap.get(input);
    }
};

// compile-time map for efficient architecture string lookups
const TargetMap = std.StaticStringMap(Architectures).initComptime(blk: {
    const fields = @typeInfo(Architectures).Enum.fields;
    var pairs: [fields.len]struct { []const u8, Architectures } = undefined;
    for (fields, 0..) |field, i| {
        const enum_val: Architectures = @enumFromInt(field.value);
        pairs[i] = .{ enum_val.asString(), enum_val };
    }
    break :blk pairs;
});

// errors related to distribution directory validation
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
