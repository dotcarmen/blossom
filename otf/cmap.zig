const std = @import("std");
const assert = std.debug.assert;

pub const EncodingRecord = extern struct {
    platform_id: PlatformId,
    encoding_id: EncodingId,
    subtable_offset: u32,

    pub fn getSubtable(self: *const EncodingRecord) *const Subtable {
        const subtable_alignment = @alignOf(Subtable);
        assert(self.subtable_offset % subtable_alignment == 0);
        const bytes: [*]align(subtable_alignment) const u8 = @ptrCast(self);
        const subtable_ptr: [*]align(subtable_alignment) const u8 = @alignCast(bytes + self.subtable_offset);
        return @ptrCast(subtable_ptr);
    }

    pub const EncodingId = enum(u16) {
        _,

        pub fn toUnicode(self: EncodingId) Unicode {
            return @enumFromInt(@intFromEnum(self));
        }

        pub const Unicode = enum(u16) {
            /// deprecated
            @"Unicode 1.0" = 0,
            /// deprecated
            @"Unicode 1.1" = 1,
            /// deprecated
            @"ISO/IEC 10646" = 2,
            @"Unicode 2.0+, BMP only" = 3,
            @"Unicode 2.0+, full" = 4,
            @"Unicode variation" = 5,
            @"Unicode full" = 6,
            _,
        };

        pub const Windows = enum(u16) {
            symbol = 0,
            unicode_mbp = 1,
            shift_jis = 2,
            prc = 3,
            big5 = 4,
            wansung = 5,
            johab = 6,
            unicode_full = 10,
            _,

            pub fn isReserved(self: Windows) bool {
                const val: u16 = @intFromEnum(self);
                return val >= 7 and val < 10;
            }
        };
    };

    pub const PlatformId = enum(u16) {
        unicode = 0,
        /// discouraged
        macintosh = 1,
        /// deprecated
        iso = 2,
        windows = 3,
        /// discouraged
        custom = 4,
        _,
    };

    const SubtableFormat = enum(u16) {
        @"0" = 0,
        @"2" = 2,
        @"4" = 4,
        @"6" = 6,
        @"8" = 8,
        @"10" = 10,
        @"12" = 12,
        @"13" = 13,
        @"14" = 14,
    };

    pub const Subtable = union(SubtableFormat) {
        pub const Format = SubtableFormat;
        pub const Format0 = SubtableFormat0;
        pub const Format2 = SubtableFormat2;
        pub const Format4 = SubtableFormat4;
        pub const Format6 = SubtableFormat6;
        pub const Format8 = SubtableFormat8;
        pub const Format10 = SubtableFormat10;
        pub const Format12 = SubtableFormat12;
        pub const Format13 = SubtableFormat13;
        pub const Format14 = SubtableFormat14;

        @"0": Format0,
        @"2": Format2,
        @"4": Format4,
        @"6": Format6,
        @"8": Format8,
        @"10": Format10,
        @"12": Format12,
        @"13": Format13,
        @"14": Format14,
    };
};

/// Byte encoding table
const SubtableFormat0 = extern struct {};

const SubtableFormat2 = extern struct {};

const SubtableFormat4 = extern struct {};

const SubtableFormat6 = extern struct {};

const SubtableFormat8 = extern struct {};

const SubtableFormat10 = extern struct {};

const SubtableFormat12 = extern struct {};

const SubtableFormat13 = extern struct {};

const SubtableFormat14 = extern struct {};
