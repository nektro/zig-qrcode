const std = @import("std");
const qrcode = @import("qrcode");

test {
    const grid = qrcode.encode(.latin1, .L, 1, "Ver1");
    // 40 45 66 57 23 10 ec 11   ec
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
