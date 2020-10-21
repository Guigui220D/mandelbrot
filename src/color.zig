const math = @import("std").math;
const clamp = math.clamp;

pub const Color = packed struct {
    pub fn to32BitsColor(self: Color) Color32 {
        return Color32{
            .r = @floatToInt(u8, clamp(self.r, 0.0, 1.0) * 255.0),
            .g = @floatToInt(u8, clamp(self.g, 0.0, 1.0) * 255.0),
            .b = @floatToInt(u8, clamp(self.b, 0.0, 1.0) * 255.0),
            .a = 0xff,
        };
    }

    pub fn fromHSV(h: f32, s: f32, v: f32) Color {
        var hh: f32 = h;

        if (v <= 0.0)
            return Color{.r = 0, .g = 0, .b = 0};

        if (hh >= 360.0)
            hh = 0;
        hh /= 60.0;

        var ff: f32 = hh - math.floor(hh);

        var p: f32 = v * (1.0 - s);
        var q: f32 = v * (1.0 - (s * ff));
        var t: f32 = v * (1.0 - (s * (1.0 - ff)));

        return switch (@floatToInt(usize, hh)) {
            0 => Color{.r = v, .g = t, .b = p},
            1 => Color{.r = q, .g = v, .b = p},
            2 => Color{.r = p, .g = v, .b = t},
            3 => Color{.r = p, .g = q, .b = v},
            4 => Color{.r = t, .g = p, .b = v},
            else => Color{.r = v, .g = p, .b = q},
        };
    }

    r: f32,
    g: f32,
    b: f32
};

pub const Color32 = packed struct {
    b: u8, g: u8, r: u8, a: u8
};

//Guillaume Derex 2020
