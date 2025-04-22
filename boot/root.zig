const builtin = @import("builtin");
const std = @import("std");
const elf = std.elf;
const log = std.log;
const uefi = std.os.uefi;
const protocol = uefi.protocol;
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

const logging = @import("logging.zig");

pub const std_options = std.Options{
    .logFn = logging.logFn,
};

pub fn main() (uefi.UnexpectedError || uefi.Error)!void {
    log.info("hello, world!", .{});
    const boots = uefi.system_table.boot_services.?;

    const loader_image = try boots.handleProtocol(
        protocol.LoadedImage,
        uefi.handle,
    ) orelse unreachable;
    // log.debug("found loader image at 0x{X}", .{@intFromPtr(loader_image.image_base)});

    const storage_device = loader_image.device_handle orelse
        return error.NotFound;

    const fs = try boots.handleProtocol(
        protocol.SimpleFileSystem,
        storage_device,
    ) orelse unreachable;
    log.debug("opened fs", .{});

    const vol = try fs.openVolume();
    const kernel_file = try vol.open(utf16("efi\\boot\\blossomk"), .read, .{});
    log.info("loaded kernel file", .{});

    const elf_header = elf.Header.read(kernel_file) catch |err| {
        log.err("failed to read elf header: {!}", .{err});
        return error.CompromisedData;
    };
    std.debug.assert(elf_header.is_64);

    var pheaders = elf_header.program_header_iterator(kernel_file);

    var kernel_addr_start: usize = std.math.maxInt(u64);
    var kernel_addr_end: usize = 0;
    while (try nextPHeader(&pheaders)) |phdr| {
        if (phdr.p_type != .LOAD) continue;
        log.debug("load kernel segment: vaddr=0x{X} memsz=0x{X}", .{
            phdr.p_vaddr, phdr.p_memsz,
        });
        kernel_addr_start = @min(kernel_addr_start, phdr.p_vaddr);
        kernel_addr_end = @max(kernel_addr_end, phdr.p_vaddr + phdr.p_memsz);
    }

    const page_size = @sizeOf(uefi.Page);
    const num_kernel_pages = (kernel_addr_end - kernel_addr_start + page_size - 1) / page_size;
    log.debug(
        "allocating {d} pages for kernel addrs 0x{X}-{X}",
        .{ num_kernel_pages, kernel_addr_start, kernel_addr_end },
    );

    const kernel_pages = try boots.allocatePages(
        .allocate_any_pages,
        .loader_data,
        num_kernel_pages,
    );
    for (kernel_pages) |*page|
        @memset(page[0..], 0);

    var kernel_memory = @as([*]align(4096) u8, @ptrCast(kernel_pages.ptr))[0 .. num_kernel_pages * page_size];
    pheaders.index = 0;
    while (try nextPHeader(&pheaders)) |phdr| {
        switch (phdr.p_type) {
            .LOAD => {
                const off = phdr.p_vaddr - kernel_addr_start;
                const dest = kernel_memory[off .. off + phdr.p_filesz];
                try kernel_file.setPosition(phdr.p_offset);
                kernel_file.reader().readNoEof(dest) catch |err| {
                    log.err("failed to read kernel file: {!}", .{err});
                    return errorUnionFallback(uefi.Error, err, error.Aborted);
                };
            },

            else => {},
        }
    }

    log.info("kernel loaded", .{});
    // const mmap = try boots.getMemoryMapInfo();
    // log.info("mmap key: {d}", .{@intFromEnum(mmap.key)});
    // try boots.exitBootServices(uefi.handle, mmap.key);
    boots.exitBootServices(uefi.handle, @enumFromInt(123)) catch |err|
        switch (err) {
            error.InvalidParameter => {
                log.debug("ignoring invalid parameter to exitBootServices", .{});
            },
            else => return err,
        };

    log.info("exited boot services", .{});
    const entry_addr = kernel_memory.ptr[elf_header.entry - kernel_addr_start ..];
    const entry: *const fn () callconv(.c) usize = @ptrCast(@alignCast(entry_addr));
    log.info("entering kernel at 0x{X}", .{entry});
    const res = entry();
    log.info("kernel returned {d}", .{res});
}

fn nextPHeader(
    pheaders: *elf.ProgramHeaderIterator(*protocol.File),
) !?elf.elf64.Phdr {
    return pheaders.next() catch |err| {
        log.err("failed to read pheader: {!}", .{err});
        return errorUnionFallback(uefi.Error, err, error.Aborted);
    };
}

fn errorUnionFallback(
    ErrorSet: type,
    err: anyerror,
    fallback: ErrorSet,
) ErrorSet {
    if (isErrorUnion(ErrorSet, err))
        return @errorCast(err);
    return fallback;
}

fn isErrorUnion(ErrorSet: type, err: anyerror) bool {
    const errors = @typeInfo(ErrorSet).error_set orelse
        return false;
    inline for (errors) |set_error|
        if (std.mem.eql(u8, @errorName(err), set_error.name))
            return true;

    return false;
}
