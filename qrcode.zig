const std = @import("std");
const extras = @import("extras");

/// GF(256)[0...255]
const GF = blk: {
    var gf: [256]u8 = @splat(2);
    for (0..256) |n| {
        if (n == 0) {
            gf[n] = 1;
            continue;
        }
        if (n < 8) {
            gf[n] <<= @intCast(n - 1);
            continue;
        }
        gf[n] = gf[n - 1] *% 2;
        if (gf[n - 1] > 127) gf[n] ^= 0b00011101;
    }
    const out = gf;
    break :blk out;
};

pub fn encode(comptime mode: Mode, comptime level: Level, comptime version: u16, input: []const u8) BitGrid(4 * version + 17) {
    std.log.warn("mode: {s}", .{@tagName(mode)});
    std.log.warn("level: {s}", .{@tagName(level)});

    if (mode == .numeric) std.debug.assert(extras.matchesAll(u8, input, isNumeric));
    if (mode == .alphanumeric) std.debug.assert(extras.matchesAll(u8, input, isAlphanumeric));
    // latin1 is a full 1-byte format, some readers can detect utf-8
    // shift jis is a full 2-byte format

    const max_lengths = comptime maxLenPerModeLevelVersion(mode, level);
    const max_length = max_lengths[version];
    std.log.warn("actual version: {d},{d},{d}", .{ version, max_length, input.len });
    std.debug.assert(input.len <= max_length);
    for (max_lengths, 0..) |l, i| if (l > input.len) break std.log.warn("reccom version: {d},{d}", .{ i, l });

    const mode_indicator: u4 = switch (mode) {
        .numeric => 0b0001,
        .alphanumeric => 0b0010,
        .latin1 => 0b0100,
        .shiftjis => 0b1000,
    };
    std.log.warn("mode_indicator: {d}", .{mode_indicator});

    const LenIndicator = switch (mode) {
        .numeric => switch (version) {
            1...9 => u10,
            10...26 => u12,
            27...40 => u14,
            else => unreachable,
        },
        .alphanumeric => switch (version) {
            1...9 => u9,
            10...26 => u11,
            27...40 => u13,
            else => unreachable,
        },
        .latin1 => switch (version) {
            1...9 => u8,
            10...26 => u16,
            27...40 => u16,
            else => unreachable,
        },
        .shiftjis => switch (version) {
            1...9 => u8,
            10...26 => u10,
            27...40 => u12,
            else => unreachable,
        },
    };
    const len_indicator: LenIndicator = @intCast(input.len);
    std.log.warn("len_indicator: {d}", .{len_indicator});

    const total_bits = (max_length + 2) * 8;
    std.log.warn("total_bits: {d}", .{total_bits});

    var scratch: std.bit_set.ArrayBitSet(u8, total_bits) = .initEmpty();
    var scratchw: BitsetWriter(u8, total_bits) = .{ .set = &scratch };

    scratchw.writeInt(mode_indicator);
    scratchw.writeInt(len_indicator);
    for (input) |x| scratchw.writeInt(x);

    const data_bits = input.len * 8 + @bitSizeOf(@TypeOf(mode_indicator)) + @bitSizeOf(@TypeOf(len_indicator));
    std.log.warn("data_bits: {d}", .{data_bits});
    std.debug.assert(scratchw.idx == data_bits);

    // write @max(4, padding_bits) 0s
    for (0..@min(4, total_bits - scratchw.idx)) |_| scratchw.writeInt(@as(u1, 0));

    // add zero bits to make data_bits%8 == 0
    for (0..-%scratchw.idx & 7) |_| scratchw.writeInt(@as(u1, 0));

    // add 236(11101100) 17(00010001) until we reach total_bits
    while (scratchw.idx < total_bits) {
        scratchw.writeInt(@as(u8, 0xec));
        scratchw.writeInt(@as(u8, 0x11));
    }

    // std.log.warn("{b:0>8}", .{&bitReverse(scratch.masks)});
    // std.log.warn("{d}", .{&bitReverse(scratch.masks)});
    // std.log.warn("{x}", .{&bitReverse(scratch.masks)});

    const groups = 1; // ?
    _ = &groups;
    const blocks = 1; // ?
    _ = &blocks;
    const dc_per_block = 19; //?
    _ = &dc_per_block;
    const ecc_per_block = 7; //?
    _ = &ecc_per_block;

    var message_polynomial = scratch.masks;
    std.log.warn("message_polynomial: {d}", .{&bitReverse(message_polynomial)});

    const generator_polynomial = reverseArray(generatorPolynomial(ecc_per_block));
    std.log.warn("generator_polynomial: {d}", .{generator_polynomial});

    const generator_polynomial_alpha = to_alpha(generator_polynomial);
    std.log.warn("generator_polynomial_alpha: {d}", .{generator_polynomial_alpha});

    // Now that the message and generator polynomials have been created, divide them to get the error codewords.
    {
        // 1. Multiply the message polynomial by x^n where n is the number of error correction codewords to be generated
        //    and multiply the generator polynomial by x^m where m is the leading exponent of the message polynomial.
        // 2. Multiply the generator polynomial by the lead term of the message polynomial.
        // 3. XOR the result of Step 2 with the message polynomial and discard the lead 0 term.
        // 4. Repeat Steps 2-3 n-1 more times where n is the number of data codewords.
    }
    var mp: [scratch.masks.len + ecc_per_block]?u8 = @splat(null);
    for (&message_polynomial, 0..) |x, i| mp[i] = to_alpha(.{@bitReverse(x)})[0];

    for (0..scratch.masks.len) |i| {
        const lead = mp[i].?;
        for (&generator_polynomial_alpha, 0..) |x, j| {
            var y = GF[(@as(usize, x) + lead) % 255];
            if (mp[i + j]) |z| y ^= GF[z];
            mp[i + j] = if (y == 0) null else to_alpha(.{y})[0];
        }
    }

    var error_codewords: [ecc_per_block]u8 = @splat(0);
    for (0..ecc_per_block) |i| error_codewords[i] = if (mp[message_polynomial.len..][i]) |x| GF[x] else 0;
    std.log.warn("error_codewords: {d}", .{error_codewords});

    const interleaved_message = scratch.masks ++ bitReverse(error_codewords);
    std.log.warn("interleaved_message: {b:0>8}", .{&bitReverse(interleaved_message)});

    // remainder bits

    //

    const size = 4 * version + 17;
    var grid: BitGrid(size) = .initEmpty();

    // top left finder pattern
    for (0..7) |i| for (0..7) |j| grid.setT(0 + i, 0 + j);
    for (0..5) |i| for (0..5) |j| grid.setF(1 + i, 1 + j);
    for (0..3) |i| for (0..3) |j| grid.setT(2 + i, 2 + j);

    // top right finder pattern
    for (0..7) |i| for (0..7) |j| grid.setT(size - 7 + 0 + i, 0 + j);
    for (0..5) |i| for (0..5) |j| grid.setF(size - 7 + 1 + i, 1 + j);
    for (0..3) |i| for (0..3) |j| grid.setT(size - 7 + 2 + i, 2 + j);

    // bottom left finder pattern
    for (0..7) |i| for (0..7) |j| grid.setT(0 + i, size - 7 + 0 + j);
    for (0..5) |i| for (0..5) |j| grid.setF(1 + i, size - 7 + 1 + j);
    for (0..3) |i| for (0..3) |j| grid.setT(2 + i, size - 7 + 2 + j);

    // timing pattern
    for (8..size) |i| if (i % 2 == 0) grid.set(i, 6);
    for (8..size) |i| if (i % 2 == 0) grid.set(6, i);

    // alignment patterns

    // dark module
    grid.set(8, 4 * (version - 1) + 13);

    // version block

    // data mask (data cannot be placed where this is set)
    var data_mask: BitGrid(size) = .initEmpty();
    for (0..9) |y| for (0..9) |x| data_mask.set(x, y);
    for (0..9) |y| for (0..8) |x| data_mask.set(size - 8 + x, y);
    for (0..8) |y| for (0..9) |x| data_mask.set(x, size - 8 + y);
    for (0..size) |i| data_mask.set(i, 6);
    for (0..size) |i| data_mask.set(6, i);

    // write data
    var data_iter: BufBiterator = .init(&bitReverse(interleaved_message));

    var griditer: GridZigZag = .init(size, 6);
    while (griditer.next()) |idx| {
        const x = idx % size;
        const y = (idx - x) / size;
        if (data_mask.isSet(x, y)) continue;
        grid.debug.set((y * size) + x);
        if (@bitCast(data_iter.next() orelse break)) grid.set(x, y);
    }

    for (0..8) |y| for (0..8) |x| grid.debug.set((y * size) + x);
    for (0..8) |y| for (0..8) |x| grid.debug.set((y * size) + size - 8 + x);
    for (0..8) |y| for (0..8) |x| grid.debug.set(((size - 8 + y) * size) + x);
    for (0..size) |i| grid.debug.set((6 * size) + i);
    for (0..size) |i| grid.debug.set((i * size) + 6);

    // format info
    var masks = [_]std.bit_set.IntegerBitSet(15){
        .{ .mask = @bitReverse(formatPattern(level, 0)) },
        .{ .mask = @bitReverse(formatPattern(level, 1)) },
        .{ .mask = @bitReverse(formatPattern(level, 2)) },
        .{ .mask = @bitReverse(formatPattern(level, 3)) },
        .{ .mask = @bitReverse(formatPattern(level, 4)) },
        .{ .mask = @bitReverse(formatPattern(level, 5)) },
        .{ .mask = @bitReverse(formatPattern(level, 6)) },
        .{ .mask = @bitReverse(formatPattern(level, 7)) },
    };
    var grids = [_]BitGrid(size){
        grid,
        grid,
        grid,
        grid,
        grid,
        grid,
        grid,
        grid,
    };
    for (&grids, &masks) |*g, m| {
        g.setV(0, 8, m.isSet(0));
        g.setV(1, 8, m.isSet(1));
        g.setV(2, 8, m.isSet(2));
        g.setV(3, 8, m.isSet(3));
        g.setV(4, 8, m.isSet(4));
        g.setV(5, 8, m.isSet(5));
        g.setV(7, 8, m.isSet(6));
        g.setV(8, 8, m.isSet(7));
        g.setV(8, 7, m.isSet(8));
        g.setV(8, 5, m.isSet(9));
        g.setV(8, 4, m.isSet(10));
        g.setV(8, 3, m.isSet(11));
        g.setV(8, 2, m.isSet(12));
        g.setV(8, 1, m.isSet(13));
        g.setV(8, 0, m.isSet(14));

        g.setV(8, size - 1 - 0, m.isSet(0));
        g.setV(8, size - 1 - 1, m.isSet(1));
        g.setV(8, size - 1 - 2, m.isSet(2));
        g.setV(8, size - 1 - 3, m.isSet(3));
        g.setV(8, size - 1 - 4, m.isSet(4));
        g.setV(8, size - 1 - 5, m.isSet(5));
        g.setV(8, size - 1 - 6, m.isSet(6));
        g.setV(size - 8 + 0, 8, m.isSet(7));
        g.setV(size - 8 + 1, 8, m.isSet(8));
        g.setV(size - 8 + 2, 8, m.isSet(9));
        g.setV(size - 8 + 3, 8, m.isSet(10));
        g.setV(size - 8 + 4, 8, m.isSet(11));
        g.setV(size - 8 + 5, 8, m.isSet(12));
        g.setV(size - 8 + 6, 8, m.isSet(13));
        g.setV(size - 8 + 7, 8, m.isSet(14));
    }

    // masking patterns
    // Pattern 0: (row + column) mod 2 == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and (row + col) % 2 == 0) grids[0].flip(col, row);
    // Pattern 1: row mod 2 == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and row % 2 == 0) grids[1].flip(col, row);
    // Pattern 2: column mod 3 == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and col % 3 == 0) grids[2].flip(col, row);
    // Pattern 3: (row + column) mod 3 == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and (row + col) % 3 == 0) grids[3].flip(col, row);
    // Pattern 4: (floor(row/2) + floor(column / 3)) mod 2 == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and (row / 2 + col / 3) % 2 == 0) grids[4].flip(col, row);
    // Pattern 5: ((row * column) mod 2) + ((row * column) mod 3) == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and (((row * col) % 2) + ((row * col) % 3)) == 0) grids[5].flip(col, row);
    // Pattern 6: ( ((row * column) mod 2) + ((row * column) mod 3) ) mod 2 == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and (((row * col) % 2) + ((row * col) % 3)) % 2 == 0) grids[6].flip(col, row);
    // Pattern 7: ( ((row + column) mod 2) + ((row * column) mod 3) ) mod 2 == 0
    for (0..size) |row| for (0..size) |col| if (!data_mask.isSet(col, row) and (((row + col) % 2) + ((row * col) % 3)) % 2 == 0) grids[7].flip(col, row);

    // penalty
    var penaltys: [8][4]u32 = @splat(@splat(0));
    for (&grids, 0..) |*g, i| {
        var prev = false;
        var run: u16 = 0;
        for (0..size) |y| {
            for (0..size) |x| {
                if (x == 0) {
                    run = 0;
                    prev = g.isSet(0, y);
                }
                const this = g.isSet(x, y);
                if (this == prev) {
                    run += 1;
                    penaltys[i][0] += if (run == 5) 3 else if (run > 5) 1 else 0;
                } else {
                    run = 1;
                }
                prev = this;
            }
        }
        for (0..size) |x| {
            for (0..size) |y| {
                if (y == 0) {
                    run = 0;
                    prev = g.isSet(x, 0);
                }
                const this = g.isSet(x, y);
                if (this == prev) {
                    run += 1;
                    penaltys[i][0] += if (run == 5) 3 else if (run > 5) 1 else 0;
                } else {
                    run = 1;
                }
                prev = this;
            }
        }
    }
    for (&grids, 0..) |*g, i| {
        for (0..size - 1) |y| {
            for (0..size - 1) |x| {
                const p0 = g.isSet(x, y);
                const p1 = g.isSet(x + 1, y);
                const p2 = g.isSet(x, y + 1);
                const p3 = g.isSet(x + 1, y + 1);
                penaltys[i][1] += if (p0 == p1 and p1 == p2 and p2 == p3) 3 else 0;
            }
        }
    }
    for (&grids, 0..) |*g, i| {
        for (0..size) |y| {
            for (0..size - 10) |x| {
                const sel = g.sliceX(y, x, 11);
                penaltys[i][2] += if (sel.mask == 0b00001011101) 40 else 0;
                penaltys[i][2] += if (sel.mask == 0b10111010000) 40 else 0;
            }
        }
        for (0..size) |x| {
            for (0..size - 10) |y| {
                const sel = g.sliceY(x, y, 11);
                penaltys[i][2] += if (sel.mask == 0b00001011101) 40 else 0;
                penaltys[i][2] += if (sel.mask == 0b10111010000) 40 else 0;
            }
        }
    }
    for (&grids, 0..) |*g, i| {
        const total_modules: comptime_float = size * size;
        var dark_modules: f32 = 0;
        for (0..size) |y| {
            for (0..size) |x| {
                if (g.isSet(x, y)) {
                    dark_modules += 1;
                }
            }
        }
        const percent: u32 = @intFromFloat(@ceil(dark_modules / total_modules * 100));
        const round1 = percent + (-%percent & 4);
        const round2 = round1 -| 5;
        const sub = [_]u32{ @abs(@as(i32, @intCast(round1)) - 50), @abs(@as(i32, @intCast(round2)) - 50) };
        const div = [_]u32{ @divFloor(sub[0], 5), @divFloor(sub[1], 5) };
        penaltys[i][3] += std.mem.min(u32, &div) * 10;
    }
    for (&penaltys) |x| std.log.warn("penaltys: {d}", .{&x});

    var penalty: [8]u32 = @splat(0);
    for (0..8) |i| penalty[i] = extras.sum(u32, &penaltys[i]);

    const min_penalty = std.mem.min(u32, &penalty);
    std.log.warn("min_penalty: {d}", .{min_penalty});
    const min_mask = std.mem.indexOfScalar(u32, &penalty, min_penalty).?;
    std.log.warn("min_mask: {d}", .{min_mask});

    std.log.warn("", .{});
    return grids[min_mask];
}

fn BitGrid(comptime size: usize) type {
    return struct {
        bset: std.bit_set.ArrayBitSet(usize, size * size),
        debug: std.bit_set.ArrayBitSet(usize, size * size),
        comptime size: usize = size,

        pub fn initEmpty() @This() {
            return .{
                .bset = .initEmpty(),
                .debug = .initEmpty(),
            };
        }

        pub fn isSet(self: *const @This(), x: usize, y: usize) bool {
            return self.bset.isSet((y * size) + x);
        }

        pub fn set(self: *@This(), x: usize, y: usize) void {
            self.bset.set((y * size) + x);
            self.debug.set((y * size) + x);
        }

        pub fn setF(self: *@This(), x: usize, y: usize) void {
            self.bset.setValue((y * size) + x, false);
            self.debug.setValue((y * size) + x, true);
        }

        pub fn setT(self: *@This(), x: usize, y: usize) void {
            self.bset.setValue((y * size) + x, true);
            self.debug.setValue((y * size) + x, true);
        }

        pub fn setV(self: *@This(), x: usize, y: usize, value: bool) void {
            self.bset.setValue((y * size) + x, value);
            self.debug.setValue((y * size) + x, true);
        }

        pub fn hasSet(self: *const @This(), x: usize, y: usize) bool {
            return self.debug.isSet((y * size) + x);
        }

        pub fn flip(self: *@This(), x: usize, y: usize) void {
            std.debug.assert(self.debug.isSet((y * size) + x));
            self.bset.toggle((y * size) + x);
        }

        pub fn sliceX(self: *@This(), y: usize, sx: usize, comptime len: usize) std.bit_set.IntegerBitSet(len) {
            var result: std.bit_set.IntegerBitSet(len) = .initEmpty();
            for (0..len) |i| result.setValue(i, self.isSet(sx + i, y));
            return result;
        }

        pub fn sliceY(self: *@This(), x: usize, sy: usize, comptime len: usize) std.bit_set.IntegerBitSet(len) {
            var result: std.bit_set.IntegerBitSet(len) = .initEmpty();
            for (0..len) |i| result.setValue(i, self.isSet(x, sy + i));
            return result;
        }
    };
}

fn BitsetWriter(MaskIntType: type, size: usize) type {
    return struct {
        set: *std.bit_set.ArrayBitSet(MaskIntType, size),
        idx: usize = 0,

        pub fn writeInt(self: *@This(), int: anytype) void {
            return writeInt2(self, @bitReverse(int));
        }
        fn writeInt2(self: *@This(), int: anytype) void {
            const T = @TypeOf(int);
            const info = @typeInfo(T).int;
            comptime std.debug.assert(info.signedness == .unsigned);
            if (self.idx == size) {
                return;
            }
            if (T == u1) {
                self.set.setValue(self.idx, @bitCast(int));
                self.idx += 1;
                return;
            }
            self.set.setValue(self.idx, (int & 1) == 1);
            self.idx += 1;
            return writeInt2(self, @as(extras.OneSmallerInt(T), @intCast(int >> 1)));
        }
    };
}

fn bitReverse(array: anytype) [array.len]std.meta.Child(@TypeOf(array)) {
    var result: [array.len]std.meta.Child(@TypeOf(array)) = @splat(0);
    for (&array, &result) |x, *y| y.* = @bitReverse(x);
    return result;
}

fn reverseArray(array: anytype) @TypeOf(array) {
    var result: @TypeOf(array) = array;
    for (0..result.len / 2) |i| {
        std.mem.swap(std.meta.Child(@TypeOf(result)), &result[i], &result[result.len - 1 - i]);
    }
    return result;
}

//

pub const Mode = enum {
    numeric,
    alphanumeric,
    latin1,
    shiftjis,
};

pub const Level = enum {
    L,
    M,
    Q,
    H,
};

// Sourced from https://gist.github.com/ZavierHenry/a4b3761212109d5598bb2db79c334782
pub fn maxLenPerModeLevelVersion(mode: Mode, level: Level) *const [41]u16 {
    return switch (mode) {
        .numeric => switch (level) {
            .L => &.{ 0, 41, 77, 127, 187, 255, 322, 370, 461, 552, 652, 772, 883, 1022, 1101, 1250, 1408, 1548, 1725, 1903, 2061, 2232, 2409, 2620, 2812, 3057, 2383, 3517, 3669, 3909, 4158, 4417, 4686, 4965, 5253, 5529, 5836, 6153, 6479, 6743, 7089 },
            .M => &.{ 0, 34, 63, 101, 149, 202, 255, 293, 365, 432, 513, 694, 691, 796, 871, 991, 1082, 1212, 1346, 1500, 1600, 1708, 1872, 2059, 2188, 2395, 2544, 2701, 2857, 3035, 3289, 3486, 3693, 3909, 4134, 4343, 4588, 4775, 5039, 5313, 5596 },
            .Q => &.{ 0, 27, 48, 77, 111, 144, 178, 207, 259, 312, 364, 427, 489, 580, 621, 703, 775, 876, 948, 1063, 1159, 1224, 1358, 1468, 1588, 1718, 1804, 1933, 2085, 2181, 2358, 2473, 2670, 2805, 2949, 3081, 3244, 3417, 3599, 3791, 3993 },
            .H => &.{ 0, 17, 34, 58, 82, 106, 139, 154, 202, 235, 288, 331, 374, 427, 468, 530, 602, 674, 746, 813, 919, 969, 1056, 1108, 1228, 1286, 1425, 1501, 1581, 1677, 1782, 1897, 2022, 2157, 2301, 2361, 2524, 2625, 2735, 2927, 3057 },
        },
        .alphanumeric => switch (level) {
            .L => &.{ 0, 25, 47, 77, 114, 154, 195, 224, 279, 335, 395, 468, 535, 619, 667, 758, 854, 938, 1046, 1153, 1249, 1352, 1460, 1588, 1704, 1853, 1990, 2132, 2223, 2369, 2520, 2677, 2840, 3009, 3183, 3351, 3537, 3729, 3927, 4087, 4296 },
            .M => &.{ 0, 20, 38, 61, 90, 122, 154, 178, 221, 262, 311, 366, 419, 483, 528, 600, 656, 734, 816, 909, 970, 1035, 1134, 1248, 1326, 1451, 1542, 1637, 1732, 1839, 1994, 2113, 2238, 2369, 2506, 2632, 2780, 2894, 3054, 3220, 3391 },
            .Q => &.{ 0, 16, 29, 47, 67, 87, 108, 125, 157, 189, 221, 259, 296, 352, 376, 426, 470, 531, 574, 644, 702, 742, 823, 890, 963, 1041, 1094, 1172, 1263, 1322, 1429, 1499, 1618, 1700, 1787, 1867, 1966, 2071, 2181, 2298, 2420 },
            .H => &.{ 0, 10, 20, 35, 50, 64, 84, 93, 122, 143, 174, 200, 227, 259, 283, 321, 365, 408, 452, 493, 557, 587, 640, 672, 744, 779, 864, 910, 958, 1016, 1080, 1150, 1226, 1307, 1394, 1431, 1530, 1591, 1658, 1774, 1852 },
        },
        .latin1 => switch (level) {
            .L => &.{ 0, 17, 32, 53, 78, 106, 134, 154, 192, 230, 271, 321, 367, 425, 458, 520, 586, 644, 718, 792, 858, 929, 1003, 1091, 1171, 1273, 1367, 1465, 1528, 1628, 1732, 1840, 1952, 2068, 2188, 2303, 2431, 2563, 2699, 2809, 2953 },
            .M => &.{ 0, 14, 26, 42, 62, 84, 106, 122, 152, 180, 213, 251, 287, 331, 362, 412, 450, 504, 560, 624, 666, 711, 779, 857, 911, 997, 1059, 1125, 1190, 1264, 1370, 1452, 1538, 1628, 1722, 1809, 1911, 1989, 2099, 2213, 2331 },
            .Q => &.{ 0, 11, 20, 32, 46, 60, 74, 86, 108, 130, 151, 177, 203, 241, 258, 292, 322, 364, 394, 442, 482, 509, 565, 611, 661, 715, 751, 805, 868, 908, 982, 1030, 1112, 1168, 1228, 1283, 1351, 1423, 1499, 1579, 1663 },
            .H => &.{ 0, 7, 14, 24, 34, 44, 58, 64, 84, 98, 119, 137, 155, 177, 194, 220, 250, 280, 310, 338, 382, 403, 439, 461, 511, 535, 593, 625, 658, 698, 742, 790, 842, 898, 958, 983, 1051, 1093, 1139, 1219, 1273 },
        },
        .shiftjis => switch (level) {
            .L => &.{ 0, 10, 20, 32, 48, 65, 82, 95, 118, 141, 167, 198, 226, 262, 282, 320, 361, 397, 442, 488, 528, 572, 618, 672, 721, 784, 842, 902, 940, 1002, 1066, 1132, 1201, 1273, 1347, 1417, 1496, 1577, 1661, 1729, 1817 },
            .M => &.{ 0, 8, 16, 26, 38, 52, 65, 75, 93, 111, 131, 155, 177, 204, 223, 254, 277, 310, 345, 384, 410, 438, 480, 528, 561, 614, 652, 692, 732, 778, 843, 894, 947, 1002, 1060, 1113, 1176, 1224, 1292, 1362, 1435 },
            .Q => &.{ 0, 7, 12, 20, 28, 37, 45, 53, 66, 80, 93, 109, 125, 149, 159, 180, 198, 224, 243, 272, 297, 314, 348, 376, 407, 440, 462, 496, 534, 559, 604, 634, 684, 719, 756, 790, 832, 876, 923, 972, 1024 },
            .H => &.{ 0, 4, 8, 15, 21, 27, 36, 39, 52, 60, 74, 85, 96, 109, 120, 136, 154, 173, 191, 208, 235, 248, 270, 284, 315, 330, 365, 385, 405, 430, 457, 486, 518, 553, 590, 605, 647, 673, 701, 750, 784 },
        },
    };
}

fn isNumeric(c: u8) bool {
    return switch (c) {
        '0'...'9' => true,
        else => false,
    };
}

fn isAlphanumeric(c: u8) bool {
    return switch (c) {
        '0'...'9' => true,
        'A'...'Z' => true,
        ' ', '$', '%', '*', '+', '-', '.', '/', ':', ',' => true,
        else => false,
    };
}

fn generatorPolynomial(comptime n: usize) [n + 1]u8 {
    if (n == 1) return .{ 1, 1 };

    const prev = generatorPolynomial(n - 1);
    const prev_alpha = to_alpha(prev);
    const term_alpha: [2]u8 = .{ n - 1, 0 };

    var multiply_alpha: [n * 2][2]u8 = @splat(@splat(0));
    for (&prev_alpha, 0..) |a, i| {
        for (&term_alpha, 0..) |b, j| {
            multiply_alpha[(term_alpha.len * i) + j] = .{ a + b, @intCast(i + j) };
        }
    }
    var combine_alpha: [n + 1]u8 = @splat(0);
    for (0..n + 1) |i| {
        for (&multiply_alpha) |el| {
            if (el[1] == i) combine_alpha[i] ^= GF[el[0]];
        }
    }
    return combine_alpha;
}

fn to_alpha(array: anytype) [array.len]u8 {
    var result: [array.len]u8 = array;
    for (&result) |*x| x.* = @intCast(std.mem.indexOfScalar(u8, &GF, x.*).?);
    return result;
}

fn formatPattern(level: Level, mask: u3) u15 {
    return switch (level) {
        .L => switch (mask) {
            0 => 0b111011111000100,
            1 => 0b111001011110011,
            2 => 0b111110110101010,
            3 => 0b111100010011101,
            4 => 0b110011000101111,
            5 => 0b110001100011000,
            6 => 0b110110001000001,
            7 => 0b110100101110110,
        },
        .M => switch (mask) {
            0 => 0b101010000010010,
            1 => 0b101000100100101,
            2 => 0b101111001111100,
            3 => 0b101101101001011,
            4 => 0b100010111111001,
            5 => 0b100000011001110,
            6 => 0b100111110010111,
            7 => 0b100101010100000,
        },
        .Q => switch (mask) {
            0 => 0b011010101011111,
            1 => 0b011000001101000,
            2 => 0b011111100110001,
            3 => 0b011101000000110,
            4 => 0b010010010110100,
            5 => 0b010000110000011,
            6 => 0b010111011011010,
            7 => 0b010101111101101,
        },
        .H => switch (mask) {
            0 => 0b001011010001001,
            1 => 0b001001110111110,
            2 => 0b001110011100111,
            3 => 0b001100111010000,
            4 => 0b000011101100010,
            5 => 0b000001001010101,
            6 => 0b000110100001100,
            7 => 0b000100000111011,
        },
    };
}

//
//
//
//

const BufBiterator = struct {
    buf: []const u8,
    bits: std.bit_set.IntegerBitSet(8),
    idx: u8, // buf index
    jdx: u8, // bits index

    pub fn init(buf: []const u8) BufBiterator {
        return .{
            .buf = buf,
            .bits = .{ .mask = buf[0] },
            .idx = 0,
            .jdx = 0,
        };
    }

    pub fn next(self: *BufBiterator) ?u1 {
        if (self.jdx == 8) {
            self.jdx = 0;
            self.idx += 1;
            if (self.idx == self.buf.len) return null;
            self.bits.mask = self.buf[self.idx];
            return self.next();
        }
        const result = self.bits.isSet(7 - self.jdx);
        self.jdx += 1;
        return @intFromBool(result);
    }
};

//
//
//
//
//

const GridZigZag = struct {
    grid_size: usize,
    col_skip: usize,
    dir: u1,
    phase: u1,
    y: usize,
    x: usize,

    pub fn init(grid_size: usize, col_skip: usize) GridZigZag {
        return .{
            .grid_size = grid_size,
            .col_skip = col_skip,
            .dir = 0,
            .phase = 0,
            .y = grid_size,
            .x = grid_size - 2,
        };
    }

    pub fn next(self: *@This()) ?usize {
        blk: switch (self.dir) {
            0 => switch (self.phase) { //up
                0 => { //prev left
                    if (self.y == 0) {
                        self.x -= 1;
                        self.dir = 1;
                        self.phase = 1;
                        if (self.x == self.col_skip and self.col_skip == 0) return null;
                        if (self.x == self.col_skip) self.x -= 1;
                        break :blk;
                    }
                    self.y -= 1;
                    self.x += 1;
                    self.phase +%= 1;
                },
                1 => { //prev right
                    self.x -= 1;
                    self.phase +%= 1;
                },
            },
            1 => switch (self.phase) { //down
                0 => { //prev left
                    if (self.y == self.grid_size - 1) {
                        if (self.x == 0) return null;
                        self.x -= 1;
                        if (self.x == self.col_skip and self.col_skip == 0) return null;
                        if (self.x == self.col_skip) self.x -= 1;
                        self.dir = 0;
                        self.phase = 1;
                        break :blk;
                    }
                    self.x += 1;
                    self.y += 1;
                    self.phase +%= 1;
                },
                1 => { //prev right
                    self.x -= 1;
                    self.phase +%= 1;
                },
            },
        }
        return (self.y * self.grid_size) + self.x;
    }
};
