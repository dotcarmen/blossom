const TtfVm = @This();
const std = @import("std");

const assert = std.debug.assert;

ip: [*]const u8,
instrs: []const u8,
stack: []u32,
max_stack: usize,
storage_area: []u8,

pub fn init(
    instrs: []const u8,
    stack: []u32,
    storage_area: []u8,
) TtfVm {
    return .{
        .instrs = instrs,
        .stack = .{ .ptr = stack.ptr, .len = 0 },
        .max_stack = stack.len,
        .storage_area = storage_area,
    };
}

fn readTape(self: *TtfVm, T: type) T {
    assert(std.mem.isAligned(@intFromPtr(self.ip), @alignOf(T)));
    const val: *const T = @alignCast(@ptrCast(self.ip));
    self.ip += @sizeOf(T);
    return val;
}

fn pushStack(self: *TtfVm, int: anytype) void {
    const Int = @typeInfo(@TypeOf(int)).int;
    assert(Int.bits <= 32);

    var Int_32 = Int;
    Int_32.bits = 32;

    const int32: @Type(.{ .int = Int_32 }) = @intCast(int);
    const uint32: u32 = @bitCast(int32);

    self.stack.ptr[self.stack.len] = uint32;
    self.stack.len += 1;
}

pub fn interp(self: *TtfVm) void {
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
