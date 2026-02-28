const std = @import("std");
const qrcode = @import("qrcode");

test {
    const grid = qrcode.encode(.latin1, .L, 1, "Ver1");
    // 40 45 66 57 23 10 ec 11   ec
    _ = &grid;
}
test {
    const grid = qrcode.encode(.latin1, .L, 2, "Version 2");
    // 40 95 66 57 27 36 96 f6   e2 03 20 ec 11 ec 11 ec
    _ = &grid;
}
test {
    const grid = qrcode.encode(.latin1, .L, 3, "Version 3 QR Code");
    // 41 15 66 57 27 36 96 f6   e2 03 32 05 15 22 04 36
    // f6 46 50 ec 11 ec 11 ec   11 ec
    _ = &grid;
}
test {
    const grid = qrcode.encode(.latin1, .L, 4, "Version 4 QR Code, up to 50 char");
    // 42 05 66 57 27 36 96 f6   e2 03 42 05 15 22 04 36
    // f6 46 52 c2 07 57 02 07   46 f2 03 53 02 06 36 86
    // 17 20 ec 11
    _ = &grid;
}
test {
    const grid = qrcode.encode(.latin1, .M, 10, "VERSION 10 QR CODE, UP TO 174 CHAR AT H LEVEL, WITH 57X57 MODULES AND PLENTY OF ERROR CORRECTION TO GO AROUND. NOTE THAT THERE ARE ADDITIONAL TRACKING BOXES");
    // 20 25 60 66 db 42 85 e0   b7 37 4e 34 68 95 d0 00
    // 04 b0 80 d6 72 91 34 c7   2a 93 fc c0 c1 e7 19 df
    // cc b9 a5 4a a8 b4 00 01   2c 20 df 9d 1a 3b 21 1d
    // 17 48 af bf 64 ce ef e8   81 d9 4d b1 e9 46 d3 bc
    // d8 b1 d4 8c d7 9c 68 d2   6d 28 2a 57 13 f3 8c 5c
    // 5d 19 7a 6b d5 d4 e7 9e   21 1d 27 ce 2c 1e 9e d2
    // a5 22 a6 8e ea 9a 39 e9   6e 95 c4 f3 af 9c 66 4a
    // 30 68 2b d1 03 dd b7 00   ec 11
    _ = &grid;

    const bg_black = "\x1b[40m";
    const bg_white = "\x1b[47m";
    const bg_blue = "\x1b[44m";
    const bg_reset = "\x1b[49m";

    const fg_black = "\x1b[30m";
    const fg_white = "\x1b[37m";
    const fg_reset = "\x1b[39m";

    for (0..grid.size) |y| {
        for (0..grid.size) |x| {
            std.debug.print("{s}", .{if (grid.hasSet(x, y))
                if (grid.isSet(x, y))
                    bg_black ++ fg_black ++ "██"
                else
                    bg_white ++ fg_white ++ "  "
            else
                bg_blue ++ fg_white ++ " -"});
        }
        std.debug.print("{s}", .{fg_reset ++ bg_reset});
        std.debug.print("\n", .{});
    }
}
