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
}
test {
    const grid = qrcode.encode(
        .latin1,
        .L,
        25,
        \\Version 25 QR Code, up to 1853 characters at L level.
        \\A QR code (abbreviated from Quick Response code) is a type of matrix barcode (or two-dimensional code) that is designed to be read by smartphones. The code consists of black modules arranged in a square pattern on a white background. The information encoded may be text, a URL, or other data.
        \\Created by Toyota subsidiary Denso Wave in 1994, the QR code is one of the most popular types of two-dimensional barcodes. The QR code was designed to allow its contents to be decoded at high speed.
        \\The technology has seen frequent use in Japan and South Korea; the United Kingdom is the seventh-largest national consumer of QR codes.
        \\Although initially used for tracking parts in vehicle manufacturing, QR codes now are used in a much broader context, including both commercial tracking applications and convenience-oriented applications aimed at mobile phone users (termed mobile tagging). QR codes may be used to display text to the user, to add a vCard contact to the user's device, to open a Uniform Resource Identifier (URI), or to compose an e-mail or text message. Users can generate and print their own QR codes for others to scan and use by visiting one of several paid and free QR code generating sites or apps.
        ,
    );
    // 40 4f 55 66 57 27 36 96   f6 e2 03 23 52 05 15 22
    // 04 36 f6 46 52 c2 07 57   02 07 46 f2 03 13 83 53
    // 32 06 36 86 17 26 16 37   46 57 27 32 06 17 42 04
    // c2 06 c6 57 66 56 c2 e0   a4 12 05 15 22 06 36 f6
    // 46 52 02 86 16 26 27 26   57 66 96 17 46 56 42 06
    // 67 26 f6 d2 05 17 56 96   36 b2 05 26 57 37 06 f6
    // e7 36 52 06 36 f6 46 52   92 06 97 32 06 12 07 47
    // 97 06 52 06 f6 62 06 d6   17 47 26 97 82 06 26 17
    // 26 36 f6 46 52 02 86 f7   22 07 47 76 f2 d6 46 96
    // d6 56 e7 36 96 f6 e6 16   c2 06 36 f6 46 52 92 07
    // 46 86 17 42 06 97 32 06   46 57 36 96 76 e6 56 42
    // 07 46 f2 06 26 52 07 26   56 16 42 06 27 92 07 36
    // d6 17 27 47 06 86 f6 e6   57 32 e2 05 46 86 52 06
    // 36 f6 46 52 06 36 f6 e7   36 97 37 47 32 06 f6 62
    // 06 26 c6 16 36 b2 06 d6   f6 47 56 c6 57 32 06 17
    // 27 26 16 e6 76 56 42 06   96 e2 06 12 07 37 17 56
    // 17 26 52 07 06 17 47 46   57 26 e2 06 f6 e2 06 12
    // 07 76 86 97 46 52 06 26   16 36 b6 77 26 f7 56 e6
    // 42 e2 05 46 86 52 06 96   e6 66 f7 26 d6 17 46 96
    // f6 e2 06 56 e6 36 f6 46   56 42 06 d6 17 92 06 26
    // 52 07 46 57 87 42 c2 06   12 05 55 24 c2 c2 06 f7
    // 22 06 f7 46 86 57 22 06   46 17 46 12 e0 a4 37 26
    // 56 17 46 56 42 06 27 92   05 46 f7 96 f7 46 12 07
    // 37 56 27 36 96 46 96 17   27 92 04 46 56 e7 36 f2
    // 05 76 17 66 52 06 96 e2   03 13 93 93 42 c2 07 46
    // 86 52 05 15 22 06 36 f6   46 52 06 97 32 06 f6 e6
    // 52 06 f6 62 07 46 86 52   06 d6 f7 37 42 07 06 f7
    // 07 56 c6 17 22 07 47 97   06 57 32 06 f6 62 07 47
    // 76 f2 d6 46 96 d6 56 e7   36 96 f6 e6 16 c2 06 26
    // 17 26 36 f6 46 57 32 e2   05 46 86 52 05 15 22 06
    // 36 f6 46 52 07 76 17 32   06 46 57 36 96 76 e6 56
    // 42 07 46 f2 06 16 c6 c6   f7 72 06 97 47 32 06 36
    // f6 e7 46 56 e7 47 32 07   46 f2 06 26 52 06 46 56
    // 36 f6 46 56 42 06 17 42   06 86 96 76 82 07 37 06
    // 56 56 42 e0 a5 46 86 52   07 46 56 36 86 e6 f6 c6
    // f6 77 92 06 86 17 32 07   36 56 56 e2 06 67 26 57
    // 17 56 56 e7 42 07 57 36   52 06 96 e2 04 a6 17 06
    // 16 e2 06 16 e6 42 05 36   f7 57 46 82 04 b6 f7 26
    // 56 13 b2 07 46 86 52 05   56 e6 97 46 56 42 04 b6
    // 96 e6 76 46 f6 d2 06 97   32 07 46 86 52 07 36 57
    // 66 56 e7 46 82 d6 c6 17   26 76 57 37 42 06 e6 17
    // 46 96 f6 e6 16 c2 06 36   f6 e7 37 56 d6 57 22 06
    // f6 62 05 15 22 06 36 f6   46 57 32 e0 a4 16 c7 46
    // 86 f7 56 76 82 06 96 e6   97 46 96 16 c6 c7 92 07
    // 57 36 56 42 06 66 f7 22   07 47 26 16 36 b6 96 e6
    // 72 07 06 17 27 47 32 06   96 e2 07 66 56 86 96 36
    // c6 52 06 d6 16 e7 56 66   16 37 47 57 26 96 e6 72
    // c2 05 15 22 06 36 f6 46   57 32 06 e6 f7 72 06 17
    // 26 52 07 57 36 56 42 06   96 e2 06 12 06 d7 56 36
    // 82 06 27 26 f6 16 46 57   22 06 36 f6 e7 46 57 87
    // 42 c2 06 96 e6 36 c7 56   46 96 e6 72 06 26 f7 46
    // 82 06 36 f6 d6 d6 57 26   36 96 16 c2 07 47 26 16
    // 36 b6 96 e6 72 06 17 07   06 c6 96 36 17 46 96 f6
    // e7 32 06 16 e6 42 06 36   f6 e7 66 56 e6 96 56 e6
    // 36 52 d6 f7 26 96 56 e7   46 56 42 06 17 07 06 c6
    // 96 36 17 46 96 f6 e7 32   06 16 96 d6 56 42 06 17
    // 42 06 d6 f6 26 96 c6 52   07 06 86 f6 e6 52 07 57
    // 36 57 27 32 02 87 46 57   26 d6 56 42 06 d6 f6 26
    // 96 c6 52 07 46 16 76 76   96 e6 72 92 e2 05 15 22
    // 06 36 f6 46 57 32 06 d6   17 92 06 26 52 07 57 36
    // 56 42 07 46 f2 06 46 97   37 06 c6 17 92 07 46 57
    // 87 42 07 46 f2 07 46 86   52 07 57 36 57 22 c2 07
    // 46 f2 06 16 46 42 06 12   07 64 36 17 26 42 06 36
    // f6 e7 46 16 37 42 07 46   f2 07 46 86 52 07 57 36
    // 57 22 77 32 06 46 57 66   96 36 52 c2 07 46 f2 06
    // f7 06 56 e2 06 12 05 56   e6 96 66 f7 26 d2 05 26
    // 57 36 f7 57 26 36 52 04   96 46 56 e7 46 96 66 96
    // 57 22 02 85 55 24 92 92   c2 06 f7 22 07 46 f2 06
    // 36 f6 d7 06 f7 36 52 06   16 e2 06 52 d6 d6 16 96
    // c2 06 f7 22 07 46 57 87   42 06 d6 57 37 36 16 76
    // 52 e2 05 57 36 57 27 32   06 36 16 e2 06 76 56 e6
    // 57 26 17 46 52 06 16 e6   42 07 07 26 96 e7 42 07
    // 46 86 56 97 22 06 f7 76   e2 05 15 22 06 36 f6 46
    // 57 32 06 66 f7 22 06 f7   46 86 57 27 32 07 46 f2
    // 07 36 36 16 e2 06 16 e6   42 07 57 36 52 06 27 92
    // 07 66 97 36 97 46 96 e6   72 06 f6 e6 52 06 f6 62
    // 07 36 57 66 57 26 16 c2   07 06 16 96 42 06 16 e6
    // 42 06 67 26 56 52 05 15   22 06 36 f6 46 52 06 76
    // 56 e6 57 26 17 46 96 e6   72 07 36 97 46 57 32 06
    // f7 22 06 17 07 07 32 e0   ec 11 ec 11
    _ = &grid;
}
