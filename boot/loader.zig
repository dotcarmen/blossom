const Loader = @This();
const options = @import("options");

const builtin = @import("builtin");
const std = @import("std");
const log = std.log.scoped(.os_loader);
const uefi = std.os.uefi;
const protocol = uefi.protocol;
const tables = uefi.tables;
const Status = uefi.Status;
const Error = Status.Error || uefi.UnexpectedError;

boots: *tables.BootServices,
fs: *protocol.SimpleFileSystem,

kernel_path: []const u16,
kernel_file: *protocol.File,
elf_header: std.elf.Header,

kernel_pages: [*]align(options.page_size) u8,
kernel_addr_start: usize,
kernel_addr_end: usize,

pub fn init(
    boots: *tables.BootServices,
    kernel_path: [*:0]const u16,
) Error!Loader {
    var self: Loader = undefined;
    self.boots = boots;
    var path_len: usize = 0;
    while (kernel_path[path_len] != 0) path_len += 1;
    self.kernel_path = kernel_path[0..path_len];

    const loader_image = try boots.openProtocolSt(protocol.LoadedImage, uefi.handle);
    log.debug("found loader image", .{});
    const storage_device = loader_image.device_handle orelse return Status.Error.NotFound;
    self.fs = try boots.openProtocolSt(protocol.SimpleFileSystem, storage_device);
    log.debug("opened dir", .{});

    const vol = try self.fs.openVolume();
    self.kernel_file = try vol.open(
        kernel_path,
        .read,
        .{ .read_only = true },
    );
    log.info("loaded kernel file", .{});

    self.elf_header = std.elf.Header.read(self.kernel_file) catch |err| {
        log.err("failed to read elf header: {!}", .{err});
        return Error.CompromisedData;
    };
    if (!self.elf_header.is_64) {
        log.err("blossom only supports 64-bit systems", .{});
        return Error.Unsupported;
    }

    var pheaders = self.elf_header.program_header_iterator(self.kernel_file);

    self.kernel_addr_start = std.math.maxInt(u64);
    self.kernel_addr_end = 0;
    while (try nextPHeader(&pheaders)) |phdr| {
        if (phdr.p_type == std.elf.PT_LOAD) {
            log.debug("load kernel segment: vaddr=0x{X}, memsz=0x{X}", .{ phdr.p_vaddr, phdr.p_memsz });
            self.kernel_addr_start = @min(self.kernel_addr_start, phdr.p_vaddr);
            self.kernel_addr_end = @max(self.kernel_addr_end, phdr.p_vaddr + phdr.p_memsz);
        }
    }

    const num_kernel_pages = (self.kernel_addr_end - self.kernel_addr_start + options.page_size - 1) / options.page_size;
    log.debug("allocating {d} pages (sized {d}) for kernel addrs 0x{X}-0x{X}", .{
        num_kernel_pages,
        options.page_size,
        self.kernel_addr_start,
        self.kernel_addr_end,
    });
    try boots.allocatePages(
        .allocate_any_pages,
        .loader_data,
        num_kernel_pages,
        &self.kernel_pages,
    ).err();
    log.debug("kernel address 0x{X}", .{@intFromPtr(self.kernel_pages)});
    @memset(self.kernel_pages[0 .. self.kernel_addr_end - self.kernel_addr_start], 0);

    return self;
}

fn nextPHeader(headers: *std.elf.ProgramHeaderIterator(*protocol.File)) Error!?std.elf.Elf64_Phdr {
    return headers.next() catch |err| {
        log.err("failed to read program header: {!}", .{err});
        return switch (err) {
            protocol.File.SeekError.Unsupported => Error.Unsupported,
            protocol.File.SeekError.DeviceError => Error.DeviceError,
            protocol.File.ReadError.NoMedia => Error.NoMedia,
            // DeviceError already handled
            protocol.File.ReadError.VolumeCorrupted => Error.VolumeCorrupted,
            protocol.File.ReadError.BufferTooSmall => Error.BufferTooSmall,
            else => Error.Aborted,
        };
    };
}

pub fn load(self: *Loader) Error!void {
    log.info("loading kernel into memory", .{});
    var headers = self.elf_header.program_header_iterator(self.kernel_file);
    while (try nextPHeader(&headers)) |phdr| {
        if (phdr.p_type == std.elf.PT_LOAD) {
            log.debug("loading segment at 0x{X}..+0x{X}", .{ phdr.p_vaddr, phdr.p_filesz });
            const off = phdr.p_vaddr - self.kernel_addr_start;
            const dest = self.kernel_pages[off .. off + phdr.p_filesz];
            try self.kernel_file.setPosition(phdr.p_offset);
            self.kernel_file.reader().readNoEof(dest) catch |err| {
                log.err("failed to read kernel image segment: {!}", .{err});
                return switch (err) {
                    protocol.File.ReadError.NoMedia => Error.NoMedia,
                    protocol.File.ReadError.DeviceError => Error.DeviceError,
                    protocol.File.ReadError.VolumeCorrupted => Error.VolumeCorrupted,
                    protocol.File.ReadError.BufferTooSmall => Error.BufferTooSmall,
                    else => Error.Aborted,
                };
            };
        }
    }
    log.info("successfully loaded kernel into memory", .{});
}

pub inline fn entry_addr(self: *const Loader) usize {
    const addr: usize = @intFromPtr(self.kernel_pages);
    log.debug("kernel entry addr is 0x{X}", .{self.elf_header.entry});
    return addr + self.elf_header.entry - self.kernel_addr_start;
}
