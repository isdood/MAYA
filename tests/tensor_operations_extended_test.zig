// tests/tensor_operations_extended_test.zig
const std = @import("std");
const testing = std.testing;
const math = std.math;
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
    
    // Copy data to device
    try tensor_a.upload(a);
    try tensor_b.upload(b);
    
    // Dispatch the compute shader
    try pipeline.dispatch(command_buffer, &tensor_a, &tensor_b, &output, op, alpha, beta);
    
    // Wait for the GPU to finish
    try context.deviceWaitIdle();
    
    // Download and verify results
    const result = try allocator.alloc(T, a.len);
    defer allocator.free(result);
    
    try output.download(result);
    
    // Compare results with expected values
    for (result, expected) |r, e| {
        if (T == f32) {
            try testing.expectApproxEqRel(@as(f32, @floatCast(e)), @as(f32, @floatCast(r)), 0.001);
        } else {
            try testing.expectEqual(e, r);
        }
    }
}

fn runTensorOperationTest(
    comptime T: type,
    context: *Context,
    command_buffer: vk.VkCommandBuffer,
    pipeline: anytype,
    op: TensorOperation,
    alpha: T,
    beta: T,
) !void {
    const dims = TensorDims{ 2, 2, 2, 2 }; // Small tensor for testing
    const len = dims[0] * dims[1] * dims[2] * dims[3];
    
    // Create test data
    const a = try std.testing.allocator.alloc(T, len);
    defer std.testing.allocator.free(a);
    
    const b = try std.testing.allocator.alloc(T, len);
    defer std.testing.allocator.free(b);
    
    const expected = try std.testing.allocator.alloc(T, len);
    defer std.testing.allocator.free(expected);
    
    // Fill with test data
    for (0..len) |i| {
        const val: T = @floatFromInt(i);
        a[i] = val;
        b[i] = @floatFromInt(i * 2);
        
        // Compute expected result based on operation
        expected[i] = switch (op) {
            .add => a[i] + b[i],
            .sub => a[i] - b[i],
            .mul => a[i] * b[i],
            .div => if (b[i] == 0) 0 else a[i] / b[i],
            .max => @max(a[i], b[i]),
            .min => @min(a[i], b[i]),
            .pow => if (T == f32) std.math.pow(f32, a[i], b[i]) else 0,
            .relu => @max(a[i], 0),
            .sigmoid => if (T == f32) 1.0 / (1.0 + std.math.exp(-a[i])) else 1,
            .tanh => if (T == f32) std.math.tanh(a[i]) else 0,
        };
    }
    
    // Run the test
    try testTensorOperation(T, context, command_buffer, pipeline, a, b, expected, dims, op, alpha, beta);
}

test "tensor operations with different data types" {
    // Initialize Vulkan context
    var context = try Context.init();
    defer context.deinit();
    
    // Create command buffer
    const command_buffer = try context.createCommandBuffer();
    defer context.destroyCommandBuffer(command_buffer);
    
    // Initialize pipelines for different data types
    var pipeline_f32 = try TensorPipelineF32.init(&context);
    defer pipeline_f32.deinit();
    
    var pipeline_i32 = try TensorPipelineI32.init(&context);
    defer pipeline_i32.deinit();
    
    var pipeline_u32 = try TensorPipelineU32.init(&context);
    defer pipeline_u32.deinit();
    
    // Test different operations for each data type
    const test_cases = struct {
        op: TensorOperation,
        alpha: f32,
        beta: f32,
    }[]{
        .{ .op = .add, .alpha = 1.0, .beta = 1.0 },
        .{ .op = .sub, .alpha = 1.0, .beta = 1.0 },
        .{ .op = .mul, .alpha = 1.0, .beta = 0.0 },
        .{ .op = .div, .alpha = 1.0, .beta = 0.0 },
        .{ .op = .max, .alpha = 1.0, .beta = 1.0 },
        .{ .op = .min, .alpha = 1.0, .beta = 1.0 },
    };
    
    // Test float32 operations
    for (test_cases) |tc| {
        try runTensorOperationTest(f32, &context, command_buffer, &pipeline_f32, tc.op, tc.alpha, tc.beta);
    }
    
    // Test int32 operations (skip non-integer operations)
    const int_test_cases = struct {
        op: TensorOperation,
        alpha: i32,
        beta: i32,
    }[]{
        .{ .op = .add, .alpha = 1, .beta = 1 },
        .{ .op = .sub, .alpha = 1, .beta = 1 },
        .{ .op = .mul, .alpha = 1, .beta = 0 },
        .{ .op = .max, .alpha = 1, .beta = 1 },
        .{ .op = .min, .alpha = 1, .beta = 1 },
    };
    
    for (int_test_cases) |tc| {
        try runTensorOperationTest(i32, &context, command_buffer, &pipeline_i32, tc.op, tc.alpha, tc.beta);
    }
    
    // Test uint32 operations
    for (int_test_cases) |tc| {
        try runTensorOperationTest(u32, &context, command_buffer, &pipeline_u32, tc.op, @intCast(tc.alpha), @intCast(tc.beta));
    }
    
    // Test activation functions (float32 only)
    const activation_ops = [_]TensorOperation{ .relu, .sigmoid, .tanh };
    for (activation_ops) |op| {
        try runTensorOperationTest(f32, &context, command_buffer, &pipeline_f32, op, 1.0, 0.0);
    }
}

test "tensor operations with different shapes" {
    // Initialize Vulkan context
    var context = try Context.init();
    defer context.deinit();
    
    // Create command buffer
    const command_buffer = try context.createCommandBuffer();
    defer context.destroyCommandBuffer(command_buffer);
    
    // Initialize pipeline
    var pipeline = try TensorPipelineF32.init(&context);
    defer pipeline.deinit();
    
    // Test different tensor shapes
    const test_shapes = [_]TensorDims{
        // 1D
        [4]u32{8, 1, 1, 1},
        // 2D
        [4]u32{4, 4, 1, 1},
        // 3D
        [4]u32{4, 4, 4, 1},
        // 4D
        [4]u32{2, 2, 2, 2},
        // Non-power-of-two
        [4]u32{3, 5, 2, 1},
    };
    
    for (test_shapes) |dims| {
        const len = dims[0] * dims[1] * dims[2] * dims[3];
        
        // Create test data
        const a = try std.testing.allocator.alloc(f32, len);
        defer std.testing.allocator.free(a);
        
        const b = try std.testing.allocator.alloc(f32, len);
        defer std.testing.allocator.free(b);
        
        const expected = try std.testing.allocator.alloc(f32, len);
        defer std.testing.allocator.free(expected);
        
        // Fill with test data
        for (0..len) |i| {
            a[i] = @floatFromInt(i);
            b[i] = @floatFromInt(i * 2);
            expected[i] = a[i] + b[i];
        }
        
        // Test addition with this shape
        try testTensorOperation(f32, &context, command_buffer, &pipeline, a, b, expected, dims, .add, 1.0, 1.0);
    }
}

test "tensor operations with different alpha/beta values" {
    // Initialize Vulkan context
    var context = try Context.init();
    defer context.deinit();
    
    // Create command buffer
    const command_buffer = try context.createCommandBuffer();
    defer context.destroyCommandBuffer(command_buffer);
    
    // Initialize pipeline
    var pipeline = try TensorPipelineF32.init(&context);
    defer pipeline.deinit();
    
    const dims = TensorDims{ 2, 2, 1, 1 };
    const len = dims[0] * dims[1] * dims[2] * dims[3];
    
    // Create test data
    const a = try std.testing.allocator.alloc(f32, len);
    defer std.testing.allocator.free(a);
    
    const b = try std.testing.allocator.alloc(f32, len);
    defer std.testing.allocator.free(b);
    
    const expected = try std.testing.allocator.alloc(f32, len);
    defer std.testing.allocator.free(expected);
    
    // Fill with test data
    for (0..len) |i| {
        a[i] = @floatFromInt(i + 1);
        b[i] = @floatFromInt((i + 1) * 2);
    }
    
    // Test different alpha/beta combinations
    const test_cases = [_]struct { alpha: f32, beta: f32 }{
        .{ .alpha = 0.5, .beta = 0.5 },
        .{ .alpha = 2.0, .beta = 0.0 },
        .{ .alpha = 0.0, .beta = 2.0 },
        .{ .alpha = 1.5, .beta = -0.5 },
    };
    
    for (test_cases) |tc| {
        // Compute expected result: alpha * A + beta * B
        for (0..len) |i| {
            expected[i] = tc.alpha * a[i] + tc.beta * b[i];
        }
        
        // Test with add operation (alpha and beta are used as coefficients)
        try testTensorOperation(f32, &context, command_buffer, &pipeline, a, b, expected, dims, .add, tc.alpha, tc.beta);
    }
}
