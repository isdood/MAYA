// examples/test_tensor_ops.zig
const std = @import("std");
const vk = @import("vk");
const Context = @import("context").VulkanContext;
const tensor = @import("vulkan/compute/tensor");
const tensor_ops = @import("compute/tensor_operations");

// Import the tensor types
const Tensor4D = tensor.Tensor4D;
const Tensor4DF32 = tensor.Tensor4D(f32);
const TensorOperation = tensor_ops.TensorOperation;

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Initializing Vulkan context...\n", .{});
    
    // Initialize Vulkan context
    var context = try Context.init(allocator, .{});
    defer context.deinit();
    
    std.debug.print("Vulkan context initialized successfully!\n", .{});
    
    // Initialize tensor operations
    std.debug.print("Initializing tensor operations...\n", .{});
    tensor_ops.initThreadLocal(allocator);
    
    // Test tensor operations
    try testTensorOperations(allocator, &context);
    
    std.debug.print("All tests passed!\n", .{});
}

fn testTensorOperations(allocator: std.mem.Allocator, context: *Context) !void {
    std.debug.print("Testing tensor operations...\n", .{});
    
    // Create input tensors
    const dims = [4]u32{2, 2, 1, 1}; // 2x2x1x1 tensor
    
    // Initialize with some data
    const data_a = [_]f32{1.0, 2.0, 3.0, 4.0};
    const data_b = [_]f32{5.0, 6.0, 7.0, 8.0};
    
    // Create tensors
    var tensor_a = try Tensor4DF32.initWithData(context, dims, &data_a, allocator);
    defer tensor_a.deinit();
    
    var tensor_b = try Tensor4DF32.initWithData(context, dims, &data_b, allocator);
    defer tensor_b.deinit();
    
    // Test reading/writing data
    std.debug.print("Testing tensor read/write...\n", .{});
    const read_back = try tensor_a.readData(allocator);
    defer allocator.free(read_back);
    
    for (data_a, 0..) |expected, i| {
        std.debug.assert(read_back[i] == expected);
    }
    std.debug.print("Tensor read/write test passed!\n", .{});
    
    // Test tensor operations
    std.debug.print("Testing tensor operations...\n", .{});
    
    // Create output tensor
    var tensor_c = try Tensor4DF32.initUninitialized(context, dims, allocator);
    defer tensor_c.deinit();
    
    // Create tensor pipeline
    var pipeline = try tensor_ops.TensorPipeline(f32).init(context, .add);
    
    // Perform addition
    try pipeline.execute(
        &tensor_a,
        &tensor_b,
        &tensor_c,
        allocator
    );
    
    // Verify results
    const result = try tensor_c.readData(allocator);
    defer allocator.free(result);
    
    std.debug.print("Addition results:\n", .{});
    for (data_a, 0..) |a, i| {
        const b = data_b[i];
        const expected = a + b;
        std.debug.print("{} + {} = {} (expected {})\n", .{a, b, result[i], expected});
        std.debug.assert(result[i] == expected);
    }
    
    std.debug.print("All tensor operations tests passed!\n", .{});
}
