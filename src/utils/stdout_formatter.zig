const std = @import("std");

fn code(comptime c: []const u8) []const u8 {
    return c;
}

fn wrap(
    alloc: std.mem.Allocator,
    txt: []const u8,
    start: []const u8,
    enabled: bool,
) ![]u8 {
    if (!enabled) return try alloc.dupe(u8, txt);
    return try std.fmt.allocPrint(alloc, "{s}{s}\x1b[0m", .{ start, txt });
}

pub fn green(alloc: std.mem.Allocator, txt: []const u8, enabled: bool) ![]u8 {
    return wrap(alloc, txt, code("\x1b[32m"), enabled);
}
pub fn red(alloc: std.mem.Allocator, txt: []const u8, enabled: bool) ![]u8 {
    return wrap(alloc, txt, code("\x1b[31m"), enabled);
}
pub fn yellow(alloc: std.mem.Allocator, txt: []const u8, enabled: bool) ![]u8 {
    return wrap(alloc, txt, code("\x1b[33m"), enabled);
}
pub fn gray(alloc: std.mem.Allocator, txt: []const u8, enabled: bool) ![]u8 {
    return wrap(alloc, txt, code("\x1b[90m"), enabled);
}

pub fn fmt_duration(alloc: std.mem.Allocator, elapsed_ns: u64) ![]u8 {
    const total_s = elapsed_ns / 1_000_000_000;
    const h = total_s / 3600;
    const m = (total_s / 60) % 60;
    const s = total_s % 60;

    if (h > 0) return try std.fmt.allocPrint(alloc, "({d}h {d}m {d}s)", .{ h, m, s });
    if (m > 0) return try std.fmt.allocPrint(alloc, "({d}m {d}s)", .{ m, s });

    const frac: f64 = @as(f64, @floatFromInt(elapsed_ns)) / 1e9;
    return try std.fmt.allocPrint(alloc, "({d:.2}s)", .{frac});
}
