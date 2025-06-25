const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// A 4-dimensional tensor for HYPERCUBE operations
pub const Tensor4D = struct {
    data: []f32,
    shape: [4]usize, // [batch, depth, height, width]
    allocator: Allocator,

    /// Creates a new 4D tensor with the given shape
    pub fn init(allocator: Allocator, shape: [4]usize) !*@This() {
        const size = shape[0] * shape[1] * shape[2] * shape[3];
        const data = try allocator.alloc(f32, size);
        
        const self = try allocator.create(@This());
        self.* = .{
            .data = data,
            .shape = shape,
            .allocator = allocator,
        };
        return self;
    }

    /// Frees the tensor's memory
    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }

    /// Gets the value at the specified 4D index
    pub fn get(self: *const @This(), b: usize, d: usize, h: usize, w: usize) f32 {
        const idx = self.getIndex(b, d, h, w);
        return self.data[idx];
    }

    /// Sets the value at the specified 4D index
    pub fn set(self: *@This(), b: usize, d: usize, h: usize, w: usize, value: f32) void {
        const idx = self.getIndex(b, d, h, w);
        self.data[idx] = value;
    }

    /// Fills the tensor with the given value
    pub fn fill(self: *@This(), value: f32) void {
        for (self.data) |*v| v.* = value;
    }

    /// Fills the tensor with random values in the range [min, max]
    pub fn randomFill(self: *@This(), min: f32, max: f32) !void {
        const seed = @as(u64, @intCast(std.time.milliTimestamp()));
        var rng = std.rand.DefaultPrng.init(seed);
        const range = max - min;
        
        for (self.data) |*v| {
            v.* = min + @as(f32, @floatFromInt(rng.random().int(u32))) / 
                  @as(f32, @floatFromInt(std.math.maxInt(u32))) * range;
        }
    }

    // Internal helper to compute the 1D index from 4D coordinates
    fn getIndex(self: *const @This(), b: usize, d: usize, h: usize, w: usize) usize {
        assert(b < self.shape[0]);
        assert(d < self.shape[1]);
        assert(h < self.shape[2]);
        assert(w < self.shape[3]);
        
        return ((b * self.shape[1] + d) * self.shape[2] + h) * self.shape[3] + w;
    }

    /// Performs element-wise addition with another tensor
    pub fn add(self: *@This(), other: *const @This()) !void {
        if (!std.mem.eql(usize, &self.shape, &other.shape)) {
            return error.ShapeMismatch;
        }
        
        for (self.data, other.data) |*a, b| {
            a.* += b;
        }
    }

    /// Performs element-wise multiplication with another tensor
    pub fn mul(self: *@This(), other: *const @This()) !void {
        if (!std.mem.eql(usize, &self.shape, &other.shape)) {
            return error.ShapeMismatch;
        }
        
        for (self.data, other.data) |*a, b| {
            a.* *= b;
        }
    }

    /// Applies the ReLU activation function
    pub fn relu(self: *@This()) void {
        for (self.data) |*v| {
            v.* = @max(0, v.*);
        }
    }
};

// Tests for Tensor4D
const testing = std.testing;

test "Tensor4D initialization and basic operations" {
    const allocator = testing.allocator;
    
    // Create a small 4D tensor
    const shape = [4]usize{ 2, 2, 2, 2 }; // 2x2x2x2 tensor
    var tensor = try Tensor4D.init(allocator, shape);
    defer tensor.deinit();
    
    // Test setting and getting values
    tensor.set(0, 0, 0, 0, 1.0);
    try testing.expectEqual(@as(f32, 1.0), tensor.get(0, 0, 0, 0));
    
    // Test fill operation
    tensor.fill(0.5);
    try testing.expectEqual(@as(f32, 0.5), tensor.get(1, 1, 1, 1));
    
    // Test element-wise addition
    var tensor2 = try Tensor4D.init(allocator, shape);
    defer tensor2.deinit();
    tensor2.fill(0.5);
    
    try tensor.add(tensor2);
    try testing.expectEqual(@as(f32, 1.0), tensor.get(0, 0, 0, 0));
}

test "Tensor4D random fill" {
    const allocator = testing.allocator;
    const shape = [4]usize{ 1, 1, 1, 10 }; // Simple 1D tensor for testing
    var tensor = try Tensor4D.init(allocator, shape);
    defer tensor.deinit();
    
    // Fill with random values between 0 and 1
    try tensor.randomFill(0, 1);
    
    // Verify all values are within the expected range
    for (tensor.data) |value| {
        try testing.expect(value >= 0 and value <= 1);
    }
}
