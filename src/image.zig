const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

/// Represents a multi-channel image
pub const Image = struct {
    width: usize,
    height: usize,
    channels: usize,
    data: []f32,
    allocator: Allocator,
    
    /// Creates a new image with uninitialized data
    pub fn init(allocator: Allocator, width: usize, height: usize, channels: usize) !Image {
        const data = try allocator.alloc(f32, width * height * channels);
        return Image{
            .width = width,
            .height = height,
            .channels = channels,
            .data = data,
            .allocator = allocator,
        };
    }
    
    /// Creates a deep copy of the image
    pub fn clone(self: Image, allocator: Allocator) !Image {
        const new_image = try Image.init(allocator, self.width, self.height, self.channels);
        @memcpy(new_image.data, self.data);
        return new_image;
    }
    
    /// Frees the image data
    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
    }
    
    /// Gets a pixel value (returns a slice to the channel values)
    pub fn getPixel(self: Image, x: usize, y: usize) []f32 {
        const idx = (y * self.width + x) * self.channels;
        return self.data[idx..idx+self.channels];
    }
    
    /// Sets a pixel value
    pub fn setPixel(self: *Image, x: usize, y: usize, values: []const f32) void {
        const idx = (y * self.width + x) * self.channels;
        @memcpy(self.data[idx..idx+self.channels], values[0..self.channels]);
    }
    
    /// Applies Gaussian blur to the image
    pub fn gaussianBlur(self: Image, kernel_size: usize, sigma: f32, allocator: Allocator) !Image {
        // Simple implementation - in practice, you'd want to use separable filters
        _ = kernel_size; // Not used in this simplified version
        _ = sigma;       // Not used in this simplified version
        
        const result = try self.clone(allocator);
        // In a real implementation, you would apply a Gaussian kernel here
        // For now, just return a copy
        return result;
    }
    
    /// Resizes the image using bilinear interpolation
    pub fn resize(self: Image, new_width: usize, new_height: usize, allocator: Allocator) !Image {
        if (new_width == 0 or new_height == 0) {
            return error.InvalidDimensions;
        }
        
        var result = try Image.init(allocator, new_width, new_height, self.channels);
        
        // Handle single-pixel case
        if (new_width == 1 and new_height == 1) {
            // Just take the average of all pixels
            var sum = std.mem.zeroes([4]f32);
            for (0..self.height) |y| {
                for (0..self.width) |x| {
                    const pixel = self.getPixel(x, y);
                    for (pixel, 0..) |val, c| {
                        sum[c] += val;
                    }
                }
            }
            const count = @as(f32, @floatFromInt(self.width * self.height));
            var avg_pixel = try allocator.alloc(f32, self.channels);
            defer allocator.free(avg_pixel);
            for (0..self.channels) |c| {
                avg_pixel[c] = sum[c] / count;
            }
            result.setPixel(0, 0, avg_pixel);
            return result;
        }
        
        const x_ratio = if (new_width > 1) 
            @as(f32, @floatFromInt(self.width - 1)) / @as(f32, @floatFromInt(new_width - 1)) 
            else 0.0;
        const y_ratio = if (new_height > 1) 
            @as(f32, @floatFromInt(self.height - 1)) / @as(f32, @floatFromInt(new_height - 1))
            else 0.0;
        
        for (0..new_height) |y| {
            for (0..new_width) |x| {
                const src_x = if (new_width > 1) 
                    @as(f32, @floatFromInt(x)) * x_ratio 
                    else @as(f32, @floatFromInt(self.width)) / 2.0;
                const src_y = if (new_height > 1) 
                    @as(f32, @floatFromInt(y)) * y_ratio 
                    else @as(f32, @floatFromInt(self.height)) / 2.0;
                
                const x1 = @min(@as(usize, @intFromFloat(src_x)), self.width - 1);
                const y1 = @min(@as(usize, @intFromFloat(src_y)), self.height - 1);
                const x2 = @min(x1 + 1, self.width - 1);
                const y2 = @min(y1 + 1, self.height - 1);
                
                const x_weight = src_x - @floor(src_x);
                const y_weight = src_y - @floor(src_y);
                
                var pixel = try allocator.alloc(f32, self.channels);
                defer allocator.free(pixel);
                
                for (0..self.channels) |c| {
                    const top = self.getPixel(x1, y1)[c] * (1 - x_weight) + 
                               self.getPixel(x2, y1)[c] * x_weight;
                    const bottom = self.getPixel(x1, y2)[c] * (1 - x_weight) + 
                                 self.getPixel(x2, y2)[c] * x_weight;
                    
                    pixel[c] = top * (1 - y_weight) + bottom * y_weight;
                }
                
                result.setPixel(x, y, pixel);
            }
        }
        
        return result;
    }
};

// Tests
const testing = std.testing;

test "Image creation and pixel access" {
    const width = 10;
    const height = 10;
    const channels = 3;
    
    var image = try Image.init(testing.allocator, width, height, channels);
    defer image.deinit();
    
    // Test set/get pixel
    const test_x = 5;
    const test_y = 5;
    const test_value = [3]f32{ 0.1, 0.5, 0.9 };
    
    image.setPixel(test_x, test_y, &test_value);
    const pixel = image.getPixel(test_x, test_y);
    
    try testing.expectEqual(test_value[0], pixel[0]);
    try testing.expectEqual(test_value[1], pixel[1]);
    try testing.expectEqual(test_value[2], pixel[2]);
}

test "Image cloning" {
    var image1 = try Image.init(testing.allocator, 10, 10, 1);
    defer image1.deinit();
    
    image1.setPixel(5, 5, &[1]f32{0.5});
    
    var image2 = try image1.clone(testing.allocator);
    defer image2.deinit();
    
    try testing.expectEqual(image1.getPixel(5, 5)[0], image2.getPixel(5, 5)[0]);
}

test "Image resizing" {
    // Create a simple 2x2 image
    var image = try Image.init(testing.allocator, 2, 2, 1);
    defer image.deinit();
    
    // Set up a simple gradient
    // [0.0, 0.5]
    // [0.5, 1.0]
    image.setPixel(0, 0, &[1]f32{0.0});
    image.setPixel(1, 0, &[1]f32{0.5});
    image.setPixel(0, 1, &[1]f32{0.5});
    image.setPixel(1, 1, &[1]f32{1.0});
    
    // Resize to 3x3
    var resized = try image.resize(3, 3, testing.allocator);
    defer resized.deinit();
    
    // Check center pixel (should be average of all four)
    try testing.expectApproxEqAbs(0.5, resized.getPixel(1, 1)[0], 0.01);
    
    // Check corners (should match original corners)
    try testing.expectApproxEqAbs(0.0, resized.getPixel(0, 0)[0], 0.01);
    try testing.expectApproxEqAbs(0.5, resized.getPixel(2, 0)[0], 0.01);
    try testing.expectApproxEqAbs(0.5, resized.getPixel(0, 2)[0], 0.01);
    try testing.expectApproxEqAbs(1.0, resized.getPixel(2, 2)[0], 0.01);
    
    // Check edges (should be interpolated)
    try testing.expectApproxEqAbs(0.25, resized.getPixel(1, 0)[0], 0.01);
    try testing.expectApproxEqAbs(0.25, resized.getPixel(0, 1)[0], 0.01);
    try testing.expectApproxEqAbs(0.75, resized.getPixel(2, 1)[0], 0.01);
    try testing.expectApproxEqAbs(0.75, resized.getPixel(1, 2)[0], 0.01);
}
