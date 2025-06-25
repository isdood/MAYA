const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Tensor4D = @import("tensor4d.zig").Tensor4D;
const attention = @import("attention.zig");

// Helper function to create a test tensor with the given shape and fill value
fn createTestTensor(allocator: Allocator, shape: [4]usize, value: f32) !*Tensor4D {
    var tensor = try Tensor4D.init(allocator, shape);
    tensor.fill(value);
    return tensor;
}

test "gravity well attention basic" {
    // This test verifies that the attention mechanism correctly weights
    // values based on the similarity between query and keys
    const allocator = testing.allocator;
    
    // Create a simple query tensor (batch=1, seq_len=1, embed_dim=4)
    const query = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 1.0);
    defer query.deinit();
    
    // Create two key-value pairs
    const key1 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 1.0);  // Similar to query
    defer key1.deinit();
    
    const key2 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, -1.0);  // Opposite of query
    defer key2.deinit();
    
    const value1 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 1.0);  // High value for similar key
    defer value1.deinit();
    
    const value2 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 0.1);  // Low value for dissimilar key
    defer value2.deinit();
    
    // Create slices of tensor pointers
    const key_ptrs = [_]*const Tensor4D{ key1, key2 };
    const value_ptrs = [_]*const Tensor4D{ value1, value2 };
    
    // Test attention with default parameters
    const output = try attention.gravityWellAttention(
        allocator,
        query,
        &key_ptrs,
        &value_ptrs,
        .{ .g_scale = 1.0, .temperature = 1.0 }
    );
    defer output.deinit();
    
    // The output should be closer to value1 since key1 is more similar to query
    try testing.expectApproxEqAbs(@as(f32, 1.0), output.get(0, 0, 0, 0), 0.1);
}

test "gravity well attention with temperature" {
    // This test verifies that the temperature parameter correctly
    // controls the sharpness of the attention distribution
    const allocator = testing.allocator;
    
    // Create a simple query tensor
    const query = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 1.0);
    defer query.deinit();
    
    // Create two key-value pairs with small differences
    const key1 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 1.0);
    defer key1.deinit();
    key1.data[0] = 0.9;  // Slightly different from query
    
    const key2 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 1.0);
    defer key2.deinit();
    key2.data[0] = 1.1;  // Slightly different from query in the other direction
    
    const value1 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 1.0);
    defer value1.deinit();
    
    const value2 = try createTestTensor(allocator, [4]usize{1, 1, 1, 4}, 0.5);
    defer value2.deinit();
    
    // Create slices of tensor pointers
    const key_ptrs = [_]*const Tensor4D{ key1, key2 };
    const value_ptrs = [_]*const Tensor4D{ value1, value2 };
    
    // Test with high temperature (more uniform distribution)
    const output_high_temp = try attention.gravityWellAttention(
        allocator,
        query,
        &key_ptrs,
        &value_ptrs,
        .{ .temperature = 10.0 }
    );
    defer output_high_temp.deinit();
    
    // Test with low temperature (sharper distribution)
    const output_low_temp = try attention.gravityWellAttention(
        allocator,
        query,
        &key_ptrs,
        &value_ptrs,
        .{ .temperature = 0.1 }
    );
    defer output_low_temp.deinit();
    
    // High temp output should be more average of values (between 0.5 and 1.0)
    const high_temp_val = output_high_temp.get(0, 0, 0, 0);
    try testing.expect(high_temp_val >= 0.5 and high_temp_val <= 1.0);
    
    // Low temp output should be closer to one of the values (either > 0.9 or < 0.6)
    const low_temp_val = output_low_temp.get(0, 0, 0, 0);
    try testing.expect(low_temp_val > 0.9 or low_temp_val < 0.6);
}
