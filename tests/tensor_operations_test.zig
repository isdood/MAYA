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
    var context = try Context.init(std.testing.allocator);
    defer context.deinit();
    
    // For now, we'll just test that the context initializes correctly
    // and that we can create and destroy the tensor pipelines
    
    // Initialize tensor pipelines for different data types
    var pipeline_f32 = try TensorPipelineF32.init(std.testing.allocator, &context);
    defer pipeline_f32.deinit();
    
    var pipeline_i32 = try TensorPipelineI32.init(std.testing.allocator, &context);
    defer pipeline_i32.deinit();
    
    var pipeline_u32 = try TensorPipelineU32.init(std.testing.allocator, &context);
    defer pipeline_u32.deinit();
    
    // Simple test to verify the pipelines were created
    try testing.expect(pipeline_f32.context == &context);
    try testing.expect(pipeline_i32.context == &context);
    try testing.expect(pipeline_u32.context == &context);
    
    // For now, we'll just test that the pipelines were created successfully
    // More comprehensive tests will be added later
}
