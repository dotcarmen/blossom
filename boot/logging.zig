const std = @import("std");
const log = std.log;
const uefi = std.os.uefi;

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
) !void {
    const Attr = uefi.protocol.SimpleTextOutput;

    const console = uefi.system_table.con_out.?;
    const writer = std.io.AnyWriter{
        .context = console,
        .writeFn = @ptrCast(&writeFn),
    };

    try console.setAttribute(switch (level) {
        .debug => Attr.blue,
        .info => Attr.green,
        .warn => Attr.yellow,
        .err => Attr.red,
    }).err();
    try writer.writeAll(level.asText());
    try console.setAttribute(Attr.white).err();

    if (scope != log.default_log_scope) {
        try writer.print(" {s}", .{@tagName(scope)});
    }

    try writer.writeAll(": ");
    try writer.print(format, args);
    try writer.writeAll("\r\n");
}

fn writeFn(ctx: *uefi.protocol.SimpleTextOutput, str: []const u8) !usize {
    var off: usize = 0;
    var buf: [128]u16 = undefined;

    while (off < str.len) {
        const local_off = try std.unicode.utf8ToUtf16Le(buf[0..127], str[off..]);
        buf[local_off] = 0;
        try ctx.outputString(buf[0..local_off :0]).err();
        off += local_off;
    }

    return off;
}
