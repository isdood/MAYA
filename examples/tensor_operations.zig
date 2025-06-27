// examples/tensor_operations.zig
const std = @import("std");
const vk = @import("vk");
const Context = @import("../src/vulkan/context.zig").VulkanContext;
const memory = @import("../src/vulkan/compute/memory.zig");
const TensorMemoryManager = memory.TensorMemoryManager;

// Import tensor types for convenience
const Tensor4DF32 = memory.Tensor4DF32;
const TensorOperation = memory.TensorOperation;
const TensorOperationParams = memory.TensorOperationParams;

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize Vulkan context
    var context = try Context.init(allocator, .{});
    defer context.deinit();

    // Initialize memory manager
    var memory_manager = try TensorMemoryManager.init(allocator, &context);
    defer memory_manager.deinit();

    // Create input tensors
    const dims = [4]u32{2, 2, 2, 2}; // 2x2x2x2 tensor
    
    // Create tensor A with value 2.0
    var tensor_a = try memory_manager.createTensor(f32, dims, 2.0);
    defer tensor_a.deinit();
    
    // Create tensor B with value 3.0
    var tensor_b = try memory_manager.createTensor(f32, dims, 3.0);
    defer tensor_b.deinit();
    
    // Create output tensor (uninitialized)
    var output = try memory_manager.createUninitializedTensor(f32, dims);
    defer output.deinit();
    
    // Create a compute pipeline for tensor operations
    var pipeline = try memory.TensorPipelineF32.init(allocator, &context);
    defer pipeline.deinit();
    
    // Create a command buffer for the operation
    const device = context.device orelse return error.DeviceNotInitialized;
    const command_buffer = try context.createCommandBuffer();
    defer vk.vkFreeCommandBuffers(device, context.command_pool, 1, &command_buffer);
    
    // Begin command buffer
    const begin_info = vk.VkCommandBufferBeginInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
    };
    
    try vk.checkVkResult(vk.vkBeginCommandBuffer(command_buffer, &begin_info));
    
    // Execute tensor addition: output = tensor_a + tensor_b
    try pipeline.execute(
        command_buffer,
        &tensor_a,
        &tensor_b,
        &output,
        TensorOperationParams(f32){ .operation = .add },
        allocator,
    );
    
    // End command buffer
    try vk.checkVkResult(vk.vkEndCommandBuffer(command_buffer));
    
    // Submit the command buffer
    const submit_info = vk.VkSubmitInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,
    };
    
    // Submit to the queue
    const queue = context.graphics_queue orelse return error.QueueNotInitialized;
    try vk.checkVkResult(vk.vkQueueSubmit(queue, 1, &submit_info, null));
    
    // Wait for the queue to finish
    try vk.checkVkResult(vk.vkQueueWaitIdle(queue));
    
    // Read back the results
    const results = try output.readData(allocator);
    defer allocator.free(results);
    
    // Print the results
    std.debug.print("Tensor Addition (2.0 + 3.0):\n", .{});
    for (results, 0..) |value, i| {
        std.debug.print("  [{}] = {d:.1}\n", .{i, value});
    }
    
    // Verify the results
    for (results) |value| {
        try std.testing.expectApproxEqAbs(@as(f32, 5.0), value, 0.001);
    }
    
    std.debug.print("Tensor operation completed successfully!\n", .{});
}

// Test the example
const expect = std.testing.expect;

test "tensor operations" {
    // This just verifies the example compiles
    // In a real test, you'd want to run the example and verify its behavior
    _ = @import("tensor_operations.zig");
}
