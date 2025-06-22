const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const Pattern = @import("pattern.zig").Pattern;
const PatternPool = @import("pattern_memory.zig").PatternPool;

// Test memory pool allocation and deallocation
test "PatternPool allocation and deallocation" {
    // Initialize memory pool
    var pool = try PatternPool.init(testing.allocator, .{
        .initial_capacity = 16,
        .max_pattern_size = 1024 * 1024, // 1MB
        .thread_safe = false,
    });
    defer pool.deinit();
    
    // Test small pattern allocation
    {
        const pattern = try pool.getPattern(32, 32, 4);
        try testing.expectEqual(@as(usize, 32), pattern.width);
        try testing.expectEqual(@as(usize, 32), pattern.height);
        try testing.expectEqual(@as(usize, 32 * 32 * 4), pattern.data.len);
        
        // Release and get again to test pool reuse
        pool.releasePattern(pattern);
        
        const pattern2 = try pool.getPattern(32, 32, 4);
        try testing.expectEqual(@as(usize, 32 * 32 * 4), pattern2.data.len);
        pool.releasePattern(pattern2);
    }
    
    // Test large pattern allocation (should bypass pool)
    {
        const large_pattern = try pool.getPattern(1024, 1024, 4);
        try testing.expectEqual(@as(usize, 1024 * 1024 * 4), large_pattern.data.len);
        // Large patterns are not pooled, so we use regular deinit
        large_pattern.deinit(testing.allocator);
    }
}

// Test zero-copy operations
test "Zero-copy operations" {
    // Initialize a pattern
    const pattern = try Pattern.initPattern(testing.allocator, 64, 64, 4);
    defer pattern.deinit(testing.allocator);
    
    // Fill with test data
    @memset(pattern.data, 100);
    
    // Test view creation
    const view = pattern.createView(16, 16, 32, 32);
    try testing.expectEqual(@as(usize, 32), view.width);
    try testing.expectEqual(@as(usize, 32), view.height);
    try testing.expectEqual(@as(usize, 32 * 32 * 4), view.data.len);
    
    // Test in-place transformation
    const transform_fn = struct {
        fn transform(data: []u8) void {
            for (data) |*pixel| {
                pixel.* +%= 50;
            }
        }
    }.transform;
    const transformed = try pattern.transformInPlace(transform_fn);
    
    // Verify transformation
    for (transformed.data) |pixel| {
        try testing.expectEqual(@as(u8, 150), pixel);
    }
    
    // Clean up
    if (transformed != pattern) {
        transformed.deinit(testing.allocator);
    }
}

// Test basic pattern creation without global pool
test "Basic pattern creation" {
    // Create a pattern directly
    const pattern = try Pattern.initPattern(testing.allocator, 32, 32, 4);
    defer pattern.deinit(testing.allocator);
    
    // Verify pattern was created correctly
    try testing.expectEqual(@as(usize, 32), pattern.width);
    try testing.expectEqual(@as(usize, 32), pattern.height);
    try testing.expectEqual(@as(usize, 32 * 32 * 4), pattern.data.len);
}

// Test basic pattern operations without threading
test "Basic pattern operations" {
    const allocator = testing.allocator;
    
    // Initialize pool
    var pool = try PatternPool.init(allocator, .{
        .initial_capacity = 10,
        .max_pattern_size = 1024 * 1024,
        .thread_safe = false, // No need for thread safety in this test
    });
    defer pool.deinit();
    
    // Test pattern allocation and release
    {
        const pattern = try pool.getPattern(32, 32, 4);
        defer pool.releasePattern(pattern);
        
        // Test pattern properties
        try testing.expectEqual(@as(usize, 32), pattern.width);
        try testing.expectEqual(@as(usize, 32), pattern.height);
        try testing.expectEqual(@as(usize, 32 * 32 * 4), pattern.data.len);
        
        // Test pattern data
        @memset(pattern.data, 100);
        for (pattern.data) |byte| {
            try testing.expectEqual(@as(u8, 100), byte);
        }
    }
    
    // Test that pattern was returned to the pool
    {
        const pattern = try pool.getPattern(32, 32, 4);
        defer pool.releasePattern(pattern);
        
        // If the pool is working, we should get a pattern with the same memory
        try testing.expectEqual(@as(usize, 32 * 32 * 4), pattern.data.len);
    }
}
