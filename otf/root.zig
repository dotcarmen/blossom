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

        pub const Composite = struct {
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
        };
    };

    pub const TtfInstructions = struct {
        ip: [*]const u8,
        instrs: []const u8,
        stack: []u32,
        max_stack: usize,
        storage_area: []u8,

        pub fn init(
            instrs: []const u8,
            stack: []u32,
            storage_area: []u8,
        ) TtfInstructions {
            return .{
                .instrs = instrs,
                .stack = .{ .ptr = stack.ptr, .len = 0 },
                .max_stack = stack.len,
                .storage_area = storage_area,
            };
        }

        fn readTape(self: *TtfInstructions, T: type) T {
            assert(std.mem.isAligned(@intFromPtr(self.ip), @alignOf(T)));
            const val: *const T = @alignCast(@ptrCast(self.ip));
            self.ip += @sizeOf(T);
            return val;
        }

        fn pushStack(self: *TtfInstructions, int: anytype) void {
            const Int = @typeInfo(@TypeOf(int)).int;
            assert(Int.bits <= 32);

            var Int_32 = Int;
            Int_32.bits = 32;

            const int32: @Type(.{ .int = Int_32 }) = @intCast(int);
            const uint32: u32 = @bitCast(int32);

            self.stack.ptr[self.stack.len] = uint32;
            self.stack.len += 1;
        }

        pub fn interp(self: *TtfInstructions) void {
            while (self.ip < self.instrs[self.instrs.len..]) {
                const instr = self.readTape(Instr);
                switch (instr) {
                    inline .pushb,
                    .pushb1,
                    .pushb2,
                    .pushb3,
                    .pushb4,
                    .pushb5,
                    .pushb6,
                    .pushb7,
                    .pushb8,
                    => |push| {
                        const len: u8 = switch (push) {
                            .pushb => self.readTape(u8),
                            .pushb1 => 1,
                            .pushb2 => 2,
                            .pushb3 => 3,
                            .pushb4 => 4,
                            .pushb5 => 5,
                            .pushb6 => 6,
                            .pushb7 => 7,
                            .pushb8 => 8,
                            else => unreachable,
                        };
                        for (0..len) |_| {
                            const byte = self.readTape(u8);
                            self.pushStack(byte);
                        }
                    },
                }
            }
        }

        pub const Instr = enum(u8) {
            /// PUSH n Bytes
            pushb = 0x40,
            /// PUSH n Words
            pushw = 0x41,

            /// PUSH 1 Byte
            pushb1 = 0xB0,
            /// PUSH 2 Bytes
            pushb2 = 0xB1,
            /// PUSH 3 Bytes
            pushb3 = 0xB2,
            /// PUSH 4 Bytes
            pushb4 = 0xB3,
            /// PUSH 5 Bytes
            pushb5 = 0xB4,
            /// PUSH 6 Bytes
            pushb6 = 0xB5,
            /// PUSH 7 Bytes
            pushb7 = 0xB6,
            /// PUSH 8 Bytes
            pushb8 = 0xB7,

            /// PUSH 1 Word
            pushw1 = 0xB8,
            /// PUSH 2 Words
            pushw2 = 0xB9,
            /// PUSH 3 Words
            pushw3 = 0xBA,
            /// PUSH 4 Words
            pushw4 = 0xBB,
            /// PUSH 5 Words
            pushw5 = 0xBC,
            /// PUSH 6 Words
            pushw6 = 0xBD,
            /// PUSH 7 Words
            pushw7 = 0xBE,
            /// PUSH 8 Words
            pushw8 = 0xBF,

            /// Read Store
            rs = 0x43,
            /// Write Store
            ws = 0x42,

            /// Write Control Value Table in Pixels
            wcvftp = 0x44,
            /// Write Control Value Table in Font design units
            wcvftf = 0x70,
            /// Read Control Value Table
            rcvt = 0x45,

            /// Set freedom and projection_Vectors To Coordinate Axis y
            svtca_y = 0x00,
            /// Set freedom and projection_Vectors To Coordinate Axis x
            svtca_x = 0x01,

            /// Set Projection_Vector To Coordinate Axis y
            spvtca_y = 0x02,
            /// Set Projection_Vector To Coordinate Axis x
            spvtca_x = 0x03,

            /// Set Freedom_Vector To Coordinate Axis y
            sfvtca_y = 0x04,
            /// Set Freedom_Vector To Coordinate Axis x
            sfvtca_x = 0x05,

            /// Set Projection_Vector To Line parallel
            spvtl_parallel = 0x06,
            /// Set Projection_Vector To Line perpendicular
            spvtl_perpendicular = 0x07,

            /// Set Freedom_Vector To Line parallel
            sfvtl_parallel = 0x08,
            /// Set Freedom_Vector To Line perpendicular
            sfvtl_perpendicular = 0x09,

            /// Set Freedom_Vector To Projection_Vector
            sfvtpv = 0x0E,

            /// Set Dual Projection_Vector To Line parallel
            sdpvtl_parallel = 0x86,
            /// Set Dual Projection_Vector To Line perpendicular
            sdpvtl_perpendicular = 0x87,

            /// Set Projection_Vector From Stack
            spvfs = 0x0A,
            /// Set Freedom_Vector From Stack
            sfvfs = 0x0B,
            /// Get Projection_Vector
            gpv = 0x0C,
            /// Get Freedom_Vector
            gfv = 0x0D,

            /// Set Reference_Point 0
            srp0 = 0x10,
            /// Set Reference_Point 1
            srp1 = 0x11,
            /// Set Reference_Point 2
            srp2 = 0x12,

            /// Set Zone_Pointer 0
            szp0 = 0x13,
            /// Set Zone_Pointer 1
            szp1 = 0x14,
            /// Set Zone_Pointer 2
            szp2 = 0x15,
            /// Set Zone_PointerS
            szps = 0x16,

            /// Round To Half Grid
            rthg = 0x19,
            /// Round To Grid
            rtg = 0x18,
            /// Round To Double Grid
            rtdg = 0x3D,
            /// Round Down To Grid
            rdtg = 0x7D,
            /// Round Up To Grid
            rutg = 0x7C,
            /// Round OFF
            roff = 0x7A,
            /// Super ROUND
            sround = 0x76,
            /// Super ROUND 45 degrees
            s45round = 0x77,

            /// Set LOOP variable
            sloop = 0x17,
            /// Set Minimum Distance
            smd = 0x1A,

            /// INSTruction execution ConTRoL
            instctrl = 0x8E,
            /// SCAN conversiont ConTRoL
            scanctrl = 0x85,
            /// SCAN TYPE
            scantype = 0x8D,

            /// Set Control_Value_Table Cut In
            scvtci = 0x1D,

            /// Set Single Width Cut In
            sswci = 0x1E,
            /// Set Single Width
            ssw = 0x1F,

            /// Set the auto FLIP boolean to ON
            sflipon = 0x4D,
            /// Set the auto FLIP boolean to OFF
            sflipoff = 0x4E,

            /// Set ANGle Weight
            sangw = 0x7E,

            /// Set Delta_Base in the graphics state
            sdb = 0x5E,
            /// Set Delta_Shift in the graphics state
            sds = 0x5F,

            /// Get Coordinate projected onto the projection_vector using
            /// current position of point p
            gc_current = 0x60,
            /// Get Coordinate projected onto the projection_vector using
            /// position of point p in original outline
            gc_original = 0x61,

            /// Sets Coordinate From the Stack using projection_vector and
            /// freedom_vector
            scfs = 0x48,

            /// Measure Distance in grid-fitted outline
            md_grid = 0x49,
            /// Measure Distance in original outline
            md_original = 0x4A,

            /// Measure Pixels Per EM
            mppem = 0x4B,
            /// Measure Point Size
            mps = 0x4C,

            /// FLIP PoinT
            flippt = 0x80,
            /// FLIP RanGe ON
            fliprgon = 0x81,
            /// FLIP RanGe OFF
            fliprgoff = 0x82,

            /// SHift Point by Reference_Pointer 2 by Zone_Pointer 1
            shp_rp2_zp1 = 0x32,
            /// SHift Point by Reference_Pointer 1 by Zone_Pointer 0
            shp_rp1_zp0 = 0x33,

            /// SHift Contour by Reference_Pointer 2 by Zone_Pointer 1
            shc_rp2_zp1 = 0x34,
            /// SHift Contour by Reference_Pointer 1 by Zone_Pointer 0
            shc_rp1_zp0 = 0x35,

            /// SHift Zone by Reference_Pointer 2 by Zone_Pointer 1
            shz_rp2_zp1 = 0x36,
            /// SHift Zone by Reference_Pointer 1 by Zone_Pointer 0
            shz_rp1_zp0 = 0x37,

            /// SHift point by PIXel amount
            shpix = 0x38,

            /// Move Stack Indirect Relative Point (dont't set rp0)
            msirp = 0x3A,
            /// Move Stack Indirect Relative Point and SET rp0 to p
            msirp_set = 0x3B,

            /// Move Direct Absolute Point (not rounding)
            msap = 0x2E,
            /// Move Direct Absolute Point ROUNDing
            msap_round = 0x2F,

            /// Move Indirect Absolute Point (don’t round the distance and don’t look at the control_value_cut_in)
            miap = 0x3E,
            /// Move Indirect Absolute Point (ROUND the distance and look at the control_value_cut_in)
            miap_round = 0x3F,

            /// Move Direct Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, don't round the distance,
            /// gray distance
            mdrp_unset_unbound_exact_gray = 0xC0,
            /// Move Direct Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, don't round the distance,
            /// black distance
            mdrp_unset_unbound_exact_black = 0xC1,
            /// Move Direct Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, don't round the distance,
            /// white distance
            mdrp_unset_unbound_exact_white = 0xC2,
            /// Move Direct Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, round the distance,
            /// gray distance
            mdrp_unset_unbound_round_gray = 0xC4,
            /// Move Direct Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, round the distance,
            /// black distance
            mdrp_unset_unbound_round_black = 0xC5,
            /// Move Direct Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, round the distance,
            /// white distance
            mdrp_unset_unbound_round_white = 0xC6,
            /// Move Direct Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, don't round the distance,
            /// gray distance
            mdrp_unset_bound_exact_gray = 0xC8,
            /// Move Direct Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, don't round the distance,
            /// black distance
            mdrp_unset_bound_exact_black = 0xC9,
            /// Move Direct Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, don't round the distance,
            /// white distance
            mdrp_unset_bound_exact_white = 0xCA,
            /// Move Direct Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, round the distance,
            /// gray distance
            mdrp_unset_bound_round_gray = 0xCC,
            /// Move Direct Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, round the distance,
            /// black distance
            mdrp_unset_bound_round_black = 0xCD,
            /// Move Direct Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, round the distance,
            /// white distance
            mdrp_unset_bound_round_white = 0xCE,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, don't round the
            /// distance, gray distance
            mdrp_set_unbound_exact_gray = 0xD0,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, don't round the
            /// distance, black distance
            mdrp_set_unbound_exact_black = 0xD1,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, don't round the
            /// distance, white distance
            mdrp_set_unbound_exact_white = 0xD2,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, round the
            /// distance, gray distance
            mdrp_set_unbound_round_gray = 0xD4,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, round the
            /// distance, black distance
            mdrp_set_unbound_round_black = 0xD5,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, round the
            /// distance, white distance
            mdrp_set_unbound_round_white = 0xD6,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, don't round the
            /// distance, gray distance
            mdrp_set_bound_exact_gray = 0xD8,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, don't round the
            /// distance, black distance
            mdrp_set_bound_exact_black = 0xD9,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, don't round the
            /// distance, white distance
            mdrp_set_bound_exact_white = 0xDA,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, round the
            /// distance, gray distance
            mdrp_set_bound_round_gray = 0xDC,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, round the
            /// distance, black distance
            mdrp_set_bound_round_black = 0xDD,
            /// Move Direct Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, round the
            /// distance, white distance
            mdrp_set_bound_round_white = 0xDE,

            /// Move Indirect Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, don't round the distance,
            /// gray distance
            mirp_unset_unbound_exact_gray = 0xC0,
            /// Move Indirect Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, don't round the distance,
            /// black distance
            mirp_unset_unbound_exact_black = 0xC1,
            /// Move Indirect Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, don't round the distance,
            /// white distance
            mirp_unset_unbound_exact_white = 0xC2,
            /// Move Indirect Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, round the distance,
            /// gray distance
            mirp_unset_unbound_round_gray = 0xC4,
            /// Move Indirect Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, round the distance,
            /// black distance
            mirp_unset_unbound_round_black = 0xC5,
            /// Move Indirect Relative Point - don't set rp0, distance not
            /// lower-bounded to minimum_distance, round the distance,
            /// white distance
            mirp_unset_unbound_round_white = 0xC6,
            /// Move Indirect Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, don't round the distance,
            /// gray distance
            mirp_unset_bound_exact_gray = 0xC8,
            /// Move Indirect Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, don't round the distance,
            /// black distance
            mirp_unset_bound_exact_black = 0xC9,
            /// Move Indirect Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, don't round the distance,
            /// white distance
            mirp_unset_bound_exact_white = 0xCA,
            /// Move Indirect Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, round the distance,
            /// gray distance
            mirp_unset_bound_round_gray = 0xCC,
            /// Move Indirect Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, round the distance,
            /// black distance
            mirp_unset_bound_round_black = 0xCD,
            /// Move Indirect Relative Point - don't set rp0, distance
            /// lower-bounded to minimum_distance, round the distance,
            /// white distance
            mirp_unset_bound_round_white = 0xCE,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, don't round the
            /// distance, gray distance
            mirp_set_unbound_exact_gray = 0xD0,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, don't round the
            /// distance, black distance
            mirp_set_unbound_exact_black = 0xD1,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, don't round the
            /// distance, white distance
            mirp_set_unbound_exact_white = 0xD2,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, round the
            /// distance, gray distance
            mirp_set_unbound_round_gray = 0xD4,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, round the
            /// distance, black distance
            mirp_set_unbound_round_black = 0xD5,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance not lower-bounded to minimum_distance, round the
            /// distance, white distance
            mirp_set_unbound_round_white = 0xD6,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, don't round the
            /// distance, gray distance
            mirp_set_bound_exact_gray = 0xD8,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, don't round the
            /// distance, black distance
            mirp_set_bound_exact_black = 0xD9,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, don't round the
            /// distance, white distance
            mirp_set_bound_exact_white = 0xDA,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, round the
            /// distance, gray distance
            mirp_set_bound_round_gray = 0xDC,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, round the
            /// distance, black distance
            mirp_set_bound_round_black = 0xDD,
            /// Move Indirect Relative Point - set rp0 to point p after move,
            /// distance lower-bounded to minimum_distance, round the
            /// distance, white distance
            mirp_set_bound_round_white = 0xDE,

            /// ALIGN Relative Point
            alignrp = 0x3C,

            /// move point p to the InterSECTion of two lines
            isect = 0x0F,

            /// ALIGN PoinTS
            alignpts = 0x27,

            /// Interpolate Point by the last relative stretch
            ip = 0x39,

            /// UnTouch Point
            utp = 0x29,

            /// Interpolate Untouched Points through the outline in the
            /// y-direction
            iup_y = 0x30,
            /// Interpolate Untouched Points through the outline in the
            /// x-direction
            iup_x = 0x31,

            /// DELTA exception P1
            delta_p1 = 0x5D,
            /// DELTA exception P2
            delta_p2 = 0x71,
            /// DELTA exception P3
            delta_p3 = 0x72,
            /// DELTA exception C1
            delta_c1 = 0x73,
            /// DELTA exception C2
            delta_c2 = 0x74,
            /// DELTA exception C3
            delta_c3 = 0x75,

            /// DUPlicate top stack element
            dup = 0x20,
            /// POP top stack element
            pop = 0x21,
            /// CLEAR the entire stack
            clear = 0x22,
            /// SWAP the top two elements on the stack
            swap = 0x23,
            /// Return the DEPTH of the stack
            depth = 0x24,

            /// Copy the INDEXed element to the top of the stack
            cindex = 0x25,
            /// Move the INDEXed element to the top of the stack
            mindex = 0x26,

            /// ROLL the top three stack elements
            roll = 0x8a,

            /// IF test
            @"if" = 0x58,
            /// ELSE
            @"else" = 0x1B,
            /// End IF
            eif = 0x59,

            /// Jump Relative On True
            jrot = 0x78,
            /// JuMP
            jmp = 0x1C,
            /// Jump Relative On False
            jrof = 0x79,

            /// Less Than
            lt = 0x50,
            /// Less Than or EQual
            lteq = 0x51,
            /// Greater Than
            gt = 0x52,
            /// Greater Than or Equal
            gteq = 0x53,
            /// EQual
            eq = 0x54,
            /// Not EQual
            neq = 0x55,

            /// ODD
            odd = 0x56,
            /// EVEN
            even = 0x57,

            /// logical AND
            @"and" = 0x5A,
            /// logical OR
            @"or" = 0x5B,
            /// logical NOT
            not = 0x5C,

            /// ADD
            add = 0x60,
            /// SUBtract
            sub = 0x61,
            /// DIVide
            div = 0x62,
            /// MULtiply
            mul = 0x63,
            /// ABSolute value
            abs = 0x64,
            /// NEGate
            neg = 0x65,

            /// FLOOR
            floor = 0x66,
            /// CEILING
            ceiling = 0x67,

            /// MAXimum of top two stack elements
            max = 0x8B,
            /// MINimum of top two stack elements
            min = 0x8C,

            /// ROUND value with gray distance
            round_gray = 0x68,
            /// ROUND value with black distance
            round_black = 0x69,
            /// ROUND value with white distance
            round_white = 0x6A,

            /// No ROUNDing of value with gray distance
            nround_gray = 0x6C,
            /// No ROUNDing of value with black distance
            nround_black = 0x6D,
            /// No ROUNDing of value with white distance
            nround_white = 0x6E,

            /// Function DEFinition
            fdef = 0x2C,
            /// END Function definition
            endf = 0x2D,
            /// CALL function
            call = 0x2B,
            /// LOOP and CALL function
            loopcall = 0x2A,

            /// Instruction DEFinition
            idef = 0x89,

            /// DEBUG call
            debug = 0x4F,

            /// GET INFOrmation
            getinfo = 0x88,

            /// GET VARIATION
            getvariation = 0x91,

            _,
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
