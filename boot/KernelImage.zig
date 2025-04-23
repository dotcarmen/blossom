const KernelImage = @This();

const std = @import("std");
const elf = std.elf;
const log = std.log.scoped(.kernel_image);
const math = std.math;
const uefi = std.os.uefi;

const elf64 = elf.elf64;
const protocol = uefi.protocol;
const tables = uefi.tables;

const Error = uefi.Error;

file: *protocol.File,
header: elf.Header,

pub fn load() Error!KernelImage {
    const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;

    const boots = uefi.system_table.boot_services.?;
    const loader_image = try boots.handleProtocol(
        protocol.LoadedImage,
        uefi.handle,
    ) orelse return Error.LoadError;
    log.debug("got bootloader image", .{});

    const storage_device = loader_image.device_handle orelse
        return Error.NotFound;

    const fs = try boots.handleProtocol(
        protocol.SimpleFileSystem,
        storage_device,
    ) orelse unreachable;

    const vol = try fs.openVolume();
    const file = try vol.open(utf16("efi\\boot\\blossomk"), .read, .{});
    log.info("opened kernel file from `efi\\boot\\blossomk`", .{});

    const header = elf.Header.read(file) catch |err|
        return uefi.toError(err, Error.LoadError);

    return KernelImage{ .file = file, .header = header };
}

pub fn programHeaders(self: KernelImage) ProgramHeaders {
    return .{ .inner = .new(&self.header, self.file) };
}

pub fn sectionHeaders(self: KernelImage) SectionHeaders {
    return .{ .inner = .new(&self.header, self.file) };
}

const ProgramHeaders = struct {
    inner: elf.ProgramHeaders(*protocol.File),

    pub fn get(self: *const ProgramHeaders, index: u16) Error!?elf64.Phdr {
        const phdr = self.inner.get(index) catch |err|
            return uefi.toError(err, Error.LoadError);
        return phdr;
    }

    pub fn iterator(self: ProgramHeaders) Iterator {
        return .{ .pheaders = self };
    }

    pub const Iterator = struct {
        pheaders: ProgramHeaders,
        index: u16 = 0,

        pub fn next(self: *Iterator) Error!?elf64.Phdr {
            const result = try self.pheaders.get(self.index) orelse return null;
            self.index += 1;
            return result;
        }
    };
};

const SectionHeaders = struct {
    inner: elf.SectionHeaders(*protocol.File),

    pub fn get(self: *const SectionHeaders, index: u16) Error!?elf64.Shdr {
        const shdr = self.inner.get(index) catch |err|
            return uefi.toError(err, Error.LoadError);
        return shdr;
    }

    pub fn iterator(self: SectionHeaders) Iterator {
        return .{ .sheaders = self };
    }

    pub const Iterator = struct {
        sheaders: SectionHeaders,
        index: u16 = 0,

        pub fn next(self: *Iterator) Error!?elf64.Shdr {
            const result = try self.sheaders.get(self.index) orelse return null;
            self.index += 1;
            return result;
        }
    };
};
