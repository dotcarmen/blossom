const builtin = @import("builtin");
const std = @import("std");
const uefi = std.os.uefi;

const klog = @import("klog.zig");

pub const std_options = std.Options{
    .logFn = klog.logfn,
};

pub fn kmain() callconv(.c) usize {
    return 42;
}

comptime {
    if (builtin.is_test) {
        if (@import("root") == @This()) {
            @export(&kmain, .{ .name = "_start" });
        }
    } else {
        @export(&kmain, .{ .name = "_start" });
    }
}
