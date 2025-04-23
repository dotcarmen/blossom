const Logger = @This();

const std = @import("std");
const fmt = std.fmt;
const log = std.log;

pub const logger: Logger linksection(".kernel.logger") = .{
    .write = struct {
        fn write(_: usize, _: [*]const u8) callconv(.c) void {
            @panic("`logger` isn't initialized");
        }
    }.write,
};
const writer: std.io.AnyWriter = .{
    .context = undefined,
    .writeFn = &writeFn,
};

write: *const fn (len: usize, ptr: [*]const u8) callconv(.c) void,

pub fn logfn(
    comptime level: log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    writer.print("[{s}] {s}: ", .{
        level.asText(), @tagName(scope),
    }) catch unreachable;
    writer.print(format, args) catch unreachable;
    writer.writeAll("\n") catch unreachable;
}

fn writeFn(_: *const anyopaque, bytes: []const u8) anyerror!usize {
    logger.write(bytes.len, bytes.ptr);
    return bytes.len;
}
