const Logger = @This();

const std = @import("std");
const fmt = std.fmt;
const log = std.log;

var logger: Logger = .{};

pub fn logfn(
    comptime level: log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    fmt.format(logger, "[{any}] {any}: ", .{ level, scope }) catch @panic("oom");
    fmt.format(logger, format, args) catch @panic("oom");
}

pub fn writeAll(_: Logger, str: []const u8) !void {
    _ = str;
    unreachable;
}
