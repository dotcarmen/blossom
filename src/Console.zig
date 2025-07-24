const std = @import("std");
const assert = std.debug.assert;
const bytesToValue = std.mem.bytesToValue;

pub const source: []const u8 = @embedFile("../font/HackNerdFontMono-Regular.ttf");

const reader: std.Io.Reader = .fixed(source);
