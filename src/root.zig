const limine = @import("limine");
const std = @import("std");

const assert = std.debug.assert;

export fn _start() void {
    kmain() catch |err| {
        std.debug.panic("blossom kernel failed: {s}", .{@errorName(err)});
    };
}

pub const Error = error{
    LimineResponseMissing,
};

pub const limine_requests = struct {
    export var __start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};
    export var __end_marker: limine.RequestsEndMarker linksection(".limine_requests_end") = .{};

    export var base_revision: limine.BaseRevision linksection(".limine_requests") = .{};
    export var framebuffer: limine.Framebuffer.Request linksection(".limine_requests") = .{};
};

pub fn kmain() (limine.BaseRevision.UnsupportedRevisionError || Error)!noreturn {
    const loaded_revision = try limine_requests.base_revision.loadedRevision();
    assert(loaded_revision == 3);

    const framebuffer_response = limine_requests.framebuffer.response orelse return error.LimineResponseMissing;
    const framebuffer = framebuffer_response.getFramebuffers()[0];
    for (0..100) |i| {
        const fb_ptr: [*]volatile u32 = @ptrCast(@alignCast(framebuffer.address));
        fb_ptr[i * (framebuffer.pitch / 4) + i] = 0xff0000;
    }

    hcf();
}

fn hcf() noreturn {
    while (true) {
        switch (@import("builtin").cpu.arch) {
            .x86_64 => asm volatile ("hlt"),
            .aarch64 => asm volatile ("wfi"),
            .riscv64 => asm volatile ("wfi"),
            .loongarch64 => asm volatile ("idle 0"),
            else => unreachable,
        }
    }
}
