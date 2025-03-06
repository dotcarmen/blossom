const builtin = @import("builtin");
const std = @import("std");
const lib = @import("root.zig");

pub export fn main() std.os.uefi.Status {
    lib.printLiteral("hello, world!\r\n");

    if (builtin.is_test) {
        lib.printLiteral("running tests: ");
        for (builtin.test_functions) |test_fn| {
            lib.print(test_fn.name);
            lib.printLiteral("ok");
        }
    }

    while (true) {}

    return .success;
}
