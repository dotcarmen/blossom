const std = @import("std");
const fmt = std.fmt;
const Io = std.Io;

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;
const SCROLL_HEIGHT = 3;

comptime {
    std.debug.assert(SCROLL_HEIGHT > 0);
}

pub const Color = enum(u4) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_gray = 7,
    dark_gray = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    light_brown = 14,
    white = 15,

    pub const Settings = packed struct(u8) {
        foreground: Color = .white,
        background: Color = .black,
    };
};

const ColoredChar = packed struct(u16) {
    char: u8,
    // color in the high byte
    color: Color.Settings,
};

var curr_row: usize = 0;
var curr_col: usize = 0;
var curr_color: Color.Settings = .{};
var vga_buffer: [*]volatile ColoredChar = @ptrFromInt(0xB8000);

pub const writer: Io.Writer = .{
    // no need to buffer writes
    .buffer = &.{},
    .vtable = &Io.Writer.VTable{
        // drain is the only method that needs to be implemented
        .drain = drain,
        .flush = Io.Writer.noopFlush,
    },
};

pub fn init() void {
    for (0..VGA_HEIGHT) |row| {
        for (0..VGA_WIDTH) |col| {
            const entry = getChar(row, col);
            entry.* = .{ .char = ' ', .color = curr_color };
        }
    }
}

fn getChar(row: usize, col: usize) *ColoredChar {
    return &vga_buffer[row * VGA_WIDTH + col];
}

fn scroll() void {
    for (0..VGA_HEIGHT - SCROLL_HEIGHT) |new_row| {
        const old_row = new_row + SCROLL_HEIGHT;
        for (0..VGA_WIDTH) |col| {
            const old_char = getChar(old_row, col);
            const new_char = getChar(new_row, col);
            new_char.* = old_char.*;
            new_char.* = .{ .char = ' ', .color = curr_color };
        }
    }
}

fn putChar(ch: u8) void {
    defer if (curr_row >= VGA_HEIGHT) {
        scroll();
        curr_row -= SCROLL_HEIGHT;
    };

    if (ch == '\n') {
        curr_row += 1;
        curr_col = 0;
        return;
    }

    const entry = getChar(curr_row, curr_col);
    entry.* = .{ .char = ch, .color = curr_color };

    curr_col += 1;
    if (curr_col >= VGA_WIDTH) {
        curr_col = 0;
        curr_row += 1;
    }
}

fn drain(
    _: *Io.Writer,
    data: []const []const u8,
    splat: usize,
) Io.Writer.Error!void {
    for (data[0..data.len]) |ent|
        for (ent) |ch|
            putChar(ch);

    for (0..splat) |_|
        for (data[data.len - 1]) |ch|
            putChar(ch);
}

pub fn setColor(new_color: Color.Settings) void {
    curr_color = new_color;
}

pub fn print(comptime format: []const u8, args: anytype) Io.Writer.Error!void {
    try writer.print(format, args);
}

// fn vgaEntryColor(fg: ConsoleColors, bg: ConsoleColors) u8 {
//     return @intFromEnum(fg) | (@intFromEnum(bg) << 4);
// }

// fn vgaEntry(uc: u8, new_color: u8) u16 {
//     const c: u16 = new_color;

//     return uc | (c << 8);
// }

// pub fn initialize() void {
//     clear();
// }

// pub fn setColor(new_color: u8) void {
//     color = new_color;
// }

// pub fn clear() void {
//     @memset(buffer[0..VGA_SIZE], vgaEntry(' ', color));
// }

// pub fn putCharAt(c: u8, new_color: u8, x: usize, y: usize) void {
//     const index = y * VGA_WIDTH + x;
//     buffer[index] = vgaEntry(c, new_color);
// }

// pub fn putChar(c: u8) void {
//     putCharAt(c, color, column, row);
//     column += 1;
//     if (column == VGA_WIDTH) {
//         column = 0;
//         row += 1;
//         if (row == VGA_HEIGHT)
//             row = 0;
//     }
// }

// pub fn puts(data: []const u8) void {
//     for (data) |c|
//         putChar(c);
// }

// pub const writer = Writer(void, error{}, callback){ .context = {} };

// fn callback(_: void, string: []const u8) error{}!usize {
//     puts(string);
//     return string.len;
// }

// pub fn printf(comptime format: []const u8, args: anytype) void {
//     fmt.format(writer, format, args) catch unreachable;
// }
