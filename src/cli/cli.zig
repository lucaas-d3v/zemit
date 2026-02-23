const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

// internals
const checker = @import("../utils/checkers.zig");
const generals_enums = @import("../utils/general_enums.zig");
const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");
const reader = @import("../customization/config_reader.zig");
const fmt = @import("../utils/stdout_formatter.zig");

// commands
const helps = @import("./commands/generics/help_command.zig");
const version = @import("./commands/generics/version.zig");
const release = @import("./commands/release/release.zig");
const clean = @import("./commands/clean/clean.zig");

// main entry point of the command line interface
pub fn cli(alloc: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    _ = args.next(); // bin name

    var command: ?[]const u8 = null;

    const is_tty = checker.is_TTY();
    var color = is_tty;

    const env_no_color = std.process.getEnvVarOwned(alloc, "NO_COLOR") catch null;
    if (env_no_color) |val| {
        defer alloc.free(val);
        color = false;
    }

    var global_flags = generals_enums.GlobalFlags{
        .color = color,
        .verbose = false,
    };

    // global flags
    while (args.next()) |arg| {
        if (checker.cli_args_equals(arg, &.{ "-h", "--help" })) {
            helps.help(alloc);
            return;
        }

        if (checker.cli_args_equals(arg, &.{ "-V", "--version" })) {
            version.version(build_options.zemit_version);
            return;
        }

        if (checker.cli_args_equals(arg, &.{ "-v", "--verbose" })) {
            global_flags.verbose = true;
            continue;
        }

        if (checker.cli_args_equals(arg, &.{ "-nc", "--no-color" })) {
            global_flags.color = false;
            continue;
        }

        command = arg;
        break;
    }

    const cmd = command orelse {
        helps.help(alloc);
        return;
    };

    const error_fmt = try fmt.red(alloc, "ERROR", global_flags.color);
    defer alloc.free(error_fmt);

    const ok_fmt = try fmt.green(alloc, "✓", global_flags.color);
    defer alloc.free(ok_fmt);

    const warn_fmt = try fmt.yellow(alloc, "WARN", global_flags.color);
    defer alloc.free(warn_fmt);

    var io = generals_enums.Io{
        .stdout = std.io.getStdOut().writer().any(),
        .stderr = std.io.getStdErr().writer().any(),
        .error_fmt = error_fmt,
        .ok_fmt = ok_fmt,
        .warn_fmt = warn_fmt,
    };

    const toml_path = "zemit.toml";
    const config_parsed = reader.load(alloc, toml_path) catch |err| {
        std.log.err("{s}: Failed to parse '{s}', check the syntaxe", .{ error_fmt, toml_path });
        return err;
    };
    defer config_parsed.deinit();

    const layout = try checker.to_release_layout(config_parsed.value.dist.layout, io.stderr, io.error_fmt);
    if (layout == .none) {
        return;
    }

    var release_ctx = release_enums.ReleaseCtx{
        .alloc = alloc,

        .architecture = release_enums.Architectures.none,

        .out_path = "",
        .full_path = "",
        .bin_name = "",
        .version = build_options.zemit_version,

        .d_optimize = config_parsed.value.build.optimize,
        .zig_args = config_parsed.value.build.zig_args,

        .layout = layout,
        .name_tamplate = config_parsed.value.dist.name_template,

        .verbose = global_flags.verbose,
        .total = 0,
        .color = global_flags.color,
    };

    // validate
    if (!(try config_parsed.value.is_ok(alloc, &release_ctx))) {
        return;
    }

    // dispatch
    if (checker.str_equals(cmd, "release")) {
        release.release(alloc, global_flags, &io, &args, release_ctx, config_parsed) catch |err| {
            switch (err) {
                error.InvalidConfig => try io.stderr.print("Check your zemit.toml.\n", .{}),
                else => {},
            }

            return;
        };

        return;
    }

    if (checker.str_equals(cmd, "clean")) {
        try clean.clean(alloc, global_flags, &args, "zemit.toml");
        return;
    }

    helps.help(alloc);
    const stderr = std.io.getStdErr().writer();
    try stderr.print("\nError: Unknown command '{s}'\n", .{cmd});
}
