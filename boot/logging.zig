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
    const console = uefi.system_table.con_out.?;
    const writer = std.io.AnyWriter{
        .context = console,
        .writeFn = @ptrCast(&writeFn),
    };

    try console.setAttribute(.{ .foreground = switch (level) {
        .debug => .blue,
        .info => .green,
        .warn => .yellow,
        .err => .red,
    } });
    try writer.writeAll(level.asText());
    try console.setAttribute(.{ .foreground = .white });

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
        _ = try ctx.outputString(buf[0..local_off :0]);
        off += local_off;
    }

    return off;
}
