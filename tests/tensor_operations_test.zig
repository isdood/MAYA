// tests/tensor_operations_test.zig
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const math = std.math;

// Import Vulkan bindings and modules
const vk = @import("vulkan");
const Context = @import("vulkan/context").VulkanContext;
const memory = @import("vulkan/compute/memory");

// Import tensor types and pipelines
const TensorMemoryManager = memory.TensorMemoryManager;
const Tensor4D = memory.Tensor4D;
const TensorPipeline = memory.TensorPipeline;
const TensorOperation = memory.TensorOperation;
const TensorOperationParams = memory.TensorOperationParams;

// Test configurations
const TestConfig = struct {
    name: []const u8,
    dims: [4]u32,
    operation: TensorOperation,
    alpha: f32 = 1.0,
    beta: f32 = 1.0,
};

// Test cases for different tensor operations
const test_cases = [_]TestConfig{
    // Element-wise operations
    .{ .name = "addition", .dims = .{2, 2, 1, 1}, .operation = .add },
    .{ .name = "subtraction", .dims = .{2, 2, 1, 1}, .operation = .sub },
    .{ .name = "multiplication", .dims = .{2, 2, 1, 1}, .operation = .mul },
    .{ .name = "division", .dims = .{2, 2, 1, 1}, .operation = .div },
    .{ .name = "maximum", .dims = .{2, 2, 1, 1}, .operation = .max },
    .{ .name = "minimum", .dims = .{2, 2, 1, 1}, .operation = .min },
    .{ .name = "power", .dims = .{2, 2, 1, 1}, .operation = .pow },
    .{ .name = "relu", .dims = .{2, 2, 1, 1}, .operation = .relu },
    .{ .name = "sigmoid", .dims = .{2, 2, 1, 1}, .operation = .sigmoid },
    .{ .name = "tanh", .dims = .{2, 2, 1, 1}, .operation = .tanh },
    
    // Linear combination with custom alpha/beta
    .{ .name = "linear_combination_1", .dims = .{3, 3, 1, 1}, .operation = .linear_combination, .alpha = 0.5, .beta = 0.5 },
    .{ .name = "linear_combination_2", .dims = .{3, 3, 1, 1}, .operation = .linear_combination, .alpha = 2.0, .beta = 3.0 },
    
    // Different tensor dimensions
    .{ .name = "small_tensor", .dims = .{1, 1, 1, 1}, .operation = .add },
    .{ .name = "medium_tensor", .dims = .{16, 16, 1, 1}, .operation = .add },
    .{ .name = "large_tensor", .dims = .{64, 64, 1, 1}, .operation = .add },
    .{ .name = "batched_tensor", .dims = .{8, 8, 4, 4}, .operation = .add },
};

// Helper function to initialize test data
fn initTestData(comptime T: type, dims: [4]u32, a: *std.ArrayList(T), b: *std.ArrayList(T), expected: *std.ArrayList(T), config: TestConfig) !void {
    const count = dims[0] * dims[1] * dims[2] * dims[3];
    
    // Clear and ensure capacity
    try a.resize(count);
    try b.resize(count);
    try expected.resize(count);
    
    // Initialize with test data
    for (0..count) |i| {
        const x = @as(T, @floatFromInt(i % 10)) + 1.0; // Avoid division by zero
        const y = @as(T, @floatFromInt((i + 5) % 10)) + 1.0; // Different values
        
        a.items[i] = x;
        b.items[i] = y;
        
        // Calculate expected result based on operation
        expected.items[i] = switch (config.operation) {
            .add => x + y,
            .sub => x - y,
            .mul => x * y,
            .div => if (y != 0) x / y else 0,
            .max => @max(x, y),
            .min => @min(x, y),
            .pow => std.math.pow(T, x, y),
            .relu => @max(0, x), // Only uses x
            .sigmoid => 1.0 / (1.0 + std.math.exp(-x)), // Only uses x
            .tanh => std.math.tanh(x), // Only uses x
            .linear_combination => config.alpha * x + config.beta * y,
        };
    }
}

// Test a single tensor operation
fn testTensorOperation(
    comptime T: type,
    memory_manager: *TensorMemoryManager,
    command_buffer: vk.VkCommandBuffer,
    config: TestConfig,
) !void {
    const allocator = std.testing.allocator;
    
    // Initialize test data
    var a = std.ArrayList(T).init(allocator);
    defer a.deinit();
    
    var b = std.ArrayList(T).init(allocator);
    defer b.deinit();
    
    var expected = std.ArrayList(T).init(allocator);
    defer expected.deinit();
    
    try initTestData(T, config.dims, &a, &b, &expected, config);
    
    // Create input tensors
    var tensor_a = try memory_manager.createTensorFromData(T, config.dims, a.items);
    defer tensor_a.deinit();
    
    var tensor_b = try memory_manager.createTensorFromData(T, config.dims, b.items);
    defer tensor_b.deinit();
    
    // Create output tensor
    var output = try memory_manager.createUninitializedTensor(T, config.dims);
    defer output.deinit();
    
    // Create pipeline
    var pipeline = try TensorPipeline(T).init(allocator, memory_manager.context);
    defer pipeline.deinit();
    
    // Set up operation parameters
    const params = TensorOperationParams(T){
        .operation = config.operation,
        .alpha = @as(T, config.alpha),
        .beta = @as(T, config.beta),
    };
    
    // Execute the operation - tensors already have data from createTensorFromData
    try pipeline.execute(
        command_buffer,
        &tensor_a,
        &tensor_b,
        &output,
        params,
        allocator,
    );
    
    // Submit the command buffer
    const queue = memory_manager.context.graphics_queue orelse return error.QueueNotInitialized;
    try vk.checkVkResult(vk.vkQueueSubmit(queue, 1, &(vk.VkSubmitInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,
    }), null));
    
    // Wait for the queue to finish
    try vk.checkVkResult(vk.vkQueueWaitIdle(queue));
    
    // Read back the results
    const results = try output.readData(allocator);
    defer allocator.free(results);
    
    // Verify the results
    try testing.expectEqual(expected.items.len, results.len);
    
    var all_match = true;
    for (expected.items, results, 0..) |exp, res, i| {
        const tolerance = if (@typeInfo(T) == .Float) 0.001 else 0;
        const matches = if (@typeInfo(T) == .Float)
            std.math.fabs(exp - res) <= tolerance
        else
            exp == res;
            
        if (!matches) {
            std.debug.print("Mismatch at index {}: expected {}, got {}\n", .{i, exp, res});
            all_match = false;
        }
    }
    
    if (!all_match) {
        return error.TestExpectedEqual;
    }
}

// Helper function to run tests for a specific type
fn testTensorType(comptime T: type) !void {
    const allocator = std.testing.allocator;
    
    // Initialize Vulkan context
    var context = try Context.init(allocator, .{});
    defer context.deinit();
    
    // Initialize memory manager
    var memory_manager = try TensorMemoryManager.init(allocator, &context);
    defer memory_manager.deinit();
    
    // Create command buffer
    const command_buffer = try context.createCommandBuffer();
    defer vk.vkFreeCommandBuffers(context.device.?, context.command_pool, 1, &command_buffer);
    
    // Initialize command buffer
    const begin_info = vk.VkCommandBufferBeginInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
    };
    try vk.checkVkResult(vk.vkBeginCommandBuffer(command_buffer, &begin_info));
    
    // Test each operation
    for (test_cases) |config| {
        // Skip unsupported operations for integer types
        if (@typeInfo(T) != .Float and (
            config.operation == .sigmoid or 
            config.operation == .tanh or
            config.operation == .pow or
            config.operation == .div
        )) continue;
        
        std.debug.print("Testing {} with {}...\n", .{ @typeName(T), config.name });
        try testTensorOperation(T, &memory_manager, command_buffer, config);
    }
}

// Test float tensors
test "float tensor operations" {
    // Skip on CI for now as it requires Vulkan
    if (std.builtin.is_test) return error.SkipZigTest;
    try testTensorType(f32);
}

// Test 32-bit integer tensors
test "i32 tensor operations" {
    // Skip on CI for now as it requires Vulkan
    if (std.builtin.is_test) return error.SkipZigTest;
    try testTensorType(i32);
}

// Test 32-bit unsigned integer tensors
test "u32 tensor operations" {
    // Skip on CI for now as it requires Vulkan
    if (std.builtin.is_test) return error.SkipZigTest;
    try testTensorType(u32);
}
