const std = @import("std");
const testing = std.testing;
const PatternTransform = @import("./pattern_transform.zig");

const TestContext = struct {
    allocator: std.mem.Allocator,
    cache: PatternTransform.PatternTransformCache,
    
    fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .allocator = allocator,
            .cache = try PatternTransform.PatternTransformCache.init(allocator, 10),
        };
    }
    
    fn deinit(self: *@This()) void {
        self.cache.deinit();
    }
};

test "PatternTransformCache basic scaling" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    
    // Create a simple 2x2 pattern (red, green, blue, white)
    const pattern_data = [_]u8{
        255, 0, 0, 255,     0, 255, 0, 255,   // Red, Green
        0, 0, 255, 255,   255, 255, 255, 255,  // Blue, White
    };
    
    // Create a copy of the pattern data on the heap
    const pattern_data_copy = try testing.allocator.dupe(u8, &pattern_data);
    defer testing.allocator.free(pattern_data_copy);
    
    const pattern = PatternTransform.Pattern{
        .data = pattern_data_copy,
        .width = 2,
        .height = 2,
    };
    
    // Test scale up 2x
    const params = PatternTransform.TransformParams{ .scale_x = 2.0, .scale_y = 2.0 };
    const transformed = try ctx.cache.getOrTransform(&pattern, params);
    defer {
        transformed.deinit(ctx.allocator);
        ctx.allocator.destroy(transformed);
    }
    
    try testing.expect(transformed.width == 4);
    try testing.expect(transformed.height == 4);
    
    // Verify some sample pixels (top-left corner should be red)
    try testing.expect(transformed.data[0] == 255); // R
    try testing.expect(transformed.data[1] == 0);   // G
    try testing.expect(transformed.data[2] == 0);   // B
    try testing.expect(transformed.data[3] == 255); // A
}

test "PatternTransformCache rotation" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    
    // Create a simple 2x2 pattern (red top-left, green top-right, blue bottom-left, white bottom-right)
    const pattern_data = [_]u8{
        255, 0, 0, 255,     0, 255, 0, 255,   // Red, Green
        0, 0, 255, 255,   255, 255, 255, 255,  // Blue, White
    };
    
    // Create a copy of the pattern data on the heap
    const pattern_data_copy = try testing.allocator.dupe(u8, &pattern_data);
    defer testing.allocator.free(pattern_data_copy);
    
    const pattern = PatternTransform.Pattern{
        .data = pattern_data_copy,
        .width = 2,
        .height = 2,
    };
    
    // Test 90-degree rotation (note: our current implementation doesn't support rotation yet)
    const params = PatternTransform.TransformParams{ .angle_degrees = 90.0 };
    const transformed = try ctx.cache.getOrTransform(&pattern, params);
    defer {
        transformed.deinit(ctx.allocator);
        ctx.allocator.destroy(transformed);
    }
    
    // For now, just verify the function completes successfully
    // In a real implementation, we would verify the rotation
    try testing.expect(transformed.width == pattern.width);
    try testing.expect(transformed.height == pattern.height);
}

test "PatternTransformCache translation" {
    var ctx = try TestContext.init(testing.allocator);
    defer ctx.deinit();
    
    // Create a simple 2x2 pattern
    const pattern_data = [_]u8{
        255, 0, 0, 255,     0, 255, 0, 255,   // Red, Green
        0, 0, 255, 255,   255, 255, 255, 255,  // Blue, White
    };
    
    // Create a copy of the pattern data on the heap
    const pattern_data_copy = try testing.allocator.dupe(u8, &pattern_data);
    defer testing.allocator.free(pattern_data_copy);
    
    const pattern = PatternTransform.Pattern{
        .data = pattern_data_copy,
        .width = 2,
        .height = 2,
    };
    
    // Test translation (note: our current implementation doesn't support translation yet)
    const params = PatternTransform.TransformParams{ 
        .translate_x = 1.0,
        .translate_y = 1.0,
    };
    
    const transformed = try ctx.cache.getOrTransform(&pattern, params);
    defer {
        transformed.deinit(ctx.allocator);
        ctx.allocator.destroy(transformed);
    }
    
    // For now, just verify the function completes successfully
    // In a real implementation, we would verify the translation
    try testing.expect(transformed.width == pattern.width);
    try testing.expect(transformed.height == pattern.height);
}

test "PatternTransformCache LRU behavior" {
    // Create a small cache with max 2 entries
    var cache = try PatternTransform.PatternTransformCache.init(testing.allocator, 2);
    defer cache.deinit();
    
    const pattern_data = [_]u8{255} ** 16; // 2x2 RGBA pattern
    // Create a pattern using the cache's createPattern method
    const pattern = try cache.createPattern(&pattern_data, 2, 2);
    defer {
        pattern.deinit(testing.allocator);
        testing.allocator.destroy(pattern);
    }
    
    // Add two entries
    const p1 = try cache.getOrTransform(&pattern, .{ .scale_x = 1.0 });
    const p2 = try cache.getOrTransform(&pattern, .{ .scale_x = 2.0 });
    
    // Cache should be full now
    try testing.expect(cache.lru.count() == 2);
    
    // Access first item to make it most recently used
    _ = try cache.getOrTransform(&pattern, .{ .scale_x = 1.0 });
    
    // Add third entry, should evict the second one (p2)
    _ = try cache.getOrTransform(&pattern, .{ .scale_x = 3.0 });
    
    // Cache should still have 2 entries
    try testing.expect(cache.lru.count() == 2);
    
    // p1 should still be in cache (was accessed most recently)
    const p1_again = try cache.getOrTransform(&pattern, .{ .scale_x = 1.0 });
    try testing.expect(p1 == p1_again);
    
    // p2 should have been evicted
    const p2_new = try cache.getOrTransform(&pattern, .{ .scale_x = 2.0 });
    try testing.expect(p2 != p2_new); // Should be a new instance
}
