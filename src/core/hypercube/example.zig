const std = @import("std");
const Allocator = std.mem.Allocator;
const Tensor4D = @import("tensor4d.zig").Tensor4D;
const SpiralConv = @import("spiral_conv.zig").SpiralConv;
const glimmer = @import("glimmer.zig");

/// Example demonstrating the HYPERCUBE components
pub fn runExample(allocator: Allocator) !void {
    std.debug.print("🚀 Starting HYPERCUBE example...\n", .{});
    
    // Create a simple 4D tensor (batch=1, channels=1, height=32, width=32)
    const input_shape = [4]usize{ 1, 1, 32, 32 };
    var input = try Tensor4D.init(allocator, input_shape);
    defer input.deinit();
    
    // Fill with a simple pattern (gradient from top-left to bottom-right)
    for (0..input_shape[2]) |y| {
        for (0..input_shape[3]) |x| {
            const value = (@as(f32, @floatFromInt(x + y)) / @as(f32, @floatFromInt(input_shape[2] + input_shape[3] - 2)));
            input.set(0, 0, y, x, value);
        }
    }
    
    // Save the input as an image
    const input_ppm = try glimmer.renderTensor4D(allocator, &input, .{});
    defer allocator.free(input_ppm);
    
    try std.fs.cwd().writeFile("input.ppm", input_ppm);
    std.debug.print("✅ Saved input image to input.ppm\n", .{});
    
    // Create a spiral convolution layer
    const in_channels = 1;
    const out_channels = 1;
    const conv = try SpiralConv.init(allocator, in_channels, out_channels, .{
        .kernel_size = 5,
        .stride = 1,
        .padding = 2,
    });
    defer conv.deinit();
    
    // Visualize the spiral kernel
    const kernel_viz = try glimmer.visualizeSpiralKernel(allocator, 11, 2.0);
    defer allocator.free(kernel_viz);
    
    std.debug.print("\nSpiral Kernel Visualization (11x11, 2 rotations):\n{s}\n", .{kernel_viz});
    
    // Apply the convolution
    const output = try conv.forward(&input);
    defer output.deinit();
    
    // Save the output as an image
    const output_ppm = try glimmer.renderTensor4D(allocator, output, .{});
    defer allocator.free(output_ppm);
    
    try std.fs.cwd().writeFile("output.ppm", output_ppm);
    std.debug.print("✅ Applied spiral convolution and saved result to output.ppm\n", .{});
    
    // Print tensor shapes
    std.debug.print("\nTensor shapes:\n", .{});
    std.debug.print("  Input:  {any}\n", .{input.shape});
    std.debug.print("  Output: {any}\n", .{output.shape});
    
    // Print some sample values
    std.debug.print("\nSample values (input[0,0,0:5,0:5]):\n", .{});
    for (0..5) |y| {
        for (0..5) |x| {
            std.debug.print("{d:4.2} ", .{input.get(0, 0, y, x)});
        }
        std.debug.print("\n", .{});
    }
    
    std.debug.print("\nSample values (output[0,0,0:5,0:5]):\n", .{});
    for (0..5) |y| {
        for (0..5) |x| {
            std.debug.print("{d:4.2} ", .{output.get(0, 0, y, x)});
        }
        std.debug.print("\n", .{});
    }
}

// Test the example
const testing = std.testing;

test "run example" {
    // This is just a simple test to verify the example compiles
    try runExample(testing.allocator);
}
