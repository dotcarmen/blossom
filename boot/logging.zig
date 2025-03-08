const std = @import("std");
const log = std.log;
const uefi = std.os.uefi;
const unicode = std.unicode;

pub fn logFn(
    comptime level: log.Level,
    comptime scope: @TypeOf(.enum_lit),
    comptime format: []const u8,
    args: anytype,
) void {
    logFnInner(level, scope, format, args) catch |err| {
        std.debug.panic("error logging: {!}", .{err});
    };
}

fn logFnInner(
    comptime level: log.Level,
    comptime scope: @TypeOf(.enum_lit),
    comptime format: []const u8,
    args: anytype,
) anyerror!void {
    const console = uefi.system_table.con_out orelse return error.NoBootServices;
    const writer = std.io.AnyWriter{
        .context = console,
        .writeFn = @ptrCast(&write),
    };

    try writer.print("[{s}]", .{level.asText()});
    if (scope != log.default_log_scope) {
        try writer.print(" {any}", .{scope});
    }

    try writer.print(": ", .{});
    try writer.print(format, args);
    try writer.print("\r\n", .{});
}

fn write(ctx: *uefi.protocol.SimpleTextOutput, str: []const u8) !usize {
    var off: usize = 0;
    var buf: [128]u16 = undefined;

    while (off < str.len) {
        const local_off = try unicode.utf8ToUtf16Le(buf[0..127], str[off..]);
        buf[local_off] = 0;
        try ctx.outputString(buf[0..local_off :0]).err();
        off += local_off;
    }

    return off;
}
