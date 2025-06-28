const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

// Simple image structure for testing
const Image = struct {
    width: usize,
    height: usize,
    data: []f32,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, width: usize, height: usize) !Image {
        const data = try allocator.alloc(f32, width * height);
        return .{
            .width = width,
            .height = height,
            .data = data,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
    }
    
    pub fn getPixel(self: Image, x: usize, y: usize) f32 {
        return self.data[y * self.width + x];
    }
    
    pub fn setPixel(self: *Image, x: usize, y: usize, value: f32) void {
        self.data[y * self.width + x] = value;
    }
};

/// Multi-scale pattern matching implementation
pub const MultiScaleMatcher = struct {
    allocator: Allocator,
    min_scale: f32 = 0.5,
    max_scale: f32 = 2.0,
    scale_steps: u8 = 4,
    
    pub fn init(allocator: Allocator) MultiScaleMatcher {
        return .{
            .allocator = allocator,
        };
    }
    
    /// Creates a Gaussian pyramid for multi-scale analysis
    pub fn createGaussianPyramid(self: *@This(), 
                               base_image: Image, 
                               allocator: ?Allocator) ![]Image {
        const alloc = allocator orelse self.allocator;
        var pyramid = try alloc.alloc(Image, self.scale_steps);
        errdefer alloc.free(pyramid);
        
        // First level is a copy of the original image
        pyramid[0] = try Image.init(alloc, base_image.width, base_image.height);
        @memcpy(pyramid[0].data, base_image.data);
        
        // Generate downscaled versions
        for (1..self.scale_steps) |i| {
            const scale = math.lerp(self.min_scale, self.max_scale, 
                                 @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(self.scale_steps - 1)));
            pyramid[i] = try self.downscaleGaussian(pyramid[i-1], scale, alloc);
        }
        
        return pyramid;
    }
    
    /// Downscales an image using a simple box filter
    fn downscaleGaussian(self: *@This(), 
                        image: Image, 
                        scale: f32, 
                        allocator: Allocator) !Image {
        _ = self; // Unused
        
        // Calculate new dimensions
        const new_width = @max(1, @as(usize, @intFromFloat(@as(f32, @floatFromInt(image.width)) * scale)));
        const new_height = @max(1, @as(usize, @intFromFloat(@as(f32, @floatFromInt(image.height)) * scale)));
        
        // Simple box filter downscaling
        var result = try Image.init(allocator, new_width, new_height);
        
        const x_ratio = @as(f32, @floatFromInt(image.width)) / @as(f32, @floatFromInt(new_width));
        const y_ratio = @as(f32, @floatFromInt(image.height)) / @as(f32, @floatFromInt(new_height));
        
        for (0..new_height) |y| {
            for (0..new_width) |x| {
                // Calculate the average of the source pixels that map to this pixel
                const src_y_start = @as(usize, @intFromFloat(@as(f32, @floatFromInt(y)) * y_ratio));
                const src_y_end = @min(@as(usize, @intFromFloat(@as(f32, @floatFromInt(y + 1)) * y_ratio)), image.height);
                const src_x_start = @as(usize, @intFromFloat(@as(f32, @floatFromInt(x)) * x_ratio));
                const src_x_end = @min(@as(usize, @intFromFloat(@as(f32, @floatFromInt(x + 1)) * x_ratio)), image.width);
                
                var sum: f32 = 0;
                var count: usize = 0;
                
                for (src_y_start..src_y_end) |src_y| {
                    for (src_x_start..src_x_end) |src_x| {
                        sum += image.getPixel(src_x, src_y);
                        count += 1;
                    }
                }
                
                result.setPixel(x, y, if (count > 0) sum / @as(f32, @floatFromInt(count)) else 0);
            }
        }
        
        return result;
    }
    
    /// Finds the best match for a pattern across scales
    pub fn findBestMatch(self: *@This(), 
                       image: Image, 
                       pattern: Image,
                       allocator: ?Allocator) !struct { x: usize, y: usize, scale: f32, score: f32 } {
        const alloc = allocator orelse self.allocator;
        
        // Create pyramids for both images
        const image_pyramid = try self.createGaussianPyramid(image, alloc);
        defer {
            for (image_pyramid) |img| img.deinit();
            alloc.free(image_pyramid);
        }
        
        const pattern_pyramid = try self.createGaussianPyramid(pattern, alloc);
        defer {
            for (pattern_pyramid) |img| img.deinit();
            alloc.free(pattern_pyramid);
        }
        
        var best_match = struct { x: usize, y: usize, scale: f32, score: f32 }{
            .x = 0,
            .y = 0,
            .scale = 1.0,
            .score = -math.floatMax(f32),
        };
        
        // Search across all scales
        for (image_pyramid, 0..) |img, img_scale| {
            for (pattern_pyramid) |pat| {
                if (pat.width > img.width or pat.height > img.height) continue;
                
                const result = try self.matchPattern(img, pat, alloc);
                
                const current_scale = math.lerp(self.min_scale, self.max_scale, 
                                              @as(f32, @floatFromInt(img_scale)) / @as(f32, @floatFromInt(self.scale_steps - 1)));
                
                if (result.score > best_match.score) {
                    best_match = .{
                        .x = result.x,
                        .y = result.y,
                        .scale = current_scale,
                        .score = result.score,
                    };
                }
            }
        }
        
        return best_match;
    }
    
    /// Matches a pattern at a specific scale
    fn matchPattern(self: *@This(), 
                   image: Image, 
                   pattern: Image,
                   allocator: Allocator) !struct { x: usize, y: usize, score: f32 } {
        
        if (pattern.width > image.width or pattern.height > image.height) {
            return error.PatternLargerThanImage;
        }
        
        var best_score: f32 = -math.floatMax(f32);
        var best_x: usize = 0;
        var best_y: usize = 0;
        
        // Simple sliding window matching (can be optimized with FFT)
        for (0..image.width - pattern.width) |x| {
            for (0..image.height - pattern.height) |y| {
                const score = try self.computeSimilarity(image, pattern, x, y, allocator);
                
                if (score > best_score) {
                    best_score = score;
                    best_x = x;
                    best_y = y;
                }
            }
        }
        
        return .{
            .x = best_x,
            .y = best_y,
            .score = best_score,
        };
    }
    
    /// Computes similarity between image region and pattern
    fn computeSimilarity(
        _: *@This(),
        image: Image,
        pattern: Image,
        x: usize,
        y: usize,
        _: Allocator
    ) !f32 {
        
        var sum: f32 = 0.0;
        var norm_image: f32 = 0.0;
        var norm_pattern: f32 = 0.0;
        
        // Simple normalized cross-correlation
        for (0..pattern.height) |py| {
            for (0..pattern.width) |px| {
                const img_val = image.getPixel(x + px, y + py);
                const pat_val = pattern.getPixel(px, py);
                
                sum += img_val * pat_val;
                norm_image += img_val * img_val;
                norm_pattern += pat_val * pat_val;
            }
        }
        
        // Avoid division by zero
        if (norm_image == 0 or norm_pattern == 0) return 0.0;
        
        // Normalized cross-correlation score
        return @abs(sum) / (@sqrt(norm_image) * @sqrt(norm_pattern));
    }
    
    pub fn deinit(self: *@This()) void {
        // No resources to free in the base implementation
        _ = self;
    }
};

// Rotation-invariant features
pub const RotationInvariantFeatures = struct {
    allocator: Allocator,
    num_orientations: u8 = 8,
    
    pub fn init(allocator: Allocator) RotationInvariantFeatures {
        return .{
            .allocator = allocator,
        };
    }
    
    /// Computes gradient orientation histogram
    pub fn computeOrientationHistogram(self: *@This(), 
                                     image: Image,
                                     x: usize,
                                     y: usize,
                                     radius: usize,
                                     allocator: ?Allocator) ![]f32 {
        const alloc = allocator orelse self.allocator;
        var histogram = try alloc.alloc(f32, self.num_orientations);
        @memset(histogram, 0);
        
        // Simple gradient computation
        for (1..image.height-1) |j| {
            for (1..image.width-1) |i| {
                // Skip if outside the region of interest
                const dx = @as(i32, @intCast(i)) - @as(i32, @intCast(x));
                const dy = @as(i32, @intCast(j)) - @as(i32, @intCast(y));
                if (dx*dx + dy*dy > radius*radius) continue;
                
                // Simple gradient
                const gx = image.getPixel(i+1, j) - image.getPixel(i-1, j);
                const gy = image.getPixel(i, j+1) - image.getPixel(i, j-1);
                
                // Orientation
                const angle = math.atan2(gy, gx);
                const orientation = @mod(angle + math.pi, 2 * math.pi) * 
                                  @as(f32, @floatFromInt(self.num_orientations)) / (2 * math.pi);
                
                // Magnitude (weight)
                const mag = @sqrt(gx*gx + gy*gy);
                
                // Bilinear interpolation
                const bin = @mod(@as(usize, @intFromFloat(orientation)), self.num_orientations);
                const next_bin = @mod(bin + 1, self.num_orientations);
                const weight = orientation - @floor(orientation);
                
                histogram[bin] += mag * (1 - weight);
                histogram[next_bin] += mag * weight;
            }
        }
        
        // Normalize histogram
        var sum: f32 = 0;
        for (histogram) |h| sum += h * h;
        if (sum > 0) {
            const inv_norm = 1.0 / @sqrt(sum);
            for (histogram) |*h| h.* *= inv_norm;
        }
        
        return histogram;
    }
    
    /// Computes dominant orientation
    pub fn computeDominantOrientation(self: *@This(), 
                                     image: Image,
                                     x: usize,
                                     y: usize,
                                     radius: usize,
                                     allocator: ?Allocator) !f32 {
        const histogram = try self.computeOrientationHistogram(image, x, y, radius, allocator);
        defer self.allocator.free(histogram);
        
        // Find peak in histogram
        var max_bin: usize = 0;
        var max_val: f32 = 0;
        for (histogram, 0..) |h, i| {
            if (h > max_val) {
                max_val = h;
                max_bin = i;
            }
        }
        
        // Convert to angle
        return 2 * math.pi * @as(f32, @floatFromInt(max_bin)) / 
               @as(f32, @floatFromInt(self.num_orientations));
    }
    
    pub fn deinit(self: *@This()) void {
        // No resources to free in the base implementation
        _ = self;
    }
};

// Tests
const testing = std.testing;

test "MultiScaleMatcher basic functionality" {
    // Initialize test images
    const width = 64;
    const height = 64;
    
    // Create a simple pattern (a small square)
    var pattern = try Image.init(testing.allocator, 16, 16);
    defer pattern.deinit();
    
    // Fill pattern
    for (0..16) |y| {
        for (0..16) |x| {
            const val: f32 = if (x >= 4 and x < 12 and y >= 4 and y < 12) 1.0 else 0.0;
            pattern.setPixel(x, y, val);
        }
    }
    
    // Create a larger image with the pattern
    var image = try Image.init(testing.allocator, width, height);
    defer image.deinit();
    
    // Initialize with zeros
    for (0..height) |y| {
        for (0..width) |x| {
            image.setPixel(x, y, 0.0);
        }
    }
    
    // Place pattern in the image
    const offset_x = 20;
    const offset_y = 30;
    for (0..16) |y| {
        for (0..16) |x| {
            const val = pattern.getPixel(x, y);
            image.setPixel(offset_x + x, offset_y + y, val);
        }
    }
    
    // Initialize matcher
    var matcher = MultiScaleMatcher.init(testing.allocator);
    defer matcher.deinit();
    
    // Find best match
    const result = try matcher.findBestMatch(image, pattern, null);
    
    // Verify results
    try testing.expectApproxEqAbs(@as(f32, @floatFromInt(offset_x)), @as(f32, @floatFromInt(result.x)), 4.0);
    try testing.expectApproxEqAbs(@as(f32, @floatFromInt(offset_y)), @as(f32, @floatFromInt(result.y)), 4.0);
    try testing.expectApproxEqAbs(1.0, result.scale, 0.5);
    try testing.expect(result.score > 0.8);
}

test "RotationInvariantFeatures orientation detection" {
    // Create a test image with a gradient
    const width = 64;
    const height = 64;
    var image = try Image.init(testing.allocator, width, height);
    defer image.deinit();
    
    // Create a gradient at 45 degrees
    for (0..height) |y| {
        for (0..width) |x| {
            const val = @as(f32, @floatFromInt(x + y)) / @as(f32, @floatFromInt(width + height));
            image.setPixel(x, y, val);
        }
    }
    
    // Initialize feature detector
    var feature_detector = RotationInvariantFeatures.init(testing.allocator);
    defer feature_detector.deinit();
    
    // Compute dominant orientation
    const center_x = width / 2;
    const center_y = height / 2;
    const radius = 10;
    const orientation = try feature_detector.computeDominantOrientation(
        image, center_x, center_y, radius, null);
    
    // Expected orientation is 45 degrees (π/4 radians)
    const expected_orientation = math.pi / 4.0;
    try testing.expectApproxEqAbs(expected_orientation, orientation, 0.2);
}
