// tests/tensor_operations_test.zig
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const vk = @import("vulkan");
const Context = @import("vulkan/context").VulkanContext;
const TensorPipeline = @import("vulkan/compute/tensor_operations").TensorPipeline;
const Tensor4D = @import("vulkan/compute/tensor_operations").Tensor4D;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize Vulkan context
    var context = try Context.init(allocator, .{ .enable_validation = true });
    defer context.deinit();
    
    // Create command pool
    const command_pool = try context.createCommandPool();
    defer context.device.destroyCommandPool(command_pool, null);
    
    // Allocate command buffer
    const command_buffer = try context.allocateCommandBuffer(command_pool);
    
    // Begin command buffer
    const begin_info = vk.VkCommandBufferBeginInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
    };
    
    try vk.vkBeginCommandBuffer(command_buffer, &begin_info);
    
    // Create tensor pipeline
    var tensor_pipeline = try TensorPipeline.init(allocator, &context);
    defer tensor_pipeline.deinit();
    
    // Test tensor addition
    try testTensorOperation(
        allocator,
        &context,
        command_buffer,
        &tensor_pipeline,
        .Add,
        "Addition"
    );
    
    // End command buffer
    try vk.vkEndCommandBuffer(command_buffer);
    
    // Submit and wait for completion
    const submit_info = vk.VkSubmitInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = undefined,
        .pWaitDstStageMask = undefined,
        .commandBufferCount = 1,
        .pCommandBuffers = @ptrCast(&command_buffer),
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = undefined,
    };
    
    const fence = try context.device.createFence(&.{
        .sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = 0,
    }, null);
    defer context.device.destroyFence(fence, null);
    
    try context.device.queueSubmit(
        context.compute_queue,
        1,
        @ptrCast(&submit_info),
        fence
    );
    
    _ = try context.device.waitForFences(1, @ptrCast(&fence), vk.VK_TRUE, std.math.maxInt(u64));
    
    std.debug.print("All tests completed successfully!\n", .{});
}

fn testTensorOperation(
    allocator: Allocator,
    _: *Context,  // Unused parameter
    command_buffer: vk.VkCommandBuffer,
    pipeline: *TensorPipeline,
    operation: TensorPipeline.TensorOperation,
    name: []const u8,
) !void {
    std.debug.print("Testing tensor operation: {s}\n", .{name});
    
    const dims = [4]u32{ 4, 4, 4, 1 };  // 4x4x4x1 tensor
    
    // Create input and output tensors
    const input_a = try createTensor(allocator, dims, 1.0);
    defer allocator.free(input_a.data);
    
    const input_b = try createTensor(allocator, dims, 2.0);
    defer allocator.free(input_b.data);
    
    var output = try createTensor(allocator, dims, 0.0);
    defer allocator.free(output.data);
    
    // Execute the operation
    try pipeline.execute(
        command_buffer,
        input_a,
        input_b,
        &output,
        .{ .operation = operation }
    );
    
    // Validate results
    for (output.data, 0..) |val, i| {
        const expected: f32 = switch (operation) {
            .Add => 3.0,  // 1.0 + 2.0
            .Multiply => 2.0,  // 1.0 * 2.0
            .LinearCombination => 3.0,  // 1.0 * 1.0 + 2.0 * 1.0
        };
        
        if (@abs(val - expected) > 0.001) {
            std.debug.print("Mismatch at index {}: expected {}, got {}\n", .{
                i, expected, val
            });
            return error.ValidationFailed;
        }
    }
    
    std.debug.print("  ✓ {s} test passed\n", .{name});
}

fn createTensor(allocator: Allocator, dims: [4]u32, value: f32) !Tensor4D {
    const count = dims[0] * dims[1] * dims[2] * dims[3];
    const data = try allocator.alloc(f32, count);
    @memset(data, value);
    return Tensor4D{
        .data = data,
        .dims = dims,
    };
}
