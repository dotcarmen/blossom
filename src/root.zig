export fn _start() void {
    
}

// const MAX_STACK_SIZE = 1024 * 1024;

// pub const Console = @import("Console.zig");

// const builtin = @import("builtin");

// const std = @import("std");

// const MultibootHeader = extern struct {
//     pub const MAGIC: u32 = 0xE85250D6;

//     comptime {
//         std.debug.assert(std.mem.Alignment.of(MultibootHeader) == .@"4");
//     }

//     magic: u32 align(4) = MAGIC,
//     flags: u32,
//     checksum: i32,
//     padding: u32 = 0,

//     pub const Flags = packed struct(u32) {
//         /// align loaded modules on page boundaries
//         @"align": bool = false,
//         /// provide memory map
//         meminfo: bool = false,
//         _pad: u30 = 0,
//     };
// };

// export var stack_bytes: [MAX_STACK_SIZE]u8 = undefined;

// export fn _start() callconv(.naked) noreturn {
//     asm volatile (switch (builtin.cpu.arch) {
//             .aarch64 =>
//             \\ ldr x30, =%[stack_top]
//             \\ mov sp, x30
//             \\ bl %[kmain]
//             \\ b .
//             ,
//             inline else => |arch| @compileError("unsupported architecture " ++ @tagName(arch)),
//         }
//         :
//         : [stack_top] "i" (stack_top: {
//             const stack_ptr: [*]align(16) u8 = &stack_bytes;
//             const stack_top: [*]align(16) u8 = stack_ptr + MAX_STACK_SIZE;
//             break :stack_top stack_top;
//           }),
//           [kmain] "X" (&kmain),
//     );
// }

// fn kmain() void {
//     Console.print("hello, world!", .{}) catch unreachable;
// }
