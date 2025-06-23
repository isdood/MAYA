const std = @import("std");
const testing = std.testing;
const Pattern = @import("../neural/pattern.zig").Pattern;
const QuantumCache = @import("./quantum_cache.zig").QuantumCache;

// Test integration with pattern processing pipeline
test "QuantumCache integration with pattern processing" {
    // Initialize test allocator
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Initialize the global pattern pool
    try Pattern.initGlobalPool(allocator);
    defer Pattern.deinitGlobalPool();
    
    // Create a test pattern
    const test_data = try allocator.alloc(u8, 100);
    @memset(test_data, 42); // Fill with test data
    
    const pattern = try Pattern.new(
        allocator,
        test_data,
        10,  // width
        10,  // height
        .Visual
    );
    
    // Initialize cache
    var cache = try QuantumCache.init(allocator, .{ .max_shards = 10 });
    defer cache.deinit();
    
    // Pre-shatter the pattern
    try cache.preShatter(pattern);
    
    // Retrieve and verify the pattern
    const shard = cache.getShard("test_pattern");
    try testing.expect(shard != null);
    if (shard) |s| {
        try testing.expectEqual(@as(usize, 100), s.len);
        for (s) |byte| {
            try testing.expectEqual(@as(u8, 42), byte);
        }
    }
    
    // Test coherence maintenance
    cache.maintainCoherence();
    try testing.expect(cache.coherence > 0.0);
}

// Test with a small subset of patterns
test "QuantumCache with pattern subset" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    try Pattern.initGlobalPool(allocator);
    defer Pattern.deinitGlobalPool();
    
    // Initialize cache with small size to test eviction
    var cache = try QuantumCache.init(allocator, .{ .max_shards = 3 });
    defer cache.deinit();
    
    // Create and cache 5 patterns (should trigger eviction)
    for (0..5) |i| {
        const data = try allocator.alloc(u8, 10);
        @memset(data, @as(u8, @intCast(i)));
        
        const pattern = try Pattern.new(
            allocator,
            data,
            2,  // width
            5,  // height
            .Visual
        );
        
        pattern.id = try std.fmt.allocPrint(allocator, "pattern_{}", .{i});
        try cache.preShatter(pattern);
    }
    
    // First pattern should be evicted (LRU)
    try testing.expect(cache.getShard("pattern_0") == null);
    
    // Last pattern should be present
    try testing.expect(cache.getShard("pattern_4") != null);
}
