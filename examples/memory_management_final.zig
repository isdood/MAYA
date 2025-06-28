// examples/memory_management_final.zig
const std = @import("std");

// Import the Vulkan modules using the correct module paths
const vk = @import("vk");
const Context = @import("context_fixed.zig").VulkanContext;
const MemoryManager = @import("memory_manager.zig").MemoryManager;

// Helper function to print Vulkan memory properties
fn printMemoryProperties(device: vk.VkPhysicalDevice) void {
    var memory_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
    vk.vkGetPhysicalDeviceMemoryProperties(device, &memory_properties);
    
    std.debug.print("Memory Types ({}):\n", .{memory_properties.memoryTypeCount});
    for (0..memory_properties.memoryTypeCount) |i| {
        const flags = memory_properties.memoryTypes[i].propertyFlags;
        std.debug.print("  [{}] Heap: {}, Flags: {{ {b} }}\n", .{
            i,
            memory_properties.memoryTypes[i].heapIndex,
            flags,
        });
    }
    
    std.debug.print("Memory Heaps ({}):\n", .{memory_properties.memoryHeapCount});
    for (0..memory_properties.memoryHeapCount) |i| {
        std.debug.print("  [{}] Size: {} MB, Flags: {b}\n", .{
            i,
            memory_properties.memoryHeaps[i].size / (1024 * 1024),
            memory_properties.memoryHeaps[i].flags,
        });
    }
}

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
    
    std.debug.print("Creating Vulkan instance...\n", .{});
    var context = Context.init(allocator) catch |err| {
        std.debug.print("Failed to initialize Vulkan context: {}\n", .{err});
        return err;
    };
    
    std.debug.print("Vulkan context created successfully\n", .{});
    
    // Ensure we have a valid device
    const device = context.device orelse {
        std.debug.print("Error: No Vulkan device available\n", .{});
        return error.NoDevice;
    };
    
    const physical_device = context.physical_device orelse {
        std.debug.print("Error: No physical device selected\n", .{});
        return error.NoPhysicalDevice;
    };
    
    std.debug.print("Vulkan device and physical device are valid\n", .{});
    
    defer {
        std.debug.print("Deinitializing Vulkan context...\n", .{});
        context.deinit();
    }
    
    // Print memory properties for debugging
    std.debug.print("\nPhysical Device Memory Properties:\n", .{});
    printMemoryProperties(physical_device);

    // Initialize memory manager
    std.debug.print("\nInitializing memory manager...\n", .{});
    var memory_manager = MemoryManager.init(device, physical_device, allocator);
    
    std.debug.print("Memory manager initialized successfully\n", .{});
    
    // Create a buffer using MemoryManager
    std.debug.print("\nCreating buffer using MemoryManager...\n", .{});
    const buffer_size = 1024 * 1024; // 1MB buffer size
    
    // Define buffer usage and memory properties
    const usage = vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | 
                 vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | 
                 vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT;
                 
    // Use host-visible and host-coherent memory for this example
    const memory_properties = vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | 
                             vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    
    std.debug.print("Creating buffer with size: {} bytes\n", .{buffer_size});
    std.debug.print("Buffer usage: {b}\n", .{usage});
    std.debug.print("Memory properties: {b}\n", .{memory_properties});
    
    var buffer = try memory_manager.createBuffer(buffer_size, usage, memory_properties);
    defer memory_manager.destroyBuffer(&buffer);
    
    std.debug.print("Buffer created successfully. Buffer info:\n", .{});
    std.debug.print("  vk_buffer: {*}\n", .{buffer.buffer});
    std.debug.print("  memory: {*}\n", .{buffer.memory});
    std.debug.print("  size: {} bytes\n", .{buffer.size});
    
    // Example 1: Writing to and reading from a buffer
    {
        std.debug.print("\nExample 1: Writing to and reading from a buffer\n", .{});
        
        // Prepare some test data
        const test_data = [_]u32{ 1, 2, 3, 4, 5 };
        
        // Copy data to the buffer
        try memory_manager.copyToBuffer(
            &buffer,
            std.mem.sliceAsBytes(&test_data),
            0, // offset
        );
        
        // Read data back from the buffer
        const readback_data = try allocator.alloc(u8, test_data.len * @sizeOf(u32));
        defer allocator.free(readback_data);
        
        try memory_manager.copyFromBuffer(
            &buffer,
            readback_data,
            0, // offset
        );
        
        // Convert readback data to u32 slice
        const readback_slice = std.mem.bytesAsSlice(u32, readback_data);
        
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
        
        // Create a new buffer for vertex data
        const vertex_buffer_size = vertices.len * @sizeOf(Vertex);
        const vertex_buffer_usage = vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | 
                                   vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        
        std.debug.print("Creating vertex buffer with size: {} bytes\n", .{vertex_buffer_size});
        var vertex_buffer = try memory_manager.createBuffer(
            vertex_buffer_size,
            vertex_buffer_usage,
            memory_properties,
        );
        defer memory_manager.destroyBuffer(&vertex_buffer);
        
        // Copy vertex data to the buffer
        try memory_manager.copyToBuffer(
            &vertex_buffer,
            std.mem.sliceAsBytes(&vertices),
            0, // offset
        );
        
        std.debug.print("Successfully copied {} vertices to the vertex buffer\n", .{vertices.len});
    }
    
    std.debug.print("\nMemory management example completed successfully!\n", .{});
}

// Simple test to verify the example compiles
test "memory management example" {
    // This just verifies the example compiles
    _ = @import("memory_management_final.zig");
}
