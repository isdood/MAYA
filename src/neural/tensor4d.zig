//! 4D Tensor implementation for HYPERCUBE

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 4D Tensor structure
pub const Tensor4D = struct {
    allocator: Allocator,
    shape: [4]usize,
    data: []f32,
    
    /// Initialize a new 4D tensor
    pub fn init(allocator: Allocator, shape: [4]usize) !*Tensor4D {
        const size = shape[0] * shape[1] * shape[2] * shape[3];
        const data = try allocator.alloc(f32, size);
        
        const tensor = try allocator.create(Tensor4D);
        tensor.* = .{
            .allocator = allocator,
            .shape = shape,
            .data = data,
        };
        
        return tensor;
    }
    
    /// Deinitialize the tensor
    pub fn deinit(self: *Tensor4D) void {
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }
    
    /// Duplicate the tensor
    pub fn dupe(self: *const Tensor4D, allocator: Allocator) !*Tensor4D {
        const new_tensor = try Tensor4D.init(allocator, self.shape);
        @memcpy(new_tensor.data, self.data);
        return new_tensor;
    }
    
    /// Get value at the specified 4D index
    pub fn get(self: *const Tensor4D, b: usize, c: usize, h: usize, w: usize) f32 {
        const idx = ((b * self.shape[1] + c) * self.shape[2] + h) * self.shape[3] + w;
        return self.data[idx];
    }
    
    /// Set value at the specified 4D index
    pub fn set(self: *Tensor4D, b: usize, c: usize, h: usize, w: usize, value: f32) void {
        const idx = ((b * self.shape[1] + c) * self.shape[2] + h) * self.shape[3] + w;
        self.data[idx] = value;
    }
};

// Tests
const testing = std.testing;

test "Tensor4D init and deinit" {
    const shape = [4]usize{1, 1, 2, 2};
    const tensor = try Tensor4D.init(testing.allocator, shape);
    defer tensor.deinit();
    
    try testing.expectEqual(shape, tensor.shape);
    try testing.expectEqual(@as(usize, 4), tensor.data.len);
}

test "Tensor4D get and set" {
    const shape = [4]usize{1, 1, 2, 2};
    const tensor = try Tensor4D.init(testing.allocator, shape);
    defer tensor.deinit();
    
    tensor.set(0, 0, 0, 0, 1.0);
    tensor.set(0, 0, 0, 1, 2.0);
    tensor.set(0, 0, 1, 0, 3.0);
    tensor.set(0, 0, 1, 1, 4.0);
    
    try testing.expectEqual(@as(f32, 1.0), tensor.get(0, 0, 0, 0));
    try testing.expectEqual(@as(f32, 2.0), tensor.get(0, 0, 0, 1));
    try testing.expectEqual(@as(f32, 3.0), tensor.get(0, 0, 1, 0));
    try testing.expectEqual(@as(f32, 4.0), tensor.get(0, 0, 1, 1));
}

test "Tensor4D dupe" {
    const shape = [4]usize{1, 1, 2, 2};
    const tensor = try Tensor4D.init(testing.allocator, shape);
    defer tensor.deinit();
    
    tensor.set(0, 0, 0, 0, 1.0);
    
    const tensor_copy = try tensor.dupe(testing.allocator);
    defer tensor_copy.deinit();
    
    try testing.expectEqual(tensor.get(0, 0, 0, 0), tensor_copy.get(0, 0, 0, 0));
}
