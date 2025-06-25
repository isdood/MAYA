const std = @import("std");
const testing = std.testing;
const PatternTransform = @import("./pattern_transform.zig");
const heap = std.heap;
const Thread = std.Thread;

const TestContext = struct {
    allocator: std.mem.Allocator,
    cache: PatternTransform.PatternTransformCache,
    
    fn init(allocator: std.mem.Allocator, max_entries: usize) !@This() {
        return .{
            .allocator = allocator,
            .cache = try PatternTransform.PatternTransformCache.init(allocator, max_entries),
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

test "PatternTransformCache statistics tracking" {
    // Use an arena allocator for this test to ensure all allocations are cleaned up
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var ctx = try TestContext.init(allocator, 2);
    defer ctx.deinit();
    
    const pattern = try createTestPattern(allocator);
    defer {
        pattern.deinit(allocator);
        allocator.destroy(pattern);
    }
    
    // Initial stats should be zero
    var stats = ctx.cache.getStats();
    try testing.expectEqual(@as(u64, 0), stats.hits);
    try testing.expectEqual(@as(u64, 0), stats.misses);
    try testing.expectEqual(@as(u64, 0), stats.evictions);
    try testing.expectEqual(@as(u64, 0), stats.total_cached_bytes);
    
    // First transform (miss)
    const params1 = PatternTransform.TransformParams{ .scale_x = 2.0, .scale_y = 2.0 };
    const transformed1 = try ctx.cache.getOrTransform(pattern, params1);
    defer {
        transformed1.deinit(allocator);
        allocator.destroy(transformed1);
    }
    
    // Check stats after first transform
    stats = ctx.cache.getStats();
    try testing.expectEqual(@as(u64, 0), stats.hits);
    try testing.expectEqual(@as(u64, 1), stats.misses);
    try testing.expectEqual(@as(u64, 0), stats.evictions);
    try testing.expect(stats.total_cached_bytes > 0);
    
    // Same transform again (hit)
    const transformed2 = try ctx.cache.getOrTransform(pattern, params1);
    defer {
        transformed2.deinit(allocator);
        allocator.destroy(transformed2);
    }
    
    // Check stats after second transform (should be a hit)
    stats = ctx.cache.getStats();
    try testing.expectEqual(@as(u64, 1), stats.hits);
    try testing.expectEqual(@as(u64, 1), stats.misses);
    
    // Add more entries to trigger eviction
    const params2 = PatternTransform.TransformParams{ .scale_x = 3.0, .scale_y = 3.0 };
    const transformed3 = try ctx.cache.getOrTransform(pattern, params2);
    defer {
        transformed3.deinit(allocator);
        allocator.destroy(transformed3);
    }
    
    const params3 = PatternTransform.TransformParams{ .scale_x = 4.0, .scale_y = 4.0 };
    const transformed4 = try ctx.cache.getOrTransform(pattern, params3);
    defer {
        transformed4.deinit(allocator);
        allocator.destroy(transformed4);
    }
    
    // Check that we had an eviction
    stats = ctx.cache.getStats();
    try testing.expect(stats.evictions > 0);
}

test "PatternTransformCache clear" {
    // Use an arena allocator for this test to ensure all allocations are cleaned up
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var ctx = try TestContext.init(allocator, 10);
    defer ctx.deinit();
    
    const pattern = try createTestPattern(allocator);
    defer {
        pattern.deinit(allocator);
        allocator.destroy(pattern);
    }
    
    // Add a few entries
    const params1 = PatternTransform.TransformParams{ .scale_x = 2.0 };
    const params2 = PatternTransform.TransformParams{ .scale_x = 3.0 };
    
    _ = try ctx.cache.getOrTransform(pattern, params1);
    _ = try ctx.cache.getOrTransform(pattern, params2);
    
    // Check that cache is not empty
    var stats = ctx.cache.getStats();
    try testing.expect(stats.total_cached_bytes > 0);
    
    // Clear the cache
    ctx.cache.clear();
    
    // Check that cache is empty
    stats = ctx.cache.getStats();
    try testing.expectEqual(@as(u64, 0), stats.total_cached_bytes);
}

test "PatternTransformCache basic operations" {
    // This test verifies basic cache operations work correctly
    
    // Use an arena allocator for this test to ensure all allocations are cleaned up
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var ctx = try TestContext.init(allocator, 10);
    defer ctx.deinit();
    
    const pattern = try createTestPattern(allocator);
    defer {
        pattern.deinit(allocator);
        allocator.destroy(pattern);
    }
    
    // Test basic transform and cache
    const params = PatternTransform.TransformParams{
        .scale_x = 2.0,
        .scale_y = 2.0,
        .rotation = 0.0,
    };
    
    // First call should be a miss
    const transformed1 = try ctx.cache.getOrTransform(pattern, params);
    defer {
        transformed1.deinit(allocator);
        allocator.destroy(transformed1);
    }
    
    // Second call with same params should be a hit
    _ = try ctx.cache.getOrTransform(pattern, params);
    
    // Check stats
    const stats = ctx.cache.getStats();
    try testing.expectEqual(@as(u64, 1), stats.hits);
    try testing.expectEqual(@as(u64, 1), stats.misses);
    try testing.expect(stats.total_cached_bytes > 0);
}
