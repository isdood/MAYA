// examples/memory_management.zig
const std = @import("std");
const vk = @import("vk");
const Context = @import("vulkan/context").VulkanContext;

// Import Buffer_legacy directly from the memory module
const memory = @import("vulkan/memory");
const Buffer_legacy = memory.Buffer_legacy;

pub fn main() !void {
    std.debug.print("Starting memory management example...\n", .{});
    
    // Initialize allocator
    std.debug.print("Initializing allocator...\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        std.debug.print("Deinitializing allocator...\n", .{});
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    // Initialize Vulkan context
    std.debug.print("Initializing Vulkan context...\n", .{});
    var context = try Context.init(allocator);
    defer {
        std.debug.print("Deinitializing Vulkan context...\n", .{});
        context.deinit();
    }

    // Verify device and physical device are valid
    std.debug.print("Checking device handles...\n", .{});
    const device = context.device orelse return error.NoDevice;
    const physical_device = context.physical_device orelse return error.NoPhysicalDevice;
    std.debug.print("Using Vulkan device: {*}\n", .{device});
    std.debug.print("Using physical device: {*}\n", .{physical_device});

    // Create a buffer directly using Buffer_legacy for simplicity
    std.debug.print("Creating buffer...\n", .{});
    const buffer_size = 1024 * 1024; // 1MB buffer size
    const usage = vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    const memory_properties = vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;
    
    std.debug.print("Buffer size: {} bytes\n", .{buffer_size});
    std.debug.print("Buffer usage: {b}\n", .{usage});
    std.debug.print("Memory properties: {b}\n", .{memory_properties});
    
    std.debug.print("Buffer size: {} bytes\n", .{buffer_size});
    std.debug.print("Buffer usage flags: {b}\n", .{usage});
    std.debug.print("Memory properties: {b}\n", .{memory_properties});
    
    std.debug.print("Initializing buffer...\n", .{});
    var buffer = Buffer_legacy.init(
        device,
        physical_device,
        buffer_size,
        usage,
        memory_properties,
    ) catch |err| {
        std.debug.print("Failed to initialize buffer: {}\n", .{err});
        return err;
    };
    
    std.debug.print("Buffer created successfully. Buffer info:\n", .{});
    std.debug.print("  vk_buffer: {*}\n", .{buffer.vk_buffer});
    std.debug.print("  memory: {*}\n", .{buffer.memory});
    std.debug.print("  size: {} bytes\n", .{buffer.size});
    
    defer {
        std.debug.print("Destroying buffer...\n", .{});
        buffer.deinit(device);
        std.debug.print("Buffer destroyed\n", .{});
    }
    
    // For this example, we'll just use direct memory mapping since we're using HOST_VISIBLE memory
    // In a real application, you'd want to use proper staging buffers for device-local memory

    // Example 1: Writing to and reading from a buffer
    {
        std.debug.print("Example 1: Writing to and reading from a buffer\n", .{});
        
        // Prepare some test data
        const test_data = [_]u32{ 1, 2, 3, 4, 5 };
        
        // Map the buffer and copy data directly
        const mapped_data = try buffer.map(device, 0, test_data.len * @sizeOf(u32));
        defer buffer.unmap(device);
        
        // Get a typed pointer to the mapped memory
        const dest_ptr = @as([*]u8, @ptrCast(mapped_data));
        const dest_slice = dest_ptr[0..test_data.len * @sizeOf(u32)];
        
        // Copy data to the mapped memory
        const src_slice = std.mem.sliceAsBytes(&test_data);
        @memcpy(dest_slice, src_slice);
        
        // Flush the memory to ensure the write is visible to the device
        try buffer.flush(device, 0, test_data.len * @sizeOf(u32));
        
        // Invalidate the memory before reading back
        try buffer.invalidate(device, 0, test_data.len * @sizeOf(u32));
        
        // Get a typed slice of the readback data
        const readback_slice = std.mem.bytesAsSlice(u32, dest_slice);
        
        // Verify the data
        std.debug.print("  Wrote data: ", .{});
        for (test_data) |val| std.debug.print("{} ", .{val});
        std.debug.print("\n  Read back: ", .{});
        for (readback_slice) |val| std.debug.print("{} ", .{val});
        std.debug.print("\n", .{});
        
        // Verify the data matches
        for (test_data, 0..) |expected, i| {
            std.debug.assert(readback_slice[i] == expected);
        }
        
        std.debug.print("  Successfully verified readback of {} bytes\n", .{test_data.len * @sizeOf(u32)});
    }
    
    // Example 2: Using the buffer with different data types
    {
        std.debug.print("\nExample 2: Using the buffer with different data types\n", .{});
        
        // Define a custom struct to write to the buffer
        const Vertex = extern struct {
            x: f32,
            y: f32,
            z: f32,
            r: f32,
            g: f32,
            b: f32,
        };
        
        const vertices = [_]Vertex{
            .{ .x = -0.5, .y = -0.5, .z = 0.0, .r = 1.0, .g = 0.0, .b = 0.0 },
            .{ .x = 0.5, .y = -0.5, .z = 0.0, .r = 0.0, .g = 1.0, .b = 0.0 },
            .{ .x = 0.0, .y = 0.5, .z = 0.0, .r = 0.0, .g = 0.0, .b = 1.0 },
        };
        
        // Map the buffer and copy the vertex data
        const mapped_data = try buffer.map(device, 0, @sizeOf(@TypeOf(vertices)));
        defer buffer.unmap(device);
        
        // Get a typed pointer to the mapped memory
        const dest_ptr = @as([*]u8, @ptrCast(mapped_data));
        const dest_slice = dest_ptr[0..@sizeOf(@TypeOf(vertices))];
        
        // Copy data to the mapped memory
        const src_slice = std.mem.sliceAsBytes(&vertices);
        @memcpy(dest_slice, src_slice);
        
        // Flush the memory to ensure the write is visible to the device
        try buffer.flush(device, 0, @sizeOf(@TypeOf(vertices)));
        
        // Invalidate the memory before reading back
        try buffer.invalidate(device, 0, @sizeOf(@TypeOf(vertices)));
        
        // Get a typed slice of the readback data
        const readback_slice = std.mem.bytesAsSlice(Vertex, dest_slice[0..@sizeOf(Vertex) * vertices.len]);
        
        // Verify the data
        std.debug.print("  Wrote triangle vertices with colors:\n", .{});
        for (vertices, 0..) |vertex, i| {
            std.debug.print("    Vertex {}: ({d:.1}, {d:.1}, {d:.1}) color: ({d:.1}, {d:.1}, {d:.1})\n", .{
                i, vertex.x, vertex.y, vertex.z, vertex.r, vertex.g, vertex.b,
            });
        }
        
        // Verify the data matches
        for (vertices, 0..) |expected, i| {
            std.debug.assert(std.meta.eql(readback_slice[i], expected));
        }
        
        std.debug.print("  Successfully verified readback of {} vertices\n", .{vertices.len});
    }
    
    std.debug.print("\nAll memory management examples completed successfully!\n", .{});
}

// Simple test to verify the example compiles
test "memory management example" {
    // This just verifies the example compiles
    // In a real test, you'd want to run the example and verify its behavior
    _ = @import("memory_management.zig");
}
