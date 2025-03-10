const builtin = @import("builtin");
const std = @import("std");
const elf = std.elf;
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
    const entry = loadOS() catch |err| {
        log.err("error loading blossom: {any}", .{err});
        return uefilib.errorToStatus(err);
    };

    {
        const code_bytes: [*]const u8 = @ptrCast(entry);
        const code: []const u8 = code_bytes[0..50];
        log.debug("code: {x}", .{code});
    }

    log.info("exiting boot services...", .{});
    _ = uefi.system_table.boot_services.?.exitBootServices(uefi.handle, 123);

    log.info("starting kernel {X}", .{entry});
    const res = entry();
    log.info("kernel returned {d}", .{res});

    return .success;
}

fn loadOS() uefi.Status.Error!*const fn () callconv(.c) usize {
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
    var info: extern struct { info: uefi.FileInfo, name: [32]u8 } = undefined;
    var len: usize = @sizeOf(@TypeOf(info));
    try kernel.getInfo(&uefi.FileInfo.guid, &len, @ptrCast(&info)).err();
    var real_name: [32]u8 = undefined;
    const utf16_name = info.info.getFileName();
    len = 0;
    while (utf16_name[len] != 0) len += 1;
    const name_len = unicode.utf16LeToUtf8(&real_name, utf16_name[0..len]) catch return uefi.Status.Error.BadBufferSize;
    log.debug("file {s} size {x} ({x} on disk) bytes", .{
        real_name[0..name_len],
        info.info.file_size,
        info.info.physical_size,
    });

    log.info("loading elf image...", .{});
    const elf_header = elf.Header.read(@constCast(kernel)) catch |err| {
        log.err("failed to read elf header: {any}", .{err});
        return uefi.Status.Error.CompromisedData;
    };
    log.debug("loaded elf header {any}", .{elf_header});
    if (!elf_header.is_64) {
        // TODO: should i do 32-bit?
        log.err("elf image is not 64-bit", .{});
        return uefi.Status.Error.Unsupported;
    }

    var pheaders = elf_header.program_header_iterator(@constCast(kernel));

    var kernel_addr_start: usize = std.math.maxInt(usize);
    var kernel_addr_end: usize = 0;
    while (pheaders.next() catch |err| {
        log.err("failed to read program header: {any}", .{err});
        return uefi.Status.Error.CompromisedData;
    }) |phdr| {
        log.debug("program header: {any}", .{phdr});

        if (phdr.p_type == elf.PT_LOAD) {
            kernel_addr_start = @min(kernel_addr_start, phdr.p_vaddr);
            kernel_addr_end = @max(kernel_addr_end, phdr.p_vaddr + phdr.p_memsz);
        }
    }

    // TODO: 4K pages... maybe do 2M instead?
    const num_kernel_pages = (kernel_addr_end - kernel_addr_start + 4095) / 4096;

    log.info("allocating {d} kernel pages for {x}-{x} ({x} bytes)", .{
        num_kernel_pages,
        kernel_addr_start,
        kernel_addr_end,
        kernel_addr_end - kernel_addr_start,
    });
    var kmem: [*]align(4096) u8 = undefined;
    try boot_services.allocatePages(
        .allocate_any_pages,
        .loader_code,
        num_kernel_pages,
        &kmem,
    ).err();
    const kmem_ptr: usize = @intFromPtr(kmem);
    log.info("kernel memory at {x}", .{kmem_ptr});
    @memset(blk: {
        const res: [*]u8 = @alignCast(kmem);
        break :blk res[0 .. kernel_addr_end - kernel_addr_start];
    }, 0);

    log.info("loading kernel into memory", .{});
    pheaders = elf_header.program_header_iterator(@constCast(kernel));
    while (pheaders.next() catch |err| {
        log.err("failed to read program header: {any}", .{err});
        return uefi.Status.Error.CompromisedData;
    }) |phdr| {
        if (phdr.p_type == elf.PT_LOAD) {
            log.debug("loading at offset {x}..+{x}", .{ phdr.p_vaddr, phdr.p_filesz });
            const off = phdr.p_vaddr - kernel_addr_start;
            const dest = kmem[off .. off + phdr.p_filesz];
            @constCast(kernel).seekableStream().seekTo(phdr.p_offset) catch |err| {
                log.err("failed to seek kernel image: {any}", .{err});
                return uefi.Status.Error.CompromisedData;
            };
            @constCast(kernel).reader().readNoEof(dest) catch |err| {
                log.err("failed to read kernel image: {any}", .{err});
                return uefi.Status.Error.CompromisedData;
            };
        }
    }

    log.info("blossom successfully loaded", .{});

    return @ptrFromInt(@intFromPtr(kmem) + elf_header.entry - kernel_addr_start);
}

pub const panic = std.debug.FullPanic(panicFn);

fn panicFn(msg: []const u8, stacktrace: ?usize) noreturn {
    printing: {
        const console = uefi.system_table.con_out.?;
        console.outputString(unicode.utf8ToUtf16LeStringLiteral("\r\nbootloader panicked")).err() catch break :printing;
        if (stacktrace) |st| {
            var buffer: [64]u8 = undefined;
            var stream = std.io.fixedBufferStream(buffer[0..]);
            stream.writer().print(" at 0x{x}", .{st}) catch break :printing;
            var buf: [64]u16 = undefined;
            const len = unicode.utf8ToUtf16Le(buf[0..63], stream.getWritten()) catch break :printing;
            buf[len] = 0;
            console.outputString(buf[0..len :0]).err() catch break :printing;
        }

        console.outputString(unicode.utf8ToUtf16LeStringLiteral(": ")).err() catch break :printing;
        var buf: [64]u16 = undefined;
        const len = unicode.utf8ToUtf16Le(buf[0..63], msg) catch break :printing;
        buf[len] = 0;
        console.outputString(buf[0..len :0]).err() catch break :printing;
        console.outputString(unicode.utf8ToUtf16LeStringLiteral("\r\n")).err() catch break :printing;
    }

    const boot_services = uefi.system_table.boot_services orelse while (true) {};
    _ = boot_services.exit(uefi.handle, uefi.Status.aborted, 0, null);
    while (true) {
        // boot_services.exit should've exited the program
    }
}
