const Composite = @This();
const std = @import("std");

const assert = std.debug.assert;

pub const Flags = packed struct {
    args_1_and_2_are_words: bool,
    args_are_xy_values: bool,
    round_xy_to_grid: bool,
    we_have_a_scale: bool,
    _reserved0: u1 = 0,
    more_components: bool,
    we_have_an_x_and_y_scale: bool,
    we_have_a_two_by_two: bool,
    we_have_instructions: bool,
    use_my_metrics: bool,
    overlap_compound: bool,
    scaled_component_offset: bool,
    unscaled_component_offset: bool,
    _reserved1: u3 = 0,
};

pub const Arg = extern union {
    xy: i16,
    point: u16,
};

flags: Flags,
glyph_index: u16,
arg1: Arg,
arg2: Arg,
x_scale: u16,
x_scale_y_coefficient: u16,
y_scale: u16,
y_scale_x_coefficient: u16,
_next: ?[*]const u8,

pub fn next(self: Composite) ?Composite {
    return if (self._next) |n| read(n) else null;
}

fn read(bytes: [*]const u8) Composite {
    const util = struct {
        fn read(b: [*]const u8, T: type) struct { T, [*]const u8 } {
            assert(std.mem.isAligned(@intFromPtr(b), @alignOf(T)));
            const ts: [*]const T = @alignCast(@ptrCast(b));
            return .{ ts[0], b[1..] };
        }
    };

    var b: [*]const u8 = bytes;
    const flags, b = util.read(b, Flags);
    const glyph_index, b = util.read(b, u16);

    const arg1: Arg, const arg2: Arg =
        if (flags.args_1_and_2_are_words) args: {
            const arg1, b = util.read(b, u16);
            const arg2, b = util.read(b, u16);
            if (!flags.args_are_xy_values)
                break :args .{ .{ .point = arg1 }, .{ .point = arg2 } };
            const arg1_signed: i16 = @bitCast(arg1);
            const arg2_signed: i16 = @bitCast(arg2);
            // no need to sign-extend i16s
            break :args .{ .{ .xy = arg1_signed }, .{ .xy = arg2_signed } };
        } else args: {
            const arg1, b = util.read(b, u8);
            const arg2, b = util.read(b, u8);
            if (!flags.args_are_xy_values)
                break :args .{ .{ .point = arg1 }, .{ .point = arg2 } };
            const arg1_i8: i8 = @bitCast(arg1);
            const arg2_i8: i8 = @bitCast(arg2);
            // sign-extend i8s
            const arg1_i16: i16 = @intCast(arg1_i8);
            const arg2_i16: i16 = @intCast(arg2_i8);
            break :args .{ .{ .xy = arg1_i16 }, .{ .xy = arg2_i16 } };
        };

    const x_scale, const y_scale_x_coefficient, const x_scale_y_coefficient, const y_scale =
        if (flags.we_have_a_scale) scales: {
            const scale, b = util.read(b, u16);
            break :scales .{ scale, 0, 0, scale };
        } else if (flags.we_have_an_x_and_y_scale) scales: {
            const x_scale, b = util.read(b, u16);
            const y_scale, b = util.read(b, u16);
            break :scales .{ x_scale, 0, 0, y_scale };
        } else if (flags.we_have_a_two_by_two) scales: {
            const x_scale, b = util.read(b, u16);
            const y_scale_x_coefficient, b = util.read(b, u16);
            const x_scale_y_coefficient, b = util.read(b, u16);
            const y_scale, b = util.read(b, u16);
            break :scales .{ x_scale, x_scale_y_coefficient, y_scale_x_coefficient, y_scale };
        } else .{ 1, 0, 0, 1 };

    return .{
        .flags = flags,
        .glyph_index = glyph_index,
        .arg1 = arg1,
        .arg2 = arg2,
        .x_scale = x_scale,
        .x_scale_y_coefficient = x_scale_y_coefficient,
        .y_scale = y_scale,
        .y_scale_x_coefficient = y_scale_x_coefficient,
        ._next = if (flags.more_components) b else null,
    };
}
