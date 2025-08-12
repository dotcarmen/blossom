test {
    // recursively ref all declarations in this module
    std.testing.refAllDeclsRecursive(@import("root.zig"));
}

const std = @import("std");
const assert = std.debug.assert;

fn strToValue(T: type, str: []const u8) T {
    return std.mem.bytesAsValue(T, str.ptr).*;
}

const VersionBits = packed struct(u32) {
    minor: u16,
    major: u16,
};

pub const SfntVersion = enum(u32) {
    ttf = 0x00010000,
    cff_otto = strToValue(u32, "OTTO"),
    _,
};

pub const TableDirectory = extern struct {
    sfnt_version: SfntVersion,
    num_tables: u16,
    search_range: u16,
    entry_selector: u16,
    range_shift: u16,
    _tables: TableRecord,

    pub inline fn tables(self: *const TableDirectory) []const TableRecord {
        const t: [*]const TableRecord = @ptrCast(&self._tables);
        return t[0..self.num_tables];
    }

    pub fn readBytes(
        self: *const TableDirectory,
        byte_offset: usize,
        byte_length: usize,
    ) []const u8 {
        const bytes: [*]const u8 = std.mem.asBytes(self).ptr;
        const data: [*]const u8 = bytes + byte_offset;
        return data[0..byte_length];
    }

    pub fn readValue(
        self: *const TableDirectory,
        byte_offset: usize,
        T: type,
    ) *const T {
        const bytes = self.readBytes(byte_offset, @sizeOf(T));
        return std.mem.bytesAsValue(T, bytes.ptr);
    }
};

pub const TableRecord = extern struct {
    tag: Tag,
    checksum: u32,
    offset: u32,
    length: u32,

    pub fn readDataBytes(
        self: *const TableRecord,
        directory: *const TableDirectory,
    ) []const u8 {
        return directory.readBytes(self.offset, self.length);
    }

    pub const ReadDataError = error{DataTooShort};

    /// Returns error.DataTooShort if the data is too short to read the
    /// requested type.
    pub fn readData(
        self: *const TableRecord,
        directory: *const TableDirectory,
        T: type,
    ) ReadDataError!T {
        if (self.length < @sizeOf(T)) return error.DataTooShort;
        return directory.readValue(self.offset, T);
    }

    // pub fn calcChecksum(self: *const TableRecord) u32 {
    //     var sum: u32 = 0;
    //     var ptr: [*]const u32 = @ptrCast(self);
    //     const end_ptr: [*]const u32 = ptr + @divFloor(self.length, @sizeOf(u32));
    //     while (ptr != end_ptr) {
    //         sum += ptr[0];
    //         ptr += 1;
    //     }
    //     return sum;
    // }

    // pub fn isChecksumValid(self: *const TableRecord) bool {
    //     return self.checksum == self.calcChecksum();
    // }

    // pub const InvalidChecksum = error{InvalidChecksum};
    // pub fn validateChecksum(self: *const TableRecord) InvalidChecksum!void {
    //     if (!self.isChecksumValid())
    //         return error.InvalidChecksum;
    // }

    pub const Tag = enum(u32) {
        // required tables
        /// Character to glyph mapping
        cmap = strToValue(u32, "cmap"),
        /// Font header
        head = strToValue(u32, "head"),
        /// Horizontal header
        hhea = strToValue(u32, "hhea"),
        /// Horizontal metrics
        hmtx = strToValue(u32, "hmtx"),
        /// Maximum profile
        maxp = strToValue(u32, "maxp"),
        /// Naming table
        name = strToValue(u32, "name"),
        // TODO:
        // /// OS/2 and Windows specific metrics
        // os2 = strToValue(u32, "OS/2"), ??
        /// PostScript information
        post = strToValue(u32, "post"),

        // tables related to TrueType outlines
        /// Control Value Table (optional table)
        cvt = strToValue(u32, "cvt "),
        /// Font program (optional table)
        fpgm = strToValue(u32, "fpgm"),
        /// Glyph data
        glyf = strToValue(u32, "glyf"),
        /// Index to location
        loca = strToValue(u32, "loca"),
        /// Control Value Program (optional table)
        prep = strToValue(u32, "prep"),
        /// Grid-fitting/Scan-conversion (optional table)
        gasp = strToValue(u32, "gasp"),

        // tables related to CFF outlines
        /// Compact Font Format 1.0
        cff = strToValue(u32, "CFF "),
        /// Compact Font Format 2.0
        cff2 = strToValue(u32, "CFF2"),
        /// Vertical Origin (optional table)
        vorg = strToValue(u32, "VORG"),

        // tables related to SVG outlines
        /// The SVG (Scalable Vector Graphics) table
        svg = strToValue(u32, "SVG "),

        // tables related to bitmap glyphs
        /// Color bitmap data
        cbdt = strToValue(u32, "CBDT"),
        /// Color bitmap location
        cblc = strToValue(u32, "CBLC"),
        /// Embedded bitmap data
        ebdt = strToValue(u32, "EBDT"),
        /// Embedded bitmap location
        eblc = strToValue(u32, "EBLC"),
        /// Embedded bitmap scaling
        ebsc = strToValue(u32, "EBSC"),
        /// Standard bitmap graphics
        sbix = strToValue(u32, "sbix"),

        // advanced typographic tables
        /// Baseline data
        base = strToValue(u32, "BASE"),
        /// Glyph definition data
        gdef = strToValue(u32, "GDEF"),
        /// Glyph positioning data
        gpos = strToValue(u32, "GPOS"),
        /// Glyph substitution data
        gsub = strToValue(u32, "GSUB"),
        /// Justification data
        jstf = strToValue(u32, "JSTF"),
        /// Math layout data
        math = strToValue(u32, "MATH"),

        // fonts used for alternative OpenType font variations
        /// Axis variations
        avar = strToValue(u32, "avar"),
        /// CVT variations (TrueType outlines only)
        cvar = strToValue(u32, "cvar"),
        /// Font variations
        fvar = strToValue(u32, "fvar"),
        /// Glyph variations (TrueType outlines only)
        gvar = strToValue(u32, "gvar"),
        /// Horizontal metrics variations
        hvar = strToValue(u32, "HVAR"),
        /// Metrics variations
        mvar = strToValue(u32, "MVAR"),
        /// Style attributes (required for variable fonts, optional for non-variable fonts)
        stat = strToValue(u32, "STAT"),
        /// Vertical metrics variations
        vvar = strToValue(u32, "VVAR"),

        // tables related to color fonts
        /// Color table
        colr = strToValue(u32, "COLR"),
        /// Color palette table
        cpal = strToValue(u32, "CPAL"),
        // these are already defined above
        // cbdt = strToValue(u32, "CBDT"),
        // cblc = strToValue(u32, "CBLC"),
        // sbix = strToValue(u32, "sbix"),
        // svg = strToValue(u32, "SVG "),

        // other OpenType tables
        /// Digital signature
        dsig = strToValue(u32, "DSIG"),
        /// Horizontal device metrics
        hdmx = strToValue(u32, "hdmx"),
        /// Kerning
        kern = strToValue(u32, "kern"),
        /// Linear threshold data
        ltsh = strToValue(u32, "LTSH"),
        /// Merge
        merg = strToValue(u32, "MERG"),
        /// Metadata
        meta = strToValue(u32, "meta"),
        // already defined above
        // stat = strToValue(u32, "STAT"),
        /// PCL 5 data
        pclt = strToValue(u32, "PCLT"),
        /// Vertical device metrics
        vdmx = strToValue(u32, "VDMX"),
        /// Vertical metrics header
        vhea = strToValue(u32, "vhea"),
        /// Vertical metrics
        vmtx = strToValue(u32, "vmtx"),

        _,

        pub fn streql(self: Tag, tag: [4]u8) bool {
            return @intFromEnum(self) == strToValue(u32, &tag);
        }
    };
};

// cmap
pub const Cmap = extern struct {
    const cmap = @import("cmap.zig");
    pub const EncodingRecord = cmap.EncodingRecord;

    pub const Version = enum(u16) {
        @"0" = 0,
        _,
    };

    version: Version,
    num_tables: u16,
    _first_encoding_record: EncodingRecord,

    pub inline fn encoding_records(self: *const Cmap) []const EncodingRecord {
        const records: [*]const EncodingRecord = @ptrCast(&self._first_encoding_record);
        return records[0..self.num_tables];
    }
};

// head
pub const Head = extern struct {
    pub const Version = enum(u32) {
        pub const Bits = VersionBits;
        @"1.0" = @bitCast(Bits{ .major = 1, .minor = 0 }),
        _,
    };

    version: Version,
    data: extern union {
        @"1.0": Version1_0,
    },

    pub const IndexToLocFormat = enum(i16) {
        /// offset16
        short = 0,
        /// offset32
        long = 1,
        _,
    };

    pub const Version1_0 = extern struct {
        pub const CHECKSUM_ADJUSTMENT: u32 = 0xB1B0AFBA;
        pub const MAGIC: u32 = 0x5F0F3CF5;

        font_revision: i16,
        chucksum_adjustment: u32,
        magic_number: u32 = MAGIC,
        flags: Flags,
        units_per_em: u16,
        created: i64,
        modified: i64,
        x_min: i16,
        y_min: i16,
        x_max: i16,
        y_max: i16,
        mac_style: MacStyle,
        lowest_rec_ppem: u16,
        font_direction_hint: FontDirectionHint,
        index_to_loc_format: IndexToLocFormat,
        glyph_data_format: GlyphDataFormat,

        pub const Flags = packed struct(u16) {
            baseline_y_0: bool,
            left_side_bearing_x_0: bool,
            instructions_depend_on_point_size: bool,
            ppem_integer_values: bool,
            instructions_may_alter_advance_width: bool,
            _reserved0: u1 = 0,
            _reserved1: u5 = 0,
            font_data_lossless: bool = false,
            font_converted: bool,
            cleartype: bool,
            last_resort: bool,
            _reserved2: u1 = 0,
        };

        pub const MacStyle = packed struct(u16) {
            bold: bool,
            italic: bool,
            underline: bool,
            outline: bool,
            shadow: bool,
            condensed: bool,
            extended: bool,
            reserved: u9 = 0,
        };

        pub const FontDirectionHint = enum(i16) {
            full_mixed = 0,
            strictly_left_to_right = 1,
            left_to_right_and_neutral = 2,
            strictly_right_to_left = -1,
            right_to_left_and_neutral = -2,
            _,

            /// FontDirectionHint is deprecated, this should be the value used.
            pub const default: FontDirectionHint = .left_to_right_and_neutral;
        };

        pub const GlyphDataFormat = enum(i16) {
            current = 0,
            _,
        };
    };
};

// hhea
pub const Hhea = extern struct {
    pub const Version = enum(u32) {
        pub const Bits = VersionBits;
        @"1.0" = @bitCast(Bits{ .major = 1, .minor = 0 }),
        _,
    };

    version: Version,
    data: extern union {
        @"1.0": Version1_0,
    },

    pub const NumberOfHMetrics = enum(u16) { _ };

    pub const Version1_0 = extern struct {
        ascender: i16,
        descender: i16,
        line_gap: i16,
        advance_width_max: u16,
        min_left_side_bearing: i16,
        min_right_side_bearing: i16,
        x_max_extent: i16,
        caret_slope_rise: i16,
        caret_slope_run: i16,
        caret_offset: i16,
        _reserved0: u32 = 0,
        metric_data_format: i16,
        number_of_hmetrics: NumberOfHMetrics,
    };
};

// hmtx
pub const Hmtx = extern struct {
    _first_h_metric: LongHorMetric,

    pub fn read(
        self: *const Hmtx,
        number_of_h_metrics: Hhea.NumberOfHMetrics,
        num_glyphs: Maxp.NumGlyphs,
    ) struct {
        h_metrics: []const LongHorMetric,
        left_side_bearings: []const i16,
    } {
        const h_metrics: [*]const LongHorMetric = @ptrCast(self);
        const h_metrics_len: usize = @intFromEnum(number_of_h_metrics);
        const left_side_bearings: [*]const i16 = @ptrCast(h_metrics[h_metrics_len..]);
        const num_lsb = @intFromEnum(num_glyphs) - h_metrics_len;
        return .{
            .h_metrics = h_metrics[0..h_metrics_len],
            .left_side_bearings = left_side_bearings[0..num_lsb],
        };
    }

    pub const LongHorMetric = extern struct {
        /// Advance width, in font design units.
        advance_width: u16,
        /// Glyph left side bearing, in font design units.
        left_side_bearing: i16,
    };
};

// maxp
pub const Maxp = extern struct {
    pub const Version = enum(u32) {
        pub const Bits = VersionBits;
        @"0.5" = @bitCast(Bits{ .major = 0, .minor = 5 }),
        @"1.0" = @bitCast(Bits{ .major = 1, .minor = 0 }),
        _,
    };

    version: Version,
    data: extern union {
        @"0.5": Version0_5,
        @"1.0": Version1_0,
    },

    pub const NumGlyphs = enum(u16) { _ };

    pub const Version0_5 = extern struct {
        num_glyphs: NumGlyphs,
    };

    pub const Version1_0 = extern struct {
        /// The number of glyphs in the font.
        num_glyphs: NumGlyphs,
        /// Maximum points in a non-composite glyph.
        max_points: u16,
        /// Maximum contours in a non-composite glyph.
        max_contours: u16,
        /// Maximum points in a composite glyph.
        max_composite_points: u16,
        /// Maximum contours in a composite glyph.
        max_composite_contours: u16,
        /// 1 if instructions do not use the twilight zone (Z0), or 2 if
        /// instructions do use Z0; should be set to 2 in most cases.
        max_zones: u16,
        /// Maximum points used in Z0.
        max_twilight_points: u16,
        /// Number of Storage Area locations.
        max_storage: u16,
        /// Number of FDEFs, equal to the highest function number + 1.
        max_function_defs: u16,
        /// Number of IDEFs.
        max_instruction_defs: u16,
        /// Maximum stack depth across Font Program ('fpgm' table), CVT Program
        /// ('prep' table) and all glyph instructions (in the 'glyf' table).
        max_stack_elements: u16,
        /// Maximum byte count for glyph instructions.
        max_size_of_instructions: u16,
        /// Maximum number of components referenced at “top level” for any
        /// composite glyph.
        max_component_elements: u16,
        /// Maximum levels of recursion; 1 for simple components.
        max_component_depth: u16,
    };
};

// glyf
pub const Glyf = extern struct {
    pub const TtfVm = @import("glyf/TtfVm.zig");

    number_of_contours: i16,
    x_min: i16,
    y_min: i16,
    x_max: i16,
    y_max: i16,
    _description_start_byte: u8,

    pub fn description(self: *const Glyf) Description {
        const description_start: [*]const u8 = @ptrCast(&self._description_start_byte);

        if (self.number_of_contours < 0) {
            return .{ .composite = .read(description_start) };
        } else {
            const contours_len: usize = @intCast(self.number_of_contours);

            const end_points_of_contours = description_start[0..contours_len];

            const instructions_len_ptr: [*]const u8 = description_start[contours_len..];
            const instructions_len = std.mem.bytesToValue(u16, instructions_len_ptr[0..2]);
            const instructions = instructions_len_ptr[2 .. instructions_len + 2];

            const flags_ptr: [*]const u8 = instructions_len_ptr[instructions_len + 2 ..];
            const flags = flags_ptr[0..contours_len];

            const coordinates_ptr: [*]const u8 = flags_ptr[contours_len..];

            return .{ .simple = .{
                .end_points_of_contours = end_points_of_contours,
                .instructions = instructions,
                .flags = flags,
                ._coordinates = coordinates_ptr,
            } };
        }
    }

    pub const Description = union(enum) {
        pub const Composite = @import("glyf/CompositeDescription.zig");

        simple: Simple,
        composite: Composite,

        pub const Simple = struct {
            end_points_of_contours: []const u8,
            instructions: []const u8,
            flags: []const u8,
            /// Coordinates of the points in the glyph.
            ///
            /// These are dynamically encoded x-coordinates followed by y-coordinates.
            /// Use the `flags` array to determine the encoding of each coordinate.
            _coordinates: [*]const u8,

            pub const Flag = packed struct(u8) {
                on_curve: bool,
                x_short_vector: bool,
                y_short_vector: bool,
                repeat: bool,
                x_is_same: bool,
                y_is_same: bool,
                overlap_simple: bool,
                _reserved0: u1 = 0,
            };
        };
    };
};

// loca
pub const Loca = extern struct {
    pub const Offset = extern union { short: u16, long: u32 };

    _first_offset: Offset,

    pub inline fn shortOffsetsPtr(self: *const Loca) [*]const u16 {
        return @ptrCast(&self._first_offset.short);
    }

    pub inline fn shortOffsets(
        self: *const Loca,
        num_glyphs: Maxp.NumGlyphs,
    ) []const u16 {
        return self.shortOffsetsPtr()[0 .. @intFromEnum(num_glyphs) + 1];
    }

    pub inline fn longOffsetsPtr(self: *const Loca) [*]const u32 {
        return @ptrCast(&self._first_offset.long);
    }

    pub inline fn longOffsets(
        self: *const Loca,
        num_glyphs: Maxp.NumGlyphs,
    ) []const u32 {
        return self.longOffsetsPtr()[0 .. @intFromEnum(num_glyphs) + 1];
    }

    pub const OffsetsPtr = union(enum) { short: [*]const u16, long: [*]const u32 };
    pub inline fn offsetsPtr(
        self: *const Loca,
        format: Head.IndexToLocFormat,
    ) OffsetsPtr {
        return switch (format) {
            .short => .{ .short = self.shortOffsetsPtr() },
            .long => .{ .long = self.longOffsetsPtr() },
            else => unreachable,
        };
    }

    pub const Offsets = union(enum) { short: []const u16, long: []const u32 };
    pub inline fn offsets(
        self: *const Loca,
        format: Head.IndexToLocFormat,
        num_glyphs: Maxp.NumGlyphs,
    ) Offsets {
        return switch (format) {
            .short => .{ .short = self.shortOffsets(num_glyphs) },
            .long => .{ .long = self.longOffsets(num_glyphs) },
            else => unreachable,
        };
    }
};
