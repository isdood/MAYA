const std = @import("std");
const Pattern = @import("../neural/pattern.zig").Pattern;
const PatternRecognizer = @import("pattern_recognition.zig").PatternRecognizer;

// Maximum number of shards to keep in the cache
const MAX_SHARDS = 1024;

// Coherence decay rate per access (higher = faster decay)
const COHERENCE_DECAY = 0.95;

// Minimum coherence before a shard is considered for eviction
const MIN_COHERENCE = 0.1;

/// QuantumShard represents a pre-shattered fragment of a pattern
pub const QuantumShard = struct {
    data: []const u8,
    width: usize,
    height: usize,
    coherence: f32 = 1.0,
    last_accessed: i64,
    access_count: u32 = 0,
    
    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

/// QuantumCache implements quantum-coherent caching for pattern processing
pub const QuantumCache = struct {
    allocator: std.mem.Allocator,
    shards: std.StringArrayHashMap(QuantumShard),
    coherence: f32 = 0.0,
    prediction_depth: u8 = 3,
    max_shards: usize = 1024,
    clock: *std.time.Timer,

    /// Initialize a new QuantumCache
    recognizer: PatternRecognizer,

    pub fn init(
        allocator: std.mem.Allocator,
        options: struct {
            prediction_depth: u8 = 3,
            max_shards: usize = 1024,
        },
    ) !@This() {
        const clock = try std.time.Timer.start();
        return .{
            .allocator = allocator,
            .shards = std.StringArrayHashMap(QuantumShard).init(allocator),
            .prediction_depth = options.prediction_depth,
            .max_shards = options.max_shards,
            .clock = clock,
            .recognizer = PatternRecognizer.init(allocator),
        };
    }

    pub fn preShatter(self: *@This(), pattern: *const Pattern) !void {
        // Create a compatible pattern for the recognizer
        const compat_pattern = Pattern{
            .data = pattern.data,
            .width = pattern.width,
            .height = pattern.height,
        };
        
        // Check if this pattern should be cached
        if (!self.recognizer.shouldCache(&compat_pattern)) {
            return; // Skip patterns that aren't good candidates for caching
        }

        // Calculate fingerprint for pattern recognition
        const fingerprint = try self.recognizer.calculateFingerprint(&compat_pattern);
        defer self.allocator.free(fingerprint);

        // Check for similar patterns in cache
        const similar = try self.recognizer.findSimilar(&compat_pattern, self, 0.9); // 90% similarity threshold
        defer {
            for (similar) |key| self.allocator.free(key);
            self.allocator.free(similar);
        }
        
        // If we found a similar pattern, don't cache this one
        if (similar.len > 0) {
            return;
        }

        // Check if we need to evict before adding a new shard
        if (self.shards.count() >= self.max_shards) {
            try self.evictLRU();
        }

        // Create a copy of the pattern data
        const data_copy = try self.allocator.dupe(u8, pattern.data);
        errdefer self.allocator.free(data_copy);

        // Create the shard
        const shard = QuantumShard{
            .data = data_copy,
            .width = pattern.width,
            .height = pattern.height,
            .last_accessed = self.clock.read(),
            .coherence = 1.0,
            .access_count = 0,
        };

        // Make a copy of the fingerprint to use as the key
        const fingerprint_copy = try self.allocator.dupe(u8, fingerprint);
        errdefer self.allocator.free(fingerprint_copy);

        // Store the new shard with its fingerprint as the key
        try self.shards.put(fingerprint_copy, shard);
    }

    /// Get a cached pattern shard
    pub fn getShard(self: *@This(), pattern_id: []const u8) ?struct { data: []const u8, width: usize, height: usize } {
        if (self.shards.getPtr(pattern_id)) |shard| {
            // Update access time and count
            shard.last_accessed = self.clock.read();
            shard.access_count += 1;
            
            // Slightly increase coherence on access
            shard.coherence = @min(1.0, shard.coherence + 0.05);
            
            return .{
                .data = shard.data,
                .width = shard.width,
                .height = shard.height,
            };
        }
        return null;
    }

    /// Maintain quantum coherence of shards
    pub fn maintainCoherence(self: *@This()) !void {
        var it = self.shards.iterator();
        var total_coherence: f32 = 0.0;
        var count: usize = 0;
        var to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();

        // First pass: update coherence and mark low-coherence shards for removal
        while (it.next()) |entry| {
            const shard = entry.value_ptr;
            
            // Apply coherence decay
            shard.coherence *= COHERENCE_DECAY;
            
            // Mark for removal if coherence is too low
            if (shard.coherence < MIN_COHERENCE) {
                try to_remove.append(entry.key_ptr.*);
            } else {
                total_coherence += shard.coherence;
                count += 1;
            }
        }
        
        // Remove low-coherence shards
        for (to_remove.items) |key| {
            if (self.shards.fetchRemove(key)) |entry| {
                entry.value.deinit(self.allocator);
            }
        }

        // Update overall cache coherence
        if (count > 0) {
            self.coherence = total_coherence / @as(f32, @floatFromInt(count));
        } else {
            self.coherence = 0.0;
        }
    }

    /// Evict least recently used shard
    fn evictLRU(self: *@This()) !void {
        var lru_key: ?[]const u8 = null;
        var lru_time: i64 = std.math.maxInt(i64);
        var lowest_coherence: f32 = 1.0;
        var lru_coherence_key: ?[]const u8 = null;

        var it = self.shards.iterator();
        while (it.next()) |entry| {
            const shard = entry.value_ptr;
            
            // Track LRU
            if (shard.last_accessed < lru_time) {
                lru_time = shard.last_accessed;
                lru_key = entry.key_ptr.*;
            }
            
            // Track lowest coherence
            if (shard.coherence < lowest_coherence) {
                lowest_coherence = shard.coherence;
                lru_coherence_key = entry.key_ptr.*;
            }
        }

        // Prefer evicting low-coherence items, fall back to LRU
        const key_to_evict = lru_coherence_key orelse lru_key;
        
        if (key_to_evict) |key| {
            if (self.shards.fetchRemove(key)) |entry| {
                entry.value.deinit(self.allocator);
            }
        }
    }

    /// Deinitialize and clean up resources
    pub fn deinit(self: *@This()) void {
        var it = self.shards.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.shards.deinit();
    }
};

// Simple test for the QuantumCache
const testing = std.testing;
const test_patterns = @import("./test_patterns.zig");

test "QuantumCache basic operations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var cache = try QuantumCache.init(
        allocator,
        .{ 
            .max_shards = 2,
            .prediction_depth = 3,
        },
    );
    defer cache.deinit();

    // Create a test pattern
    const pattern1 = try test_patterns.createSimplePattern(allocator, "test1", 32, 32);
    defer {
        pattern1.deinit();
        allocator.destroy(pattern1);
    }

    // Test pre-shattering
    try cache.preShatter(pattern1);
    
    // Test retrieving shard
    const shard = cache.getShard("test1");
    try testing.expect(shard != null);
    
    if (shard) |s| {
        try testing.expectEqual(@as(usize, 32), s.width);
        try testing.expectEqual(@as(usize, 32), s.height);
        try testing.expect(s.data.len == 32 * 32 * 4);
    }
    
    // Test LRU eviction
    const pattern2 = try test_patterns.createRandomPattern(allocator, "test2", 32, 32);
    defer {
        pattern2.deinit();
        allocator.destroy(pattern2);
    }
    try cache.preShatter(pattern2);
    
    // This should trigger eviction of the first pattern
    const pattern3 = try test_patterns.createCheckerboardPattern(allocator, "test3", 32, 32, 8);
    defer {
        pattern3.deinit();
        allocator.destroy(pattern3);
    }
    try cache.preShatter(pattern3);
    
    // First pattern should be evicted
    try testing.expect(cache.getShard("test1") == null);
    
    // Test coherence maintenance
    try cache.maintainCoherence();
    
    // Access pattern3 to increase its coherence
    _ = cache.getShard("test3");
    
    // Test coherence after access
    try cache.maintainCoherence();
    
    // Pattern3 should still be in cache due to recent access
    try testing.expect(cache.getShard("test3") != null);
}

test "QuantumCache pattern recognition" {
    const allocator = testing.allocator;
    var cache = try QuantumCache.init(allocator, .{});
    defer cache.deinit();

    // Create two similar patterns
    const width = 100;
    const height = 100;
    var data1 = try allocator.alloc(u8, width * height * 4);
    defer allocator.free(data1);
    @memset(data1, 0);

    const data2 = try allocator.alloc(u8, width * height * 4);
    defer allocator.free(data2);
    @memset(data2, 0);

    // Make the patterns slightly different
    data1[0] = 255; // One pixel difference

    const pattern1 = try Pattern.init(allocator, data1, width, height);
    defer pattern1.deinit();

    const pattern2 = try Pattern.init(allocator, data2, width, height);
    defer pattern2.deinit();

    // First pattern should be cached
    try cache.preShatter(pattern1);
    try testing.expectEqual(@as(usize, 1), cache.shards.count());

    // Second pattern (very similar) should not be cached
    try cache.preShatter(pattern2);
    try testing.expectEqual(@as(usize, 1), cache.shards.count());
}
