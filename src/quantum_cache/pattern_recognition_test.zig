const std = @import("std");
const testing = std.testing;

// Import Pattern and PatternRecognizer from pattern_recognition.zig
const pattern_recognition = @import("pattern_recognition.zig");
const Pattern = pattern_recognition.Pattern;
const PatternRecognizer = pattern_recognition.PatternRecognizer;

// Helper function to create a test pattern
fn createTestPattern(allocator: std.mem.Allocator, width: usize, height: usize, value: u8) !Pattern {
    const size = width * height * 4; // 4 bytes per pixel (RGBA)
    const data = try allocator.alloc(u8, size);
    @memset(data, value);
    return Pattern.init(data, width, height);
}

test "PatternRecognizer shouldCache" {
    const allocator = testing.allocator;
    var recognizer = PatternRecognizer.init(allocator);
    
    // Create a small pattern (should not be cached - too small)
    const small_pattern = try createTestPattern(allocator, 32, 32, 0);
    defer allocator.free(small_pattern.data);
    
    // Create a medium pattern (should be cached)
    const med_pattern = try createTestPattern(allocator, 256, 256, 0);
    defer allocator.free(med_pattern.data);
    
    // Create a large pattern (should not be cached - too large)
    const large_pattern = try createTestPattern(allocator, 2048, 2048, 0);
    defer allocator.free(large_pattern.data);
    
    // Test caching decisions
    try testing.expect(!recognizer.shouldCache(&small_pattern));
    try testing.expect(recognizer.shouldCache(&med_pattern));
    try testing.expect(!recognizer.shouldCache(&large_pattern));
}

test "PatternRecognizer similarityScore" {
    const allocator = testing.allocator;
    var recognizer = PatternRecognizer.init(allocator);
    
    // Create two identical patterns
    const pattern1 = try createTestPattern(allocator, 2, 2, 0);
    defer allocator.free(pattern1.data);
    
    var pattern2_data = try allocator.dupe(u8, pattern1.data);
    defer allocator.free(pattern2_data);
    const pattern2 = Pattern.init(pattern2_data, 2, 2);
    
    // Should be 100% similar
    const similarity1 = recognizer.similarityScore(&pattern1, &pattern2);
    try testing.expectEqual(@as(f32, 1.0), similarity1);
    
    // Create a slightly different pattern
    pattern2_data[0] = 1; // Change one byte
    const similarity2 = recognizer.similarityScore(&pattern1, &pattern2);
    try testing.expect(similarity2 < 1.0);
    try testing.expect(similarity2 > 0.9); // Should still be very similar
    
    // Create a completely different pattern
    const pattern3 = try createTestPattern(allocator, 2, 2, 255);
    defer allocator.free(pattern3.data);
    
    const similarity3 = recognizer.similarityScore(&pattern1, &pattern3);
    try testing.expect(similarity3 < 0.5); // Should be quite different
}

test "PatternRecognizer findSimilar" {
    const allocator = testing.allocator;
    var recognizer = PatternRecognizer.init(allocator);
    
    // Create a test cache
    const TestCache = struct {
        shards: std.StringArrayHashMap(struct {
            data: []const u8,
            width: usize,
            height: usize,
        }),
        
        pub fn init(alloc: std.mem.Allocator) @This() {
            return .{
                .shards = std.StringArrayHashMap(@TypeOf(.{ .data = &.{}, .width = 0, .height = 0 })).init(alloc),
            };
        }
        
        pub fn deinit(self: *@This()) void {
            self.shards.deinit();
        }
    };
    
    var cache = TestCache.init(allocator);
    defer cache.deinit();
    
    // Add a pattern to the cache
    const pattern1 = try createTestPattern(allocator, 2, 2, 0);
    defer allocator.free(pattern1.data);
    
    try cache.shards.put("test1", .{
        .data = pattern1.data,
        .width = pattern1.width,
        .height = pattern1.height,
    });
    
    // Find similar patterns (should find the one we just added)
    const similar = try recognizer.findSimilar(&pattern1, &cache, 0.9);
    defer {
        for (similar) |key| allocator.free(key);
        allocator.free(similar);
    }
    
    try testing.expectEqual(@as(usize, 1), similar.len);
    try testing.expectEqualStrings("test1", similar[0]);
}
