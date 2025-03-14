const builtin = @import("builtin");
const std = @import("std");
const elf = std.elf;
const log = std.log;
const uefi = std.os.uefi;
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

const Loader = @import("loader.zig");
const uefilib = @import("uefilib.zig");
const logging = @import("logging.zig");

pub const std_options = std.Options{
    .logFn = logging.logFn,
};

pub fn main() uefi.Status {
    mainImpl() catch |err| {
        log.err("error loading blossom: {any}", .{err});
        if (err == error.Unexpected) return .aborted;
        return uefilib.errorToStatus(@errorCast(err));
    };

    return .success;
}

fn mainImpl() (uefi.UnexpectedError || uefi.Status.Error)!void {
    log.info("hello, world!", .{});
    const boots = uefi.system_table.boot_services orelse {
        log.err("boot services unavailable", .{});
        return uefi.Status.Error.AlreadyStarted;
    };
    var loader = try Loader.init(boots, utf16("efi\\boot\\blossomk"));
    try loader.load();

    log.info("kernel successfully loaded, exiting boot services", .{});
    _ = boots.exitBootServices(uefi.handle, 123);

    const entry: *const fn () callconv(.c) usize = @ptrFromInt(loader.entry_addr());
    log.info("entering kernel at {X}", .{entry});
    const res = entry();
    log.info("kernel returned {d}", .{res});
}

pub const panic = std.debug.FullPanic(panicFn);

fn panicFn(msg: []const u8, stacktrace: ?usize) noreturn {
    @branchHint(.cold);

    const BUFFER_LEN = 64;
    const convertUtf16 = std.unicode.utf8ToUtf16Le;

    var buf: [BUFFER_LEN]u16 = undefined;

    printing: {
        const console = uefi.system_table.con_out orelse
            break :printing;
        _ = console.setAttribute(uefi.protocol.SimpleTextOutput.red);
        defer _ = console.setAttribute(uefi.protocol.SimpleTextOutput.white);
        _ = console.outputString(utf16("\r\nbootloader panic"));

        if (stacktrace) |st| {
            _ = console.outputString(utf16(" at 0x"));
            var utf8_buf: [BUFFER_LEN]u8 = undefined;
            // assume the whole address is written, because why wouldn't it?
            const utf8_len = std.fmt.formatIntBuf(&utf8_buf, st, 16, .upper, .{});
            const len = convertUtf16(&buf, utf8_buf[0..utf8_len]) catch unreachable;
            buf[len] = 0;
            _ = console.outputString(buf[0..len :0]);
        }

        _ = console.outputString(utf16(": "));
        const len = convertUtf16(buf[0 .. BUFFER_LEN - 1], msg) catch unreachable;
        buf[len] = 0;
        _ = console.outputString(buf[0..len :0]);

        _ = console.outputString(utf16("\r\n"));
    }

    const boot_services = uefi.system_table.boot_services orelse while (true) {};
    _ = boot_services.exit(
        uefi.handle,
        uefi.Status.aborted,
        0,
        null,
    );
    while (true) {
        // boot_services.exit should've exited the program
    }
}
