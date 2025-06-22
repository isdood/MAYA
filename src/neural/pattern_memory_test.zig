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

// Skip thread safety test in single-threaded mode
if (!builtin.single_threaded) {
    test "Thread-safe pattern pool" {
    // Skip this test in single-threaded mode
    if (builtin.single_threaded) return error.SkipZigTest;
    
    const allocator = testing.allocator;
    const num_threads = 4;
    const patterns_per_thread = 10; // Reduced for faster tests
    
    // Initialize thread-safe pool
    var pool = try PatternPool.init(allocator, .{
        .initial_capacity = num_threads * patterns_per_thread,
        .max_pattern_size = 1024 * 1024,
        .thread_safe = true,
    });
    defer pool.deinit();
    
    // Shared counter for thread IDs
    var counter: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0);
    
    // Function to run in each thread
    const worker = struct {
        fn run(pool_ptr: *PatternPool, thread_id: u32) !void {
            var patterns = std.ArrayList(*Pattern).init(allocator);
            defer {
                for (patterns.items) |pat| {
                    pool_ptr.releasePattern(pat);
                }
                patterns.deinit();
            }
            
            // Allocate and work with patterns
            for (0..patterns_per_thread) |i| {
                const size = 16 + (i % 16);
                const pattern = try pool_ptr.getPattern(size, size, 4);
                try patterns.append(pattern);
                
                // Mark pattern with thread ID
                @memset(pattern.data, @as(u8, @intCast(thread_id)));
                
                // Verify the pattern
                for (pattern.data) |byte| {
                    try testing.expect(byte == @as(u8, @intCast(thread_id)));
                }
            }
            
            // Atomically increment the counter
            _ = counter.fetchAdd(1, .SeqCst);
        }
    };
    
    // Create and start threads
    var threads = std.ArrayList(std.Thread).init(allocator);
    defer threads.deinit();
    
    for (0..num_threads) |i| {
        try threads.append(try std.Thread.spawn(.{}, worker.run, .{ &pool, @as(u32, @intCast(i)) }));
    }
    
    // Wait for all threads to complete
    for (threads.items) |t| {
        t.join();
    }
    
        // Verify all threads completed
        try testing.expectEqual(@as(u32, @intCast(num_threads)), counter.load(.SeqCst));
    }
}
