const builtin = @import("builtin");
const std = @import("std");
const log = std.log;
const uefi = std.os.uefi;
const unicode = std.unicode;

const logging = @import("logging.zig");

pub const std_options = std.Options{
    .logFn = logging.logFn,
};

pub fn main() std.os.uefi.Status {
    log.info("hello, world!", .{});

    if (builtin.is_test) {
        const logger = log.scoped(.tester);
        logger.info("running tests...", .{});
        for (builtin.test_functions) |test_fn| {
            logger.debug("running test {s}...", .{test_fn.name});
            logger.info("{s}: {s}", .{ test_fn.name, "pass" });
        }
    }

    while (true) {}

    return .success;
}
