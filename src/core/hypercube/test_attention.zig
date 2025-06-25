const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Tensor4D = @import("tensor4d.zig").Tensor4D;
const attention = @import("attention.zig");

test "gravity well attention basic" {
    // This test verifies that the attention mechanism correctly weights
    // values based on the similarity between query and keys
    const allocator = testing.allocator;
    
    // Create a simple query tensor (batch=1, seq_len=1, embed_dim=4)
    var query = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer query.deinit();
    
    // Set query values to [1, 1, 1, 1]
    query.fill(1.0);
    
    // Create two key-value pairs
    var key1 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer key1.deinit();
    key1.fill(1.0);  // Similar to query
    
    var key2 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer key2.deinit();
    key2.fill(-1.0);  // Opposite of query
    
    var value1 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer value1.deinit();
    value1.fill(1.0);  // High value for similar key
    
    var value2 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer value2.deinit();
    value2.fill(0.1);  // Low value for dissimilar key
    
    const keys = [_]*const Tensor4D{ &key1, &key2 };
    const values = [_]*const Tensor4D{ &value1, &value2 };
    
    // Test attention with default parameters
    const output = try attention.gravityWellAttention(
        allocator,
        &query,
        &keys,
        &values,
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
    var query = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer query.deinit();
    query.fill(1.0);
    
    // Create two key-value pairs with small differences
    var key1 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer key1.deinit();
    key1.data[0] = 0.9; key1.data[1] = 1.0; key1.data[2] = 1.0; key1.data[3] = 1.0;
    
    var key2 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer key2.deinit();
    key2.data[0] = 1.1; key2.data[1] = 1.0; key2.data[2] = 1.0; key2.data[3] = 1.0;
    
    var value1 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer value1.deinit();
    value1.fill(1.0);
    
    var value2 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer value2.deinit();
    value2.fill(0.5);
    
    const keys = [_]*const Tensor4D{ &key1, &key2 };
    const values = [_]*const Tensor4D{ &value1, &value2 };
    
    // Test with high temperature (more uniform distribution)
    const output_high_temp = try attention.gravityWellAttention(
        allocator,
        &query,
        &keys,
        &values,
        .{ .temperature = 10.0 }
    );
    defer output_high_temp.deinit();
    
    // Test with low temperature (sharper distribution)
    const output_low_temp = try attention.gravityWellAttention(
        allocator,
        &query,
        &keys,
        &values,
        .{ .temperature = 0.1 }
    );
    defer output_low_temp.deinit();
    
    // High temp output should be more average of values
    const high_temp_val = output_high_temp.get(0, 0, 0, 0);
    try testing.expect(high_temp_val > 0.6 and high_temp_val < 0.9);
    
    // Low temp output should be closer to one of the values
    const low_temp_val = output_low_temp.get(0, 0, 0, 0);
    try testing.expect(low_temp_val > 0.9 or low_temp_val < 0.6);
}
