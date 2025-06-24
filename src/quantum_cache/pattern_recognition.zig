const std = @import("std");

// Define a simple Pattern type for testing
const Pattern = struct {
    data: []const u8,
    width: usize,
    height: usize,
};

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
        _ = self; // Keep for future use
        
        // Simple heuristic: cache patterns that are between 64x64 and 1024x1024 pixels
        // and have a reasonable data size (not too small, not too large)
        const min_pixels = 64 * 64;      // 4KB for RGBA
        const max_pixels = 1024 * 1024;   // 4MB for RGBA
        const pattern_pixels = pattern.width * pattern.height;
        
        // Also check data size to be safe
        const min_data_size = 4 * 1024;         // 4KB min
        const max_data_size = 16 * 1024 * 1024;  // 16MB max
        const data_size = pattern.data.len;
        
        return (pattern_pixels >= min_pixels and 
                pattern_pixels <= max_pixels and
                data_size >= min_data_size and 
                data_size <= max_data_size);
    }

    /// Compare two patterns for similarity
    /// Returns a similarity score between 0.0 (completely different) and 1.0 (identical)
    pub fn similarityScore(self: *const @This(), a: *const Pattern, b: *const Pattern) f32 {
        _ = self; // Keep for future use
        
        // If dimensions don't match, similarity is 0
        if (a.width != b.width or a.height != b.height) {
            return 0.0;
        }
        
        // If both patterns are empty, they're identical
        if (a.data.len == 0 and b.data.len == 0) {
            return 1.0;
        }
        
        // If one pattern is empty but not the other, they're completely different
        if (a.data.len == 0 or b.data.len == 0) {
            return 0.0;
        }
        
        // Simple pixel-by-pixel comparison
        var same_bytes: usize = 0;
        const min_len = @min(a.data.len, b.data.len);
        
        for (a.data[0..min_len], 0..) |a_byte, i| {
            if (a_byte == b.data[i]) {
                same_bytes += 1;
            }
        }
        
        // Calculate similarity as a percentage of matching bytes
        return @as(f32, @floatFromInt(same_bytes)) / @as(f32, @floatFromInt(min_len));
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
    const pattern = Pattern{
        .data = &data,
        .width = width,
        .height = height,
    };
    
    // Calculate fingerprint
    const fingerprint = try recognizer.calculateFingerprint(&pattern);
    defer allocator.free(fingerprint);
    
    // Should be in format "WxH:hash"
    try testing.expect(std.mem.startsWith(u8, fingerprint, "2x2:"));
    try testing.expect(fingerprint.len > 5);
}

test "pattern recognition smoke test" {
    // Create a simple pattern
    const data = [_]u8{1, 2, 3, 4};
    const pattern = Pattern{
        .data = &data,
        .width = 2,
        .height = 2,
    };
    
    // Create a recognizer
    var recognizer = PatternRecognizer.init(testing.allocator);
    
    // Calculate fingerprint
    const fingerprint = try recognizer.calculateFingerprint(&pattern);
    defer testing.allocator.free(fingerprint);
    
    // Should be in format "WxH:hash"
    try testing.expect(std.mem.startsWith(u8, fingerprint, "2x2:"));
    try testing.expect(fingerprint.len > 5);
    
    // This pattern is too small to be cached
    try testing.expect(!recognizer.shouldCache(&pattern));
}

test "PatternRecognizer shouldCache" {
    const allocator = testing.allocator;
    var recognizer = PatternRecognizer.init(allocator);
    
    // Create a small pattern (should not be cached - too small)
    const small_data = [_]u8{0} ** (32 * 32 * 4);  // 4KB
    const small_pattern = Pattern{
        .data = &small_data,
        .width = 32,
        .height = 32,
    };
    
    // Create a medium pattern (should be cached)
    const med_data = [_]u8{0} ** (256 * 256 * 4);  // 256KB
    const med_pattern = Pattern{
        .data = &med_data,
        .width = 256,
        .height = 256,
    };
    
    // Create a large pattern (should not be cached - too large)
    const large_data = [_]u8{0} ** (2048 * 2048 * 4);  // 16MB
    const large_pattern = Pattern{
        .data = &large_data,
        .width = 2048,
        .height = 2048,
    };
    
    // Test caching decisions
    try testing.expect(!recognizer.shouldCache(&small_pattern));
    try testing.expect(recognizer.shouldCache(&med_pattern));
    try testing.expect(!recognizer.shouldCache(&large_pattern));
}
