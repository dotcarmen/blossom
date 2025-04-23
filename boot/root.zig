const KernelImage = @import("KernelImage.zig");
const logging = @import("logging.zig");

const builtin = @import("builtin");
const std = @import("std");
const elf = std.elf;
const log = std.log;
const mem = std.mem;
const uefi = std.os.uefi;
const protocol = uefi.protocol;
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;
const Error = uefi.Error;

const kernel = @import("$kernel");

pub const std_options = std.Options{
    .logFn = logging.logFn,
};

pub fn main() Error!void {
    log.info("bootloader running", .{});

    const image = try KernelImage.load();
    log.info("kernel image loaded", .{});

    var pheaders = image.programHeaders().iterator();

    var kernel_addr_start: usize = std.math.maxInt(u64);
    var kernel_addr_end: usize = 0;
    while (try pheaders.next()) |phdr| {
        if (phdr.p_type != .LOAD) continue;
        log.debug(
            "load kernel segment: vaddr=0x{X} memsz=0x{X}",
            .{ phdr.p_vaddr, phdr.p_memsz },
        );

        kernel_addr_start = @min(kernel_addr_start, phdr.p_vaddr);
        kernel_addr_end = @max(kernel_addr_end, phdr.p_vaddr + phdr.p_memsz);
    }

    const page_size = @sizeOf(uefi.Page);
    const num_kernel_pages = (kernel_addr_end - kernel_addr_start + page_size - 1) / page_size;
    log.debug(
        "allocating {d} pages for kernel addrs 0x{X}-{X}",
        .{ num_kernel_pages, kernel_addr_start, kernel_addr_end },
    );

    const boots = uefi.system_table.boot_services.?;
    const kernel_pages = try boots.allocatePages(
        .allocate_any_pages,
        .loader_data,
        num_kernel_pages,
    );
    for (kernel_pages) |*page|
        @memset(page[0..], 0);

    var kernel_memory: [*]align(4096) u8 = @ptrCast(kernel_pages.ptr);
    log.debug(
        "kernel memory starts at 0x{X}",
        .{@intFromPtr(kernel_memory)},
    );

    pheaders.index = 0;
    while (try pheaders.next()) |phdr| {
        if (phdr.p_type != .LOAD) {
            log.debug(
                "skipping non-load phdr: {}",
                .{phdr.p_type},
            );
            continue;
        }

        const off = phdr.p_vaddr - kernel_addr_start;
        const dest = kernel_memory[off .. off + phdr.p_filesz];
        try image.file.setPosition(phdr.p_offset);
        image.file.reader().readNoEof(dest) catch |err|
            return catchError(err, "reading kernel load");
    }

    log.info("kernel loaded into memory", .{});
    const symbols = (image.header.findSymbolTable(image.file) catch |err|
        return catchError(err, "reading symbol table")) orelse
        return Error.LoadError;
    log.info(
        "symbol table: len={d} last_local_symbol={?d} string_table_index={d}",
        .{ symbols.len, symbols.last_local_symbol, symbols.string_table_index },
    );

    var mmap_buf: [4096]u8 align(@alignOf(uefi.tables.MemoryDescriptor)) = undefined;
    const mmap_slice = try boots.getMemoryMap(mmap_buf[0..]);
    var mmap_iter = mmap_slice.iterator();
    while (mmap_iter.next()) |mdesc| {
        log.info(
            "memory descriptor {}: 0x{X} (0x{X}) size(pages)={d}",
            .{
                mdesc.type,
                mdesc.physical_start,
                mdesc.virtual_start,
                mdesc.number_of_pages,
            },
        );
    }

    var sections = image.sectionHeaders().iterator();
    const section_names = (image.header.sectionNames(image.file) catch |err|
        return catchError(err, "getting section names table")) orelse
        return Error.LoadError;
    while (try sections.next()) |section| {
        var namebuf: [128]u8 = undefined;
        const name = (section_names.get(section.sh_name, namebuf[0..]) catch |err|
            return uefi.toError(err, Error.LoadError)) orelse
            continue;

        const ksection = kernel_sections.get(name) orelse continue;
        log.debug("found kernel section: {s}", .{@tagName(ksection)});

        // uefi.system_table.runtime_services.setVirtualAddressMap(map: MemoryMapSlice)

        switch (ksection) {
            .logger => {
                log.info(
                    "setting kernel logger at 0x{X}",
                    .{section.sh_addr},
                );

                const logger_ptr: *kernel.klog = if (mmap_slice.findPointer(@ptrFromInt(section.sh_addr), .physical) != null)
                    @ptrFromInt(section.sh_addr)
                else
                    unreachable;

                logger_ptr.* = .{ .write = klog_write };
            },
        }
    }

    log.info("exiting boot services", .{});
    boots.exitBootServices(uefi.handle, @enumFromInt(123)) catch |err| {
        if (err != Error.InvalidParameter)
            return catchError(err, "exiting boot services");
        log.debug("ignoring invalid parameter error from exitBootServices", .{});
    };

    log.info("exited boot services", .{});
    const entry_addr = kernel_memory[image.header.entry - kernel_addr_start ..];
    const entry: *const fn () callconv(.c) usize = @ptrCast(@alignCast(entry_addr));

    log.info(
        "entering kernel at 0x{X} (e_entry: 0x{X})",
        .{ @intFromPtr(entry), image.header.entry },
    );
    const res = entry();
    log.info("kernel returned {d}", .{res});
}

fn catchError(err: anyerror, comptime action: []const u8) uefi.Error {
    log.err("error " ++ action ++ ": {!}", .{err});
    return uefi.toError(err, Error.LoadError);
}

const KernelSection = enum {
    logger,
};

const kernel_sections = std.StaticStringMap(KernelSection).initComptime(.{
    .{ ".kernel.logger", .logger },
});

fn klog_write(len: usize, ptr: [*]const u8) callconv(.c) void {
    const console = uefi.system_table.con_out.?;

    var buffer: [512]u16 = undefined;
    var offset: usize = 0;
    while (offset < len) {
        const bw = std.unicode.utf8ToUtf16Le(buffer[0..511], ptr[offset..len]) catch
            @panic("invalid utf-8 passed to klog_write");
        buffer[bw] = 0;
        _ = console.outputString(buffer[0..bw :0].ptr) catch |err| {
            std.debug.panic("error writing to console: {!}", .{err});
        };
        offset += bw;
    }
}
