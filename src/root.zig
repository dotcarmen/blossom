//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const uefi = std.os.uefi;
const unicode = std.unicode;

// pub export fn main() std.os.uefi.Status {
//     printLiteral("hello, world!\r\n");

//     if (builtin.is_test) {
//         printLiteral("running tests: ");
//         for (builtin.test_functions) |test_fn| {
//             print(test_fn.name);
//             printLiteral("ok");
//         }
//     }

//     while (true) {}

//     return .success;
// }

pub fn printLiteral(comptime str: []const u8) void {
    _ = uefi.system_table.con_out.?.outputString(
        unicode.utf8ToUtf16LeStringLiteral(str),
    );
}

pub fn print(str: []const u8) void {
    var idx: usize = 0;
    var buf: [64]u16 = undefined;
    while (idx < str.len) {
        idx = unicode.utf8ToUtf16Le(buf[0..64], str[idx..]) catch return;
        buf[63] = 0;
        _ = uefi.system_table.con_out.?.outputString(buf[0..64 :0]);
    }
}

// pub export fn add(a: i32, b: i32) i32 {
//     return a + b;
// }

// test "basic add functionality" {
//     try testing.expect(add(3, 7) == 10);
// }
