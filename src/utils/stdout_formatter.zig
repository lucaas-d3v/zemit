const std = @import("std");

const COLOR_CYAN = "\x1b[36m";
const COLOR_GREEN = "\x1b[32m";
const COLOR_RED = "\x1b[31m";
const COLOR_YELLOW = "\x1b[33m";
const COLOR_GRAY = "\x1b[90m";
const COLOR_RESET = "\x1b[0m";

pub fn writeColored(writer: std.io.AnyWriter, comptime color_code: []const u8, text: []const u8, enabled: bool) !void {
    if (enabled) try writer.writeAll(color_code);
    try writer.writeAll(text);
    if (enabled) try writer.writeAll(COLOR_RESET);
}

pub fn printCyan(writer: std.io.AnyWriter, text: []const u8, enabled: bool) !void {
    try writeColored(writer, COLOR_CYAN, text, enabled);
}

pub fn printGreen(writer: std.io.AnyWriter, text: []const u8, enabled: bool) !void {
    try writeColored(writer, COLOR_GREEN, text, enabled);
}

pub fn allocGreenText(alloc: std.mem.Allocator, text: []const u8, enabled: bool) ![]u8 {
    if (!enabled) return try alloc.dupe(u8, text);
    return try std.fmt.allocPrint(alloc, "\x1b[32m{s}\x1b[0m", .{text});
}

pub fn printRed(writer: std.io.AnyWriter, text: []const u8, enabled: bool) !void {
    try writeColored(writer, COLOR_RED, text, enabled);
}

pub fn allocRedText(alloc: std.mem.Allocator, text: []const u8, enabled: bool) ![]u8 {
    if (!enabled) return try alloc.dupe(u8, text);
    return try std.fmt.allocPrint(alloc, "\x1b[31m{s}\x1b[0m", .{text});
}

pub fn printYellow(writer: std.io.AnyWriter, text: []const u8, enabled: bool) !void {
    try writeColored(writer, COLOR_YELLOW, text, enabled);
}

pub fn allocYellowText(alloc: std.mem.Allocator, text: []const u8, enabled: bool) ![]u8 {
    if (!enabled) return try alloc.dupe(u8, text);
    return try std.fmt.allocPrint(alloc, "\x1b[33m{s}\x1b[0m", .{text});
}

pub fn printGray(writer: std.io.AnyWriter, text: []const u8, enabled: bool) !void {
    try writeColored(writer, COLOR_GRAY, text, enabled);
}

pub fn printDuration(writer: anytype, elapsed_ns: u64, enabled: bool) !void {
    const total_s = elapsed_ns / 1_000_000_000;
    const h = total_s / 3600;
    const m = (total_s / 60) % 60;
    const s = total_s % 60;

    var buf: [64]u8 = undefined;
    var pure_dur: []u8 = &[_]u8{};

    if (h > 0) {
        pure_dur = try std.fmt.bufPrint(&buf, "({d}h {d}m {d}s)", .{ h, m, s });
    } else if (m > 0) {
        pure_dur = try std.fmt.bufPrint(&buf, "({d}m {d}s)", .{ m, s });
    } else {
        const frac: f64 = @as(f64, @floatFromInt(elapsed_ns)) / 1e9;
        pure_dur = try std.fmt.bufPrint(&buf, "({d:.2}s)", .{frac});
    }

    try writeColored(writer, COLOR_GRAY, pure_dur, enabled);
}
