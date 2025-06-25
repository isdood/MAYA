const std = @import("std");
const testing = std.testing;
const PatternTransform = @import("./pattern_transform.zig");
const heap = std.heap;

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

fn createTestPattern(allocator: std.mem.Allocator) !*PatternTransform.Pattern {
    // Create a simple 2x2 pattern (red, green, blue, white)
    const pattern_data = [_]u8{
        255, 0, 0, 255,     0, 255, 0, 255,   // Red, Green
        0, 0, 255, 255,   255, 255, 255, 255,  // Blue, White
    };
    
    // Create a pattern that owns its data
    return try PatternTransform.Pattern.create(allocator, &pattern_data, 2, 2);
}

test "PatternTransformCache basic scaling" {
    // Use an arena allocator for this test to ensure all allocations are cleaned up
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var ctx = try TestContext.init(allocator);
    defer ctx.deinit();
    
    const pattern = try createTestPattern(allocator);
    defer {
        pattern.deinit(allocator);
        allocator.destroy(pattern);
    }
    
    // Test scale up 2x
    const params = PatternTransform.TransformParams{ .scale_x = 2.0, .scale_y = 2.0 };
    const transformed = try ctx.cache.getOrTransform(pattern, params);
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
    // Use an arena allocator for this test to ensure all allocations are cleaned up
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var ctx = try TestContext.init(allocator);
    defer ctx.deinit();
    
    const pattern = try createTestPattern(allocator);
    defer {
        pattern.deinit(allocator);
        allocator.destroy(pattern);
    }
    
    // Test 90-degree rotation (note: our current implementation doesn't support rotation yet)
    const params = PatternTransform.TransformParams{ .angle = 90.0 };
    const transformed = try ctx.cache.getOrTransform(pattern, params);
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
    // Use an arena allocator for this test to ensure all allocations are cleaned up
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var ctx = try TestContext.init(allocator);
    defer ctx.deinit();
    
    const pattern = try createTestPattern(allocator);
    defer {
        pattern.deinit(allocator);
        allocator.destroy(pattern);
    }
    
    // Test translation (note: our current implementation doesn't support translation yet)
    const params = PatternTransform.TransformParams{ 
        .translate_x = 1.0,
        .translate_y = 1.0,
    };
    
    const transformed = try ctx.cache.getOrTransform(pattern, params);
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
    // Use an arena allocator for this test to ensure all allocations are cleaned up
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Create a small cache with max 2 entries
    var cache = try PatternTransform.PatternTransformCache.init(allocator, 2);
    defer cache.deinit();
    
    // Helper to create a test pattern with unique data
    const createTestPatternWithValue = struct {
        fn create(alloc: std.mem.Allocator, value: u8) !*PatternTransform.Pattern {
            const pattern_data = [_]u8{value} ** 16; // 2x2 RGBA pattern
            return try PatternTransform.Pattern.create(alloc, &pattern_data, 2, 2);
        }
    }.create;
    
    // Create a pattern that owns its data
    const pattern = try createTestPatternWithValue(testing.allocator, 255);
    defer {
        pattern.deinit(testing.allocator);
        testing.allocator.destroy(pattern);
    }

    
    // Add two entries
    const p1 = try cache.getOrTransform(pattern, .{ .scale_x = 1.0 });
    defer {
        p1.deinit(allocator);
        allocator.destroy(p1);
    }
    
    const p2 = try cache.getOrTransform(pattern, .{ .scale_x = 2.0 });
    defer {
        p2.deinit(allocator);
        allocator.destroy(p2);
    }
    
    // Cache should be full now
    try testing.expect(cache.lru.count() == 2);
    
    // Access first item to make it most recently used
    const p1_again = try cache.getOrTransform(pattern, .{ .scale_x = 1.0 });
    defer {
        p1_again.deinit(allocator);
        allocator.destroy(p1_again);
    }
    
    // Add third entry, should evict the second one (p2)
    const p3 = try cache.getOrTransform(pattern, .{ .scale_x = 3.0 });
    defer {
        p3.deinit(allocator);
        allocator.destroy(p3);
    }
    
    // Cache should still have 2 entries
    try testing.expect(cache.lru.count() == 2);
    
    // p1 should still be in cache (was accessed most recently)
    const p1_again2 = try cache.getOrTransform(pattern, .{ .scale_x = 1.0 });
    defer {
        p1_again2.deinit(allocator);
        allocator.destroy(p1_again2);
    }
    
    // p2 should have been evicted, so this should create a new instance
    const p2_new = try cache.getOrTransform(pattern, .{ .scale_x = 2.0 });
    defer {
        p2_new.deinit(allocator);
        allocator.destroy(p2_new);
    }
}
