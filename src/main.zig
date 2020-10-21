const std = @import("std");
usingnamespace @import("image.zig");
usingnamespace @import("color.zig");

const allocator = std.heap.page_allocator;

const F = f64;
const Complex = std.math.Complex(F);

const block_size: usize = 200;
const size: usize = 10;  //multiplicated by block size
const real_size = size * block_size;
const fsize = @intToFloat(F, real_size);

const iterations: usize = 3000;
const zoom: F = 4E-10;
const centerx: F = -0.0452407411;
const centery: F = 0.9868162204352258;

const black = Color32{ .r = 0, .g = 0, .b = 0, .a = 255 };

const block_count = size * size;
var next_block: usize = 0;

pub fn main() anyerror!void {
    var img = try Image.init(allocator, real_size, real_size);
    defer img.deinit();

    const cores = 2 * try std.Thread.cpuCount();
    //const cores: usize = 1;

    std.debug.print("Starting render, using {} threads.\n", .{ cores });

    var timer = try std.time.Timer.start();

    var threads = try allocator.alloc(*std.Thread, cores);
    defer allocator.free(threads);
    
    for (threads) |*thread| {
        thread.* = try std.Thread.spawn(img.data, renderBlock);
    }
    for (threads) |thread| {
        defer thread.wait();
    }
    
    var ns = timer.read();
    ns /= 1_000_000;
    std.debug.print("Render took {}ms.\n", .{ns});
    

    try img.saveAsTGA("bob.tga");
}


fn renderBlock(img: []Color32) void {

    while (true) {
        var my_block = @atomicRmw(usize, &next_block, .Add, 1, .SeqCst); //Atomically increment and get task
        if (my_block >= block_count)
            break;
        std.debug.print("Thread id {} got block number {}.\n", .{ std.Thread.getCurrentId(), my_block });

        const x: usize = my_block % size;
        const y: usize = (my_block - x) / size;

        const xbegin: usize = x * block_size;
        const ybegin: usize = y * block_size;

        const xend = xbegin + block_size;
        const yend = ybegin + block_size;

        var px: usize = xbegin;
        while (px < xend) : (px += 1) {
            var fx = @intToFloat(F, px) / fsize;
            fx *= zoom; fx -= zoom / 2.0;
            fx += centerx;

            var py: usize = ybegin;
            while (py < yend) : (py += 1) {
                var fy = @intToFloat(F, py) / fsize;
                fy *= zoom; fy -= zoom / 2.0;
                fy += centery;

                var c = Complex.new(fx, fy);
                var z = Complex.new(0, 0);

                var max_mag: F = 0.0;

                var i: usize = 0;
                while (i < iterations and z.magnitude() <= 2.0) : (i += 1) {
                    z = Complex.add(Complex.mul(z, z), c);
                    max_mag = std.math.max(max_mag, z.magnitude());
                }
                
                if (i == iterations) {
                    //img[px + py * real_size] = Color.fromHSV(@floatCast(f32, max_mag) * 180.0, 1.0, 0.5).to32BitsColor();
                    img[px + py * real_size] = black;
                }
                else 
                    img[px + py * real_size] = Color.fromHSV(@intToFloat(f32, (i * 1) % 360), 1.0, 1.0).to32BitsColor();
                    //img[px + py * real_size] = Color.fromHSV(@intToFloat(f32, (i % 2) * 180 + 60), 1.0, 1.0).to32BitsColor();
                
            }
        }
        std.debug.print("Block number {} done!\n", .{ my_block });
    }
    std.debug.print("No more blocks are availible for {}, dying.\n", .{ std.Thread.getCurrentId() });
}
