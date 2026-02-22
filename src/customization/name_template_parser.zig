const std = @import("std");

pub const TokenType = enum {
    literal,
    bin,
    version,
    target,
    ext,
    unknown_var,
    eof,
};

pub const Token = struct {
    type: TokenType,
    value: []const u8,
};

pub const Lexer = struct {
    source: []const u8,
    position: usize = 0,

    pub fn next(self: *Lexer) Token {
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

            return .{
                .type = parse_var_type(var_name),
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

    fn parse_var_type(str: []const u8) TokenType {
        if (std.mem.eql(u8, str, "bin")) return .bin;
        if (std.mem.eql(u8, str, "version")) return .version;
        if (std.mem.eql(u8, str, "target")) return .target;
        if (std.mem.eql(u8, str, "ext")) return .ext;
        return .unknown_var;
    }
};

pub const Context = struct {
    bin: []const u8,
    version: []const u8,
    target: []const u8,
    ext: []const u8,
};

pub fn format_binary_name(alloc: std.mem.Allocator, template: []const u8, ctx: Context) ![]const u8 {
    var lexer = Lexer{ .source = template };
    var output = std.ArrayList(u8).init(alloc);
    errdefer output.deinit();

    while (true) {
        const token = lexer.next();
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
