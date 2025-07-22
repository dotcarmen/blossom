const limine = @import("limine");

const requests = struct {
    export var __start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};
    export var __end_marker: limine.RequestsEndMarker linksection(".limine_requests_end") = .{};

    export var base_revision: limine.BaseRevision linksection(".limine_requests") = .{};
    export var framebuffer: limine.FramebufferRequest linksection(".limine_requests") = .{};
};

export fn _start() void {
    if (!requests.base_revision.isSupported()) {
        @panic("limine revision not supported");
    }

    if (requests.framebuffer.response) |framebuffer_response| {
        const framebuffer = framebuffer_response.getFramebuffers()[0];
        for (0..100) |i| {
            const fb_ptr: [*]volatile u32 = @ptrCast(@alignCast(framebuffer.address));
            fb_ptr[i * (framebuffer.pitch / 4) + i] = 0xff0000;
        }
    } else {
        @panic("Framebuffer response not present");
    }

    hcf();
}

fn hcf() void {
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
