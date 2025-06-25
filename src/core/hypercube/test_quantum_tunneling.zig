const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Tensor4D = @import("tensor4d.zig").Tensor4D;
const quantum_tunneling = @import("quantum_tunneling.zig");

// Helper function to create a test tensor with sequential values
fn createSequentialTensor(allocator: Allocator, shape: [4]usize) !*Tensor4D {
    var tensor = try Tensor4D.init(allocator, shape);
    var index: usize = 0;
    
    for (0..shape[0]) |b| {
        for (0..shape[1]) |d| {
            for (0..shape[2]) |h| {
                for (0..shape[3]) |w| {
                    tensor.set(b, d, h, w, @as(f32, @floatFromInt(index)));
                    index += 1;
                }
            }
        }
    }
    
    return tensor;
}

test "quantum tunneling preserves shape" {
    const allocator = testing.allocator;
    const shape = [4]usize{1, 2, 3, 4};
    
    // Create input tensor
    const input = try createSequentialTensor(allocator, shape);
    defer input.deinit();
    
    // Apply quantum tunneling
    const output = try quantum_tunneling.quantumTunnelingAccess(
        allocator,
        input,
        .{ .base_probability = 0.5 }
    );
    defer output.deinit();
    
    // Check output shape matches input shape
    try testing.expectEqual(shape[0], output.shape[0]);
    try testing.expectEqual(shape[1], output.shape[1]);
    try testing.expectEqual(shape[2], output.shape[2]);
    try testing.expectEqual(shape[3], output.shape[3]);
}

test "quantum tunneling with zero probability returns copy" {
    const allocator = testing.allocator;
    const shape = [4]usize{1, 1, 3, 3};
    
    // Create input tensor
    const input = try createSequentialTensor(allocator, shape);
    defer input.deinit();
    
    // Apply quantum tunneling with zero probability
    const output = try quantum_tunneling.quantumTunnelingAccess(
        allocator,
        input,
        .{ .base_probability = 0.0 }
    );
    defer output.deinit();
    
    // Verify output is identical to input
    for (0..shape[0]) |b| {
        for (0..shape[1]) |d| {
            for (0..shape[2]) |h| {
                for (0..shape[3]) |w| {
                    try testing.expectEqual(
                        input.get(b, d, h, w),
                        output.get(b, d, h, w)
                    );
                }
            }
        }
    }
}

test "quantum tunneling with high probability causes changes" {
    const allocator = testing.allocator;
    const shape = [4]usize{1, 1, 4, 4};
    
    // Create input tensor
    const input = try createSequentialTensor(allocator, shape);
    defer input.deinit();
    
    // Apply quantum tunneling with high probability
    const output = try quantum_tunneling.quantumTunnelingAccess(
        allocator,
        input,
        .{ 
            .base_probability = 0.9,
            .temperature = 0.5,  // More deterministic for testing
            .max_distance_factor = 2.0
        }
    );
    defer output.deinit();
    
    // Count number of changed values
    var changed_count: usize = 0;
    for (0..shape[0]) |b| {
        for (0..shape[1]) |d| {
            for (0..shape[2]) |h| {
                for (0..shape[3]) |w| {
                    if (input.get(b, d, h, w) != output.get(b, d, h, w)) {
                        changed_count += 1;
                    }
                }
            }
        }
    }
    
    // With high probability, we expect some changes
    // Note: This test could theoretically fail occasionally due to randomness
    try testing.expect(changed_count > 0);
}


