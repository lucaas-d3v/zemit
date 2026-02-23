const std = @import("std");
const release_enums = @import("../cli/commands/release/release_utils/release_enums.zig");

// defines the types of tokens recognized during template parsing
pub const TokenType = enum {
    literal,
    bin,
    version,
    target,
    ext,
    unknown_var,
    eof,
};

// represents a single unit of information extracted from the template string
pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

// data structure to hold values used for template variable replacement
pub const Context = struct {
    bin: []const u8,
    version: []const u8,
    target: []const u8,
    ext: []const u8,
};

// handles the decomposition of the template string into manageable tokens
pub const Lexer = struct {
    source: []const u8,
    position: usize = 0,

    // extracts the next token from the source string and handles error reporting
    pub fn next(self: *Lexer, iO: release_enums.IoCtx) !Token {
        if (self.position >= self.source.len) {
            return .{ .type = .eof, .value = "" };
        }

        const start = self.position;

        if (self.source[self.position] == '{') {
            self.position += 1;
            const var_start = self.position;

            while (self.position < self.source.len and self.source[self.position] != '}') {
                self.position += 1;
            }

            const var_name = self.source[var_start..self.position];

            if (self.position < self.source.len) self.position += 1;

            const t_type = parse_var_type(var_name);
            if (t_type == TokenType.unknown_var) {
                try iO.stderr.print("{s}: Unknown variable '{s}' at position '{d}'\n\n\t{s}\n\t", .{ iO.error_fmt, var_name, start, self.source });

                var i: usize = 0;
                while (i < start) : (i += 1) {
                    try iO.stderr.print(" ", .{});
                }

                const var_len = var_name.len + 2; // +2 for the '{' and '}'
                i = 0;
                while (i < var_len) : (i += 1) {
                    try iO.stderr.print("^", .{});
                }

                try iO.stderr.print("\n", .{});
            }

            return .{
                .type = t_type,
                .value = var_name,
            };
        }

        while (self.position < self.source.len and self.source[self.position] != '{') {
            self.position += 1;
        }

        return .{
            .type = .literal,
            .value = self.source[start..self.position],
        };
    }

    // maps a variable name string to its corresponding TokenType
    fn parse_var_type(str: []const u8) TokenType {
        if (std.mem.eql(u8, str, "bin")) return .bin;
        if (std.mem.eql(u8, str, "version")) return .version;
        if (std.mem.eql(u8, str, "target")) return .target;
        if (std.mem.eql(u8, str, "ext")) return .ext;
        return .unknown_var;
    }
};

// processes the template string and produces the final binary name
pub fn format_binary_name(
    alloc: std.mem.Allocator,
    template: []const u8,
    ctx: Context,
    io_stds: release_enums.IoCtx,
) ![]const u8 {
    var lexer = Lexer{ .source = template };
    var output = std.ArrayList(u8).init(alloc);
    errdefer output.deinit();

    while (true) {
        const token = try lexer.next(io_stds);
        switch (token.type) {
            .eof => break,
            .literal => try output.appendSlice(token.value),
            .bin => try output.appendSlice(ctx.bin),
            .version => try output.appendSlice(ctx.version),
            .target => try output.appendSlice(ctx.target),
            .ext => try output.appendSlice(ctx.ext),
            .unknown_var => return error.UnknownVariableInTemplate,
        }
    }

    return output.toOwnedSlice();
}
