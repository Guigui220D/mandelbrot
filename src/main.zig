const std = @import("std");
usingnamespace @import("image.zig");
usingnamespace @import("color.zig");

const allocator = std.heap.page_allocator;

const F = f64;
const Complex = std.math.Complex(F);

const block_size: usize = 120;
const size_x: usize = 16;  //multiplicated by block size
const size_y: usize = 9;  //multiplicated by block size
const real_size_x = size_x * block_size;
const real_size_y = size_y * block_size;
const fsize_x = @intToFloat(F, real_size_x);
const fsize_y = @intToFloat(F, real_size_y);

var zoom: F = 5.15E-12;
const zoom_inc: F = 0.98;
const centerx: F = 0.281717921930775;
const centery: F = 0.5771052841488505;

const black = Color32{ .r = 0, .g = 0, .b = 0, .a = 255 };

const block_count = (size_x * size_y);
var next_block: usize = 0;

const multi_threaded: bool = true;

pub fn main() anyerror!void {
    var frame: usize = 0;

    const cores = if (multi_threaded) 2 * (try std.Thread.cpuCount()) else 1;

    std.debug.print("Starting render, using {} threads.\n", .{ cores });

    var img = try Image.init(allocator, real_size_x, real_size_y);
    defer img.deinit();

    var ns = try renderFrame(cores, &img);

    std.debug.print("Render took {}ms.\n", .{ns});
}

pub fn renderFrame(thread_count: usize, img: *Image) !u64 {
    var timer = try std.time.Timer.start();
    next_block = 0;

    var threads = try allocator.alloc(*std.Thread, thread_count);
    defer allocator.free(threads);

    for (threads) |*thread| {
        thread.* = try std.Thread.spawn(img.data, renderBlock);
    }
    for (threads) |thread| {
        thread.wait();
    }

    var ns = timer.read();
    return ns / 1_000_000;
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

                var p = checkPoint(c, 10000, false);
                
                if (p.in_the_set) {
                    img[px + py * real_size_x] = black;
                }
                else {
                    img[px + py * real_size_x] = Color.fromHSV(@intToFloat(f32, (p.total_iterations * 1) % 360), 0.6, @sqrt(@floatCast(f32, p.max_excess / 2.0))).to32BitsColor();
                }
                
            }
        }
        //std.debug.print("Block number {} done!\n", .{ my_block });
    }
    //std.debug.print("No more blocks are availible for {}, dying.\n", .{ std.Thread.getCurrentId() });
}

const PointInfo = struct {
    total_iterations: usize,
    max_excess: F,
    in_the_set: bool
};

fn checkPoint(c: Complex, iterations: usize, comptime burning_ship: bool) PointInfo {
    var i: usize = 0;
    var max_mag: F = 0.0;

    var z = Complex.new(0, 0);
    
    while (i < iterations and z.magnitude() <= 2.0) : (i += 1) {
        if (burning_ship) {
            z.re = std.math.fabs(z.re);
            z.im = std.math.fabs(z.im);
        }
        z = Complex.add(Complex.mul(z, z), c);
        max_mag = std.math.max(max_mag, z.magnitude());
    }

    return PointInfo{
        .total_iterations = i,
        .max_excess = max_mag - 2.0,
        .in_the_set = (i == iterations)
    };
}
