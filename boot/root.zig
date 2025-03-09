const builtin = @import("builtin");
const std = @import("std");
const log = std.log;
const uefi = std.os.uefi;
const unicode = std.unicode;

const uefilib = @import("uefilib.zig");
const logging = @import("logging.zig");

pub const std_options = std.Options{
    .logFn = logging.logFn,
};

pub fn main() uefi.Status {
    log.info("hello, world!", .{});

    if (builtin.is_test) {
        const logger = log.scoped(.tester);
        logger.info("running tests...", .{});
        for (builtin.test_functions) |test_fn| {
            logger.debug("running test {s}...", .{test_fn.name});
            logger.info("{s}: {s}", .{ test_fn.name, "pass" });
        }
    }

    log.info("loading blossom...", .{});
    loadOS() catch |err| {
        log.err("error loading blossom: {any}", .{err});
        return uefilib.errorToStatus(err);
    };

    return .success;
}

fn loadOS() uefi.Status.Error!void {
    const boot_services = uefi.system_table.boot_services.?;

    // TODO: defer close protocols
    const loaded_image = try boot_services.openProtocolSt(uefi.protocol.LoadedImage, uefi.handle);
    const device = loaded_image.device_handle orelse return uefi.Status.Error.NotFound;
    const fs = try boot_services.openProtocolSt(uefi.protocol.SimpleFileSystem, device);

    var vol: *uefi.protocol.File = undefined;
    try fs.openVolume(@ptrCast(&vol)).err();
    defer _ = vol.close();

    var kernel: *const uefi.protocol.File = undefined;
    try vol.open(
        &kernel,
        unicode.utf8ToUtf16LeStringLiteral("efi\\boot\\blossomk"),
        uefi.protocol.File.efi_file_mode_read,
        uefi.protocol.File.efi_file_read_only,
    ).err();
    defer _ = kernel.close();

    log.info("kernel file successfully opened", .{});
    var info: struct { info: uefi.FileInfo, name: [32]u8 } = undefined;
    var len: usize = @sizeOf(@TypeOf(info));
    try kernel.getInfo(&uefi.FileInfo.guid, &len, @ptrCast(&info)).err();
    var real_name: [32]u8 = undefined;
    const utf16_name = info.info.getFileName();
    len = 0;
    while (utf16_name[len] != 0) len += 1;
    const name_len = unicode.utf16LeToUtf8(&real_name, utf16_name[0..len]) catch return uefi.Status.Error.BadBufferSize;
    log.info("file {s} size {x} ({x} on disk) bytes", .{
        real_name[0..name_len],
        info.info.file_size,
        info.info.physical_size,
    });

    log.info("blossom loaded. press any key to continue...", .{});
    var events = [_]uefi.Event{uefi.system_table.con_in.?.wait_for_key};
    // TODO: idk lol
    var idx: usize = 0;
    try boot_services.waitForEvent(1, &events, &idx).err();
}

const panic = std.debug.FullPanic(panicFn);

fn panicFn(msg: []const u8, stacktrace: ?usize) noreturn {
    printing: {
        const console = uefi.system_table.con_out.?;
        console.outputString(unicode.utf8ToUtf16LeStringLiteral("\r\nbootloader panicked")).err() catch break :printing;
        if (stacktrace) |st| {
            var stream = std.io.fixedBufferStream([64]u8);
            stream.writer().print(" at 0x{x}", .{st}) catch break :printing;
            var buf: [64]u16 = undefined;
            const len = unicode.utf8ToUtf16Le(buf[0..63], stream.getWritten()) catch break :printing;
            buf[len] = 0;
            console.outputString(buf[0..len :0]).err() catch break :printing;
        }

        console.outputString(":\r\n").err() catch break :printing;
        console.outputString(msg).err() catch break :printing;
    }

    const boot_services = uefi.system_table.boot_services orelse while (true) {};
    boot_services.exit(uefi.handle, 2, 0, null);
}
