// examples/memory_management.zig
const std = @import("std");
const vk = @import("vk");
const Buffer = @import("../src/vulkan/memory/buffer.zig").Buffer;
const BufferPool = @import("../src/vulkan/memory/pool.zig").BufferPool;
const StagingManager = @import("../src/vulkan/memory/transfer.zig").StagingManager;
const Context = @import("../src/vulkan/context").VulkanContext;

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Vulkan context (simplified)
    var context = try Context.init(allocator, .{});
    defer context.deinit();

    // Create a buffer pool for device-local buffers
    const buffer_size = 1024 * 1024; // 1MB
    var pool = try BufferPool.init(
        allocator,
        &context,
        buffer_size,
        vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
    );
    defer pool.deinit();

    // Create a staging manager for transfers
    const transfer_queue_family = 0; // TODO: Get from context
    var staging_mgr = try StagingManager.init(allocator, &context, transfer_queue_family);
    defer staging_mgr.deinit();

    // Example 1: Using the buffer pool
    {
        std.debug.print("Example 1: Using buffer pool\n", .{});
        
        // Acquire a buffer from the pool
        const buffer = try pool.acquire();
        defer pool.release(buffer) catch |err| {
            std.debug.print("Error releasing buffer: {}\n", .{err});
            // If release fails, we need to clean up manually
            buffer.deinit();
            allocator.destroy(buffer);
        };
        
        // Prepare some test data
        const test_data = [_]u8{ 1, 2, 3, 4, 5 };
        
        // Copy data to the buffer using the staging manager
        try staging_mgr.copyToDevice(buffer, &test_data);
        
        // Read data back (for demonstration, in real code you'd process it on GPU)
        var readback = try allocator.alloc(u8, test_data.len);
        defer allocator.free(readback);
        
        try staging_mgr.copyFromDevice(buffer, readback);
        
        // Verify the data
        std.debug.assert(std.mem.eql(u8, &test_data, readback));
        std.debug.print("✅ Buffer pool test passed\n", .{});
    }
    
    // Example 2: Using the staging manager directly
    {
        std.debug.print("\nExample 2: Using staging manager directly\n", .{});
        
        // Create a device-local buffer
        const buffer = try Buffer.init(
            &context,
            buffer_size,
            vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );
        defer buffer.deinit();
        
        // Prepare test data
        const test_data = [_]u8{ 5, 4, 3, 2, 1 };
        
        // Use the staging manager to copy data to the device
        try staging_mgr.copyToDevice(&buffer, &test_data);
        
        // Read data back
        var readback = try allocator.alloc(u8, test_data.len);
        defer allocator.free(readback);
        
        try staging_mgr.copyFromDevice(&buffer, readback);
        
        // Verify the data
        std.debug.assert(std.mem.eql(u8, &test_data, readback));
        std.debug.print("✅ Staging manager test passed\n", .{});
    }
}

// Simple test to verify the example compiles
test "memory management example" {
    // This just verifies the example compiles
    // In a real test, you'd want to run the example and verify its behavior
    _ = @import("memory_management.zig");
}
