const std = @import("std");
usingnamespace @import("image.zig");
usingnamespace @import("color.zig");

const allocator = std.heap.page_allocator;

const F = f64;
const Complex = std.math.Complex(F);

const block_size: usize = 480;
const size_x: usize = 16;  //multiplicated by block size
const size_y: usize = 9;  //multiplicated by block size
const real_size_x = size_x * block_size;
const real_size_y = size_y * block_size;
const fsize_x = @intToFloat(F, real_size_x);
const fsize_y = @intToFloat(F, real_size_y);

const iterations: usize = 10000;
var zoom: F = 5.15E-12;
const zoom_inc: F = 0.98;
const centerx: F = 0.281717921930775;
const centery: F = 0.5771052841488505;

const black = Color32{ .r = 0, .g = 0, .b = 0, .a = 255 };

const block_count = (size_x * size_y);
var next_block: usize = 0;


pub fn main() anyerror!void {
    var frame: usize = 0;

    const cores = 2 * try std.Thread.cpuCount();
    //const cores: usize = 1;

    std.debug.print("Starting render, using {} threads.\n", .{ cores });
    var timer = try std.time.Timer.start();

    var img = try Image.init(allocator, real_size_x, real_size_y);
    defer img.deinit();

    var threads = try allocator.alloc(*std.Thread, cores);
    defer allocator.free(threads);

    while (frame != 1) : (frame += 1) {
        next_block = 0;

        std.debug.print("   - doing frame {}\n", .{frame});

        for (threads) |*thread| {
            thread.* = try std.Thread.spawn(img.data, renderBlock);
        }
        for (threads) |thread| {
            thread.wait();
        }

        var buf: [15:0]u8 = undefined;
        var thing = try std.fmt.bufPrint(&buf, "frame_{}.tga", .{frame});

        try img.saveAsTGA(thing);

        zoom = zoom * zoom_inc;
    }

    var ns = timer.read();
    ns /= 1_000_000;

    std.debug.print("Render took {}ms.\n", .{ns});
}


fn renderBlock(img: []Color32) void {

    while (true) {
        var my_block = @atomicRmw(usize, &next_block, .Add, 1, .SeqCst); //Atomically increment and get task
        if (my_block >= block_count)
            break;
        //std.debug.print("Thread id {} got block number {}.\n", .{ std.Thread.getCurrentId(), my_block });

        const x: usize = my_block % size_x;
        const y: usize = (my_block - x) / size_x;

        const xbegin: usize = x * block_size;
        const ybegin: usize = y * block_size;

        const xend = xbegin + block_size;
        const yend = ybegin + block_size;

        var px: usize = xbegin;
        while (px < xend) : (px += 1) {
            var fx = @intToFloat(F, px) / fsize_x;
            fx *= zoom; fx -= zoom / 2.0;
            fx += centerx;

            var py: usize = ybegin;
            while (py < yend) : (py += 1) {
                var fy = @intToFloat(F, py) / fsize_x;
                fy *= zoom; fy -= (fsize_y / fsize_x) * zoom / 2.0;
                fy += centery;

                var c = Complex.new(fx, fy);
                var z = Complex.new(0, 0);

                var max_mag: F = 0.0;

                var i: usize = 0;
                while (i < iterations and z.magnitude() <= 2.0) : (i += 1) {
                    //z.re = std.math.fabs(z.re);
                    //z.im = std.math.fabs(z.im);
                    z = Complex.add(Complex.mul(z, z), c);
                    max_mag = std.math.max(max_mag, z.magnitude());
                }
                var excess = max_mag - 2.0;
                
                if (i == iterations) {
                    img[px + py * real_size_x] = black;
                }
                else {
                    img[px + py * real_size_x] = Color.fromHSV(@intToFloat(f32, (i * 1) % 360), 0.6, @sqrt(@floatCast(f32, excess / 2.0))).to32BitsColor();
                }
                
            }
        }
        //std.debug.print("Block number {} done!\n", .{ my_block });
    }
    //std.debug.print("No more blocks are availible for {}, dying.\n", .{ std.Thread.getCurrentId() });
}
