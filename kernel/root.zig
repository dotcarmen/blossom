const builtin = @import("builtin");
const std = @import("std");
const log = std.log;
const uefi = std.os.uefi;

const options = @import("$options");

pub const klog = @import("klog.zig");

pub const std_options = std.Options{
    .logFn = klog.logfn,
    .page_size_min = options.page_size,
    .page_size_max = options.page_size,
    .queryPageSize = struct {
        fn queryPageSize() usize {
            return options.page_size;
        }
    }.queryPageSize,
};

pub fn kmain() callconv(.c) usize {
    log.info("hello, kernel world!", .{});
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
