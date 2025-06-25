const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const Tensor4D = @import("tensor4d.zig").Tensor4D;

/// Parameters for gravity-well attention
pub const GravityAttentionParams = struct {
    /// Scaling factor for the gravitational constant (controls attention strength)
    g_scale: f32 = 1.0,
    /// Minimum distance to prevent division by zero
    min_distance: f32 = 1e-6,
    /// Temperature parameter for softmax
    temperature: f32 = 1.0,
    /// Whether to use softmax normalization
    use_softmax: bool = true,
};

/// Calculates the "mass" of a tensor (L2 norm by default)
pub fn calculateMass(tensor: *const Tensor4D) f32 {
    var sum: f32 = 0.0;
    
    // Simple L2 norm as mass
    for (tensor.data) |val| {
        sum += val * val;
    }
    
    return math.sqrt(sum);
}

/// Calculates the "distance" between two tensors (cosine distance)
pub fn calculateDistance(a: *const Tensor4D, b: *const Tensor4D) f32 {
    var dot: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;
    
    for (a.data, b.data) |a_val, b_val| {
        dot += a_val * b_val;
        norm_a += a_val * a_val;
        norm_b += b_val * b_val;
    }
    
    norm_a = math.sqrt(norm_a);
    norm_b = math.sqrt(norm_b);
    
    // Cosine distance = 1 - cosine_similarity
    return 1.0 - (dot / (norm_a * norm_b));
}

/// Gravity-well attention mechanism
/// Implements attention weights based on gravitational attraction
pub fn gravityWellAttention(
    allocator: Allocator,
    query: *const Tensor4D,
    keys: []const *const Tensor4D,
    values: []const *const Tensor4D,
    params: GravityAttentionParams,
) !*Tensor4D {
    std.debug.assert(keys.len == values.len);
    
    const num_heads = keys.len;
    
    // Calculate query mass (importance)
    const query_mass = calculateMass(query);
    
    // Calculate attention scores
    var scores = try allocator.alloc(f32, num_heads);
    defer allocator.free(scores);
    
    for (keys, 0..) |key, i| {
        const key_mass = calculateMass(key);
        const distance = @max(calculateDistance(query, key), params.min_distance);
        
        // Gravitational attraction: F = G * (m1 * m2) / r^2
        // Using negative exponent for attention (closer = stronger attention)
        scores[i] = (query_mass * key_mass) / (distance * distance);
    }
    
    // Apply temperature scaling
    if (params.temperature != 1.0) {
        for (scores) |*score| {
            score.* /= params.temperature;
        }
    }
    
    // Apply softmax if enabled
    if (params.use_softmax) {
        // Find max for numerical stability
        var max_score: f32 = -math.floatMax(f32);
        for (scores) |score| {
            max_score = @max(max_score, score);
        }
        
        // Compute exponentials and sum
        var sum_exp: f32 = 0.0;
        for (scores) |*score| {
            const exp_val = math.exp(score.* - max_score);
            score.* = exp_val;
            sum_exp += exp_val;
        }
        
        // Normalize
        if (sum_exp > 0.0) {
            for (scores) |*score| {
                score.* /= sum_exp;
            }
        }
    }
    
    // Weighted sum of values
    const output_shape = [_]usize{1} ++ values[0].shape[1..4].*;
    var output = try Tensor4D.init(allocator, output_shape);
    output.fill(0.0);
    
    for (scores, 0..) |score, i| {
        // Scale value by attention score and add to output
        for (output.data, values[i].data) |*out_val, val| {
            out_val.* += score * val;
        }
    }
    
    return output;
}

// Tests for attention mechanism
const testing = std.testing;

test "calculateMass" {
    const allocator = testing.allocator;
    
    // Create a simple 1x1x1x3 tensor
    var tensor = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 3});
    defer tensor.deinit();
    
    // Set values: [1, 2, 3]
    tensor.set(0, 0, 0, 0, 1.0);
    tensor.set(0, 0, 0, 1, 2.0);
    tensor.set(0, 0, 0, 2, 3.0);
    
    // sqrt(1² + 2² + 3²) = sqrt(14) ≈ 3.7417
    const mass = calculateMass(tensor);
    try testing.expectApproxEqAbs(@as(f32, 3.7417), mass, 1e-4);
}

test "gravityWellAttention basic" {
    const allocator = testing.allocator;
    
    // Create query tensor
    const query = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer query.deinit();
    query.fill(1.0);
    
    // Create keys and values (2 heads)
    const key1 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer key1.deinit();
    key1.fill(1.0);  // Same as query
    
    const key2 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer key2.deinit();
    key2.fill(-1.0);  // Opposite of query
    
    const value1 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer value1.deinit();
    value1.fill(1.0);
    
    const value2 = try Tensor4D.init(allocator, [4]usize{1, 1, 1, 4});
    defer value2.deinit();
    value2.fill(0.5);
    
    // Create slices of tensor pointers
    const key_ptrs = [_]*const Tensor4D{ key1, key2 };
    const value_ptrs = [_]*const Tensor4D{ value1, value2 };
    
    // Test attention
    const output = try gravityWellAttention(
        allocator,
        query,
        &key_ptrs,
        &value_ptrs,
        .{ .g_scale = 1.0, .temperature = 1.0 }
    );
    defer output.deinit();
    
    // Should give more weight to key1 (same as query)
    try testing.expectApproxEqAbs(@as(f32, 1.0), output.get(0, 0, 0, 0), 0.1);
}
