const std = @import("std");
const Pattern = @import("../neural/pattern").Pattern;

/// PatternRecognizer identifies patterns for efficient caching
pub const PatternRecognizer = struct {
    allocator: std.mem.Allocator,
    
    /// Initialize a new PatternRecognizer
    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .allocator = allocator,
        };
    }

    /// Calculate a fingerprint for pattern recognition
    /// This is a simple implementation that can be enhanced with more sophisticated algorithms
    pub fn calculateFingerprint(self: *const @This(), pattern: *const Pattern) ![]const u8 {
        _ = self; // Mark as used
        
        // Simple fingerprint based on pattern dimensions and first few bytes
        var fingerprint = std.ArrayList(u8).init(self.allocator);
        defer fingerprint.deinit();
        
        // Add dimensions to fingerprint
        try std.fmt.format(fingerprint.writer(), "{}x{}:", .{pattern.width, pattern.height});
        
        // Add hash of pattern data
        const hash = std.hash.Wyhash.hash(0, pattern.data);
        try std.fmt.format(fingerprint.writer(), "{x}", .{hash});
        
        return fingerprint.toOwnedSlice();
    }

    /// Check if a pattern is a good candidate for caching
    pub fn shouldCache(self: *const @This(), pattern: *const Pattern) bool {
        _ = self; // Mark as used
        
        // Simple heuristic: cache patterns that are between 64x64 and 4096x4096 pixels
        const min_size = 64 * 64;
        const max_size = 4096 * 4096;
        const pattern_size = pattern.width * pattern.height;
        
        return pattern_size >= min_size and pattern_size <= max_size;
    }

    /// Compare two patterns for similarity
    /// Returns a similarity score between 0.0 (completely different) and 1.0 (identical)
    pub fn similarityScore(self: *const @This(), a: *const Pattern, b: *const Pattern) f32 {
        _ = self; // Mark as used
        
        // If dimensions don't match, similarity is 0
        if (a.width != b.width or a.height != b.height) {
            return 0.0;
        }
        
        // Simple pixel-by-pixel comparison
        var same_pixels: usize = 0;
        const total_pixels = a.width * a.height;
        
        for (a.data, 0..) |pixel, i| {
            if (i >= b.data.len) break;
            if (pixel == b.data[i]) {
                same_pixels += 1;
            }
        }
        
        return @as(f32, @floatFromInt(same_pixels)) / @as(f32, @floatFromInt(total_pixels));
    }

    /// Find similar patterns in the cache
    pub fn findSimilar(self: *const @This(), pattern: *const Pattern, cache: anytype, min_similarity: f32) ![]const []const u8 {
        var matches = std.ArrayList([]const u8).init(self.allocator);
        
        // Iterate through cached patterns
        var it = cache.shards.iterator();
        while (it.next()) |entry| {
            const shard = entry.value_ptr;
            
            // Skip if dimensions don't match
            if (shard.width != pattern.width or shard.height != pattern.height) {
                continue;
            }
            
            // Create a temporary pattern for comparison
            const cached_pattern = Pattern{
                .data = shard.data,
                .width = shard.width,
                .height = shard.height,
                .pattern_type = .Visual,
                .metadata = .{},
                .allocator = self.allocator,
            };
            
            // Calculate similarity
            const similarity = self.similarityScore(pattern, &cached_pattern);
            if (similarity >= min_similarity) {
                try matches.append(entry.key_ptr.*);
            }
        }
        
        return matches.toOwnedSlice();
    }
};

// Tests
const testing = std.testing;

test "PatternRecognizer fingerprint" {
    const allocator = testing.allocator;
    var recognizer = PatternRecognizer.init(allocator);
    
    // Create a test pattern
    const width = 2;
    const height = 2;
    const data = [_]u8{ 0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 128 };
    const pattern = try Pattern.init(allocator, &data, width, height);
    defer pattern.deinit();
    
    // Calculate fingerprint
    const fingerprint = try recognizer.calculateFingerprint(pattern);
    defer allocator.free(fingerprint);
    
    // Should be in format "WxH:hash"
    try testing.expect(std.mem.startsWith(u8, fingerprint, "2x2:"));
    try testing.expect(fingerprint.len > 5);
}

test "PatternRecognizer similarity" {
    const allocator = testing.allocator;
    var recognizer = PatternRecognizer.init(allocator);
    
    // Create two test patterns
    const width = 2;
    const height = 2;
    const data1 = [_]u8{ 0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 128 };
    const data2 = [_]u8{ 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 0, 128 };
    
    const pattern1 = try Pattern.init(allocator, &data1, width, height);
    defer pattern1.deinit();
    
    const pattern2 = try Pattern.init(allocator, &data2, width, height);
    defer pattern2.deinit();
    
    // Check similarity
    const similarity = recognizer.similarityScore(pattern1, pattern2);
    try testing.expect(similarity >= 0.5 and similarity <= 1.0);
}

test "PatternRecognizer shouldCache" {
    const allocator = testing.allocator;
    var recognizer = PatternRecognizer.init(allocator);
    
    // Create a small pattern (should not be cached)
    const small_data = [_]u8{0} ** (32 * 32 * 4);
    const small_pattern = try Pattern.init(allocator, &small_data, 32, 32);
    defer small_pattern.deinit();
    
    // Create a medium pattern (should be cached)
    const med_data = [_]u8{0} ** (128 * 128 * 4);
    const med_pattern = try Pattern.init(allocator, &med_data, 128, 128);
    defer med_pattern.deinit();
    
    // Create a large pattern (should not be cached)
    const large_data = [_]u8{0} ** (8192 * 8192 * 4);
    const large_pattern = try Pattern.init(allocator, &large_data, 8192, 8192);
    defer large_pattern.deinit();
    
    // Test caching decisions
    try testing.expect(!recognizer.shouldCache(small_pattern));
    try testing.expect(recognizer.shouldCache(med_pattern));
    try testing.expect(!recognizer.shouldCache(large_pattern));
}
