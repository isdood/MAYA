const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

// Import the Vulkan compute module
const vulkan = @import("vulkan");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("=== Starting Vulkan compute test ===\n", .{});
    print("Initializing Vulkan compute manager...\n", .{});
    
    // Initialize Vulkan
    var manager = vulkan.VulkanComputeManager.init(allocator) catch |err| {
        print("Failed to initialize Vulkan compute manager: {s}\n", .{@errorName(err)});
        return err;
    };
    defer manager.deinit();
    
    print("Vulkan compute manager initialized successfully!\n", .{});
    
    // Test data
    var input_data = [_]f32{1.0, 2.0, 3.0, 4.0};
    var output_data = [_]f32{0.0} ** 4;
    const input_dims = [4]i32{1, 1, 2, 2};  // batch, channels, height, width
    const output_dims = [4]i32{1, 1, 2, 2};
    
    print("Running spiral convolution...\n", .{});
    
    // Run the compute shader
    try manager.runSpiralConvolution(
        &input_data,
        &output_data,
        input_dims,
        output_dims,
        3,      // kernel_size
        1.618,  // golden_ratio
        0.01    // time_scale
    );
    
    print("Spiral convolution completed successfully!\n", .{});
    print("Output data: {d:.2}\n", .{output_data});
    print("=== Vulkan compute test completed successfully ===\n", .{});

    print("Output: {d:.2} {d:.2}\n", .{ output_data[0], output_data[1] });
    print("        {d:.2} {d:.2}\n", .{ output_data[2], output_data[3] });
}
