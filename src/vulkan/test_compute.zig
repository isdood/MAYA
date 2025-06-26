const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

// Import the Vulkan compute module
const vulkan = @import("compute/manager.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("Initializing Vulkan compute...\n", .{});
    
    // Initialize Vulkan
    var manager = try vulkan.VulkanComputeManager.init(allocator);
    defer manager.deinit();
    
    print("Vulkan compute initialized successfully!\n", .{});

    // Simple test with 2x2x2x2 input and output
    const input_dims = [4]i32{ 1, 1, 2, 2 };  // [batch, channels, height, width]
    const output_dims = [4]i32{ 1, 1, 2, 2 }; // [batch, channels, height, width]
    
    // Create test input (simple gradient)
    const input = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var output = [_]f32{0.0} ** 4;

    print("Running spiral convolution...\n", .{});
    print("Input: {d:.2} {d:.2}\n", .{ input[0], input[1] });
    print("       {d:.2} {d:.2}\n\n", .{ input[2], input[3] });

    try manager.runSpiralConvolution(
        &input,
        &output,
        input_dims,
        output_dims,
        3,      // kernel_size
        1.618,  // golden_ratio (φ)
        1.0,    // time_scale
    );

    print("Output: {d:.2} {d:.2}\n", .{ output[0], output[1] });
    print("        {d:.2} {d:.2}\n", .{ output[2], output[3] });
}
