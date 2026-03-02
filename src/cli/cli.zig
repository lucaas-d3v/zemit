const std = @import("std");
const build_options = @import("build_options");
const checker = @import("../utils/checkers.zig");
const generals_enums = @import("../utils/general_enums.zig");
const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");
const reader = @import("../customization/config_reader.zig");
const fmt = @import("../utils/stdout_formatter.zig");
const helps = @import("./commands/generics/help_command.zig");
const version = @import("./commands/generics/version.zig");
const release = @import("./commands/release/release.zig");
const clean = @import("./commands/clean/clean.zig");
const init = @import("./commands/init/init.zig");
const test_cmd = @import("./commands/test/test.zig");

pub fn runCli(alloc: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next();

    var command: ?[]const u8 = null;
    const color = checker.isColor(alloc);

    var global_flags = generals_enums.GlobalFlags{
        .color = color,
        .verbose = false,
    };

    const error_fmt = try fmt.allocRedText(alloc, "ERROR", global_flags.color);
    defer alloc.free(error_fmt);

    const ok_fmt = try fmt.allocGreenText(alloc, "✓", global_flags.color);
    defer alloc.free(ok_fmt);

    const warn_fmt = try fmt.allocYellowText(alloc, "WARN", global_flags.color);
    defer alloc.free(warn_fmt);

    var stdout_buffer: [4096]u8 = undefined;
    var stderr_buffer: [4096]u8 = undefined;

    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);

    defer {
        _ = stdout_writer.interface.flush() catch {};
        _ = stderr_writer.interface.flush() catch {};
    }

    const io = generals_enums.Io{
        .stdout = &stdout_writer.interface,
        .stderr = &stderr_writer.interface,
        .error_fmt = error_fmt,
        .ok_fmt = ok_fmt,
        .warn_fmt = warn_fmt,
    };

    while (args.next()) |arg| {
        if (checker.cliArgsEquals(arg, &.{ "-h", "--help" })) {
            try helps.help(io);
            return;
        }

        if (checker.cliArgsEquals(arg, &.{ "-V", "--version" })) {
            try version.printVersion(build_options.zemit_version);
            return;
        }

        if (checker.cliArgsEquals(arg, &.{ "-v", "--verbose" })) {
            global_flags.verbose = true;
            continue;
        }

        if (checker.cliArgsEquals(arg, &.{ "-nc", "--no-color" })) {
            global_flags.color = false;
            continue;
        }

        command = arg;
        break;
    }

    const cmd = command orelse {
        try helps.help(io);
        return;
    };

    // especial case
    if (checker.strEquals(cmd, "init")) {
        try init.runInit(&args, io);
        return;
    }

    const toml_path = "zemit.toml";
    const config_parsed = reader.loadConfig(alloc, toml_path, io) catch return;
    defer config_parsed.deinit();

    var release_ctx = release_enums.ReleaseCtx{
        .alloc = alloc,
        .architecture = .none,
        .out_path = "",
        .full_path = "",
        .bin_name = "",
        .version = build_options.zemit_version,
        .d_optimize = config_parsed.value.build.optimize,
        .zig_args = config_parsed.value.build.zig_args,
        .layout = config_parsed.value.dist.layout,
        .name_tamplate = config_parsed.value.dist.name_template,
        .checksums = config_parsed.value.checksums,
        .verbose = global_flags.verbose,
        .total = 0,
        .color = global_flags.color,
    };

    if (!(try config_parsed.value.isOk(alloc, &release_ctx, io))) return;

    if (checker.strEquals(cmd, "release")) {
        try release.runRelease(alloc, global_flags, io, &args, release_ctx, config_parsed);
        return;
    }

    if (checker.strEquals(cmd, "clean")) {
        try clean.runClean(alloc, global_flags, &args, io, config_parsed);
        return;
    }

    if (checker.strEquals(cmd, "test")) {
        try test_cmd.runTest(alloc, toml_path, &release_ctx, io);
        return;
    }

    try helps.help(io);
    try io.stderr.print("\nError: Unknown command '{s}'\n", .{cmd});
}
