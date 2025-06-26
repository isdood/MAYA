// tests/tensor_operations_test.zig
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// Import Vulkan bindings and modules
const vk = @import("vulkan");
const Context = @import("vulkan/context").VulkanContext;
const Buffer = @import("vulkan/memory/buffer").Buffer;
const tensor_ops = @import("vulkan/compute/tensor_operations");

// Import tensor types and pipelines
const Tensor4DF32 = tensor_ops.Tensor4D(f32);
const Tensor4DI32 = tensor_ops.Tensor4D(i32);
const Tensor4DU32 = tensor_ops.Tensor4D(u32);

const TensorPipelineF32 = tensor_ops.TensorPipeline(f32);
const TensorPipelineI32 = tensor_ops.TensorPipeline(i32);
const TensorPipelineU32 = tensor_ops.TensorPipeline(u32);

const TensorOperation = tensor_ops.TensorOperation;

const TensorDims = [4]u32;

fn testTensorOperation(
    comptime T: type,
    context: *Context,
    command_buffer: vk.VkCommandBuffer,
    pipeline: anytype,
    a: []const T,
    b: []const T,
    expected: []const T,
    dims: TensorDims,
    op: TensorOperation,
    alpha: T,
    beta: T,
) !void {
    const TensorType = tensor_ops.Tensor4D(T);
    const allocator = std.testing.allocator;
    
    // Create input tensors
    var tensor_a = try TensorType.init(context, dims, 0);
    defer tensor_a.deinit();
    
    var tensor_b = try TensorType.init(context, dims, 0);
    defer tensor_b.deinit();
    
    // Create output tensor
    var output = try TensorType.init(context, dims, 0);
    defer output.deinit();
    
    // Copy test data to GPU
    try tensor_a.writeData(a);
    try tensor_b.writeData(b);
    
    // Execute the operation
    try pipeline.execute(
        command_buffer,
        &tensor_a,
        &tensor_b,
        &output,
        .{
            .alpha = alpha,
            .beta = beta,
            .operation = op,
        },
    );
    
    // Read back the results
    const result = try output.readData(allocator);
    defer allocator.free(result);
    
    // Verify the results
    for (expected, 0..) |expected_val, i| {
        if (@typeInfo(T) == .Float) {
            try std.testing.expectApproxEqAbs(expected_val, result[i], 0.001);
        } else {
            try std.testing.expectEqual(expected_val, result[i]);
        }
    }
}

test "tensor operations with different data types" {
    // Initialize Vulkan context
    var context = try Context.init(
        std.testing.allocator,
        .{ .enable_validation = true },
    );
    defer context.deinit();
    
    // Create command pool and command buffer
    const command_pool = try context.device.createCommandPool(
        &vk.VkCommandPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = context.queue_family_index,
        },
        null,
    );
    defer context.device.destroyCommandPool(command_pool, null);
    
    var command_buffer: vk.VkCommandBuffer = undefined;
    _ = try context.device.allocateCommandBuffers(
        &vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        },
        @ptrCast(&command_buffer),
    );
    
    // Initialize tensor pipelines for different data types
    var pipeline_f32 = try TensorPipelineF32.init(std.testing.allocator, &context);
    defer pipeline_f32.deinit();
    
    var pipeline_i32 = try TensorPipelineI32.init(std.testing.allocator, &context);
    defer pipeline_i32.deinit();
    
    var pipeline_u32 = try TensorPipelineU32.init(std.testing.allocator, &context);
    defer pipeline_u32.deinit();
    
    // Begin command buffer
    try context.device.beginCommandBuffer(
        command_buffer,
        &vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        },
    );
    
    // Test float32 operations
    try testTensorOperation(
        f32,
        &context,
        command_buffer,
        &pipeline_f32,
        &[_]f32{ 1.0, 2.0, 3.0, 4.0 },
        &[_]f32{ 5.0, 6.0, 7.0, 8.0 },
        &[_]f32{ 6.0, 8.0, 10.0, 12.0 }, // Addition
        .{ 2, 2, 1, 1 },
        .Add,
        1.0,
        1.0,
    );
    
    try testTensorOperation(
        f32,
        &context,
        command_buffer,
        &pipeline_f32,
        &[_]f32{ 1.0, 2.0, 3.0, 4.0 },
        &[_]f32{ 2.0, 2.0, 2.0, 2.0 },
        &[_]f32{ 2.0, 4.0, 6.0, 8.0 }, // Multiplication
        .{ 2, 2, 1, 1 },
        .Multiply,
        1.0,
        1.0,
    );
    
    // Test int32 operations
    try testTensorOperation(
        i32,
        &context,
        command_buffer,
        &pipeline_i32,
        &[_]i32{ 1, 2, 3, 4 },
        &[_]i32{ 5, 6, 7, 8 },
        &[_]i32{ 6, 8, 10, 12 }, // Addition
        .{ 2, 2, 1, 1 },
        .Add,
        1,
        1,
    );
    
    // Test uint32 operations
    try testTensorOperation(
        u32,
        &context,
        command_buffer,
        &pipeline_u32,
        &[_]u32{ 1, 2, 3, 4 },
        &[_]u32{ 5, 6, 7, 8 },
        &[_]u32{ 6, 8, 10, 12 }, // Addition
        .{ 2, 2, 1, 1 },
        .Add,
        1,
        1,
    );
    
    // End command buffer
    try context.device.endCommandBuffer(command_buffer);
    
    // Submit the command buffer
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
    
    try context.device.queueSubmit(
        context.graphics_queue,
        1,
        @ptrCast(&submit_info),
        null,
    );
    
    // Wait for the GPU to finish
    try context.device.queueWaitIdle(context.graphics_queue);
}
