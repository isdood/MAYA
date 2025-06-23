const std = @import("std");
const pattern_serialization = @import("pattern_serialization.zig");
const pattern_memory = @import("pattern_memory.zig");

/// Global memory pool for pattern allocation
var global_pool: ?*pattern_memory.PatternPool = null;

/// Initialize the global pattern memory pool
pub fn initGlobalPool(allocator: std.mem.Allocator) !void {
    if (global_pool == null) {
        global_pool = try pattern_memory.PatternPool.init(allocator, .{
            .initial_capacity = 128,
            .max_pattern_size = 4 * 1024 * 1024, // 4MB max pattern size
            .thread_safe = true,
        });
    }
}

/// Deinitialize the global pattern memory pool
pub fn deinitGlobalPool() void {
    if (global_pool) |pool| {
        pool.deinit();
        global_pool = null;
    }
}

pub const Pattern = struct {
    /// The pixel data of the pattern
    data: []u8,
    /// Width of the pattern in pixels
    width: usize,
    /// Height of the pattern in pixels
    height: usize,
    /// Pattern complexity score
    complexity: f64 = 0.0,
    /// Pattern stability score
    stability: f64 = 0.0,
    /// Pattern type
    pattern_type: PatternType,
    /// Pattern metadata
    metadata: PatternMetadata,
    /// Allocator for this pattern
    allocator: std.mem.Allocator,

    /// Initialize a new pattern
    pub fn init(allocator: std.mem.Allocator, data: []u8, width: usize, height: usize) !*Pattern {
        const self = try allocator.create(Pattern);
        self.* = .{
            .data = data,
            .width = width,
            .height = height,
            .pattern_type = .Visual,
            .metadata = .{
                .created_at = std.time.timestamp(),
                .updated_at = std.time.timestamp(),
                .source = "",
                .version = "1.0",
                .tags = &[_][]const u8{},
            },
            .allocator = allocator,
        };
        return self;
    }

    /// Deinitialize the pattern
    pub fn deinit(self: *Pattern) void {
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }

    /// Create a view of a pattern region
    pub fn createView(self: *const Pattern, x: usize, y: usize, width: usize, height: usize) Pattern {
        const start = y * self.width * 4 + x * 4;
        const end = start + height * width * 4;
        return .{
            .data = self.data[start..end],
            .width = width,
            .height = height,
            .pattern_type = self.pattern_type,
            .metadata = self.metadata,
            .allocator = self.allocator,
        };
    }

    /// Transform pattern in place
    pub fn transformInPlace(self: *Pattern, transform_fn: fn ([]u8) void) !*Pattern {
        transform_fn(self.data);
        return self;
    }

    /// Calculate Hamming distance between two patterns
    pub fn calculateHammingDistance(data1: []const u8, data2: []const u8) f64 {
        if (data1.len != data2.len) return 1.0;
        
        var distance: f64 = 0.0;
        const vector_size = 16;
        
        // Process in chunks of vector_size
        for (0..data1.len/vector_size) |i| {
            const vec1 = @as(@Vector(vector_size, u8), data1[i*vector_size..][0..vector_size].*);
            const vec2 = @as(@Vector(vector_size, u8), data2[i*vector_size..][0..vector_size].*);
            const diff = vec1 != vec2;
            distance += @popCount(@bitCast(u32, @as(u32, diff)));
        }
        
        // Process remaining elements
        const remaining = data1.len % vector_size;
        if (remaining > 0) {
            const vec1 = @as(@Vector(remaining, u8), data1[data1.len-remaining..].*);
            const vec2 = @as(@Vector(remaining, u8), data2[data2.len-remaining..].*);
            const diff = vec1 != vec2;
            distance += @popCount(@bitCast(u32, @as(u32, diff)));
        }
        
        return distance / data1.len;
    }

    /// Serialize pattern to JSON
    pub fn toJson(self: *const Pattern) ![]const u8 {
        return try pattern_serialization.serializeToJson(self.allocator, self);
    }

    /// Deserialize a pattern from a JSON string
    pub fn fromJson(allocator: std.mem.Allocator, json: []const u8) !*Pattern {
        return try pattern_serialization.deserializeFromJson(allocator, json);
    }
};

pub const Pattern = struct {
    /// The pixel data of the pattern
    data: []u8,
    /// Width of the pattern in pixels
    width: usize,
    /// Height of the pattern in pixels
    height: usize,
    /// Type of the pattern
    pattern_type: PatternType,
    /// Complexity score of the pattern (0.0 to 1.0)
    complexity: f64,
    /// Stability score of the pattern (0.0 to 1.0)
    stability: f64,
    /// Allocator used for this pattern's memory
    allocator: std.mem.Allocator,

    pub const PatternType = enum {
        Quantum,
        Visual,
        Hybrid,
        Unknown,
    };

    /// Initialize a new pattern with the given data and dimensions
    /// Uses the global memory pool if available and appropriate
    pub fn init(allocator: std.mem.Allocator, data: []const u8, width: usize, height: usize) !*Pattern {
        const pool = global_pool;
        const size = width * height * 4; // Assuming 4 channels (RGBA)
        
        // For large patterns or if pool is disabled, allocate directly
        if (pool == null or size > pool.?.config.max_pattern_size) {
            const self = try allocator.create(Pattern);
            self.* = .{
                .data = try allocator.dupe(u8, data),
                .width = width,
                .height = height,
                .pattern_type = .Unknown,
                .complexity = 0.0,
                .stability = 0.0,
                .allocator = allocator,
            };
            return self;
        }
        
        // Use memory pool
        const self = try pool.?.getPattern(width, height, 4);
        @memcpy(self.data[0..data.len], data);
        self.pattern_type = .Unknown;
        self.complexity = 0.0;
        self.stability = 0.0;
        return self;
    }
    
    /// Initialize a new pattern with the given dimensions and channels
    /// Uses the global memory pool if available
    pub fn initPattern(allocator: std.mem.Allocator, width: u32, height: u32, channels: u8) error{OutOfMemory}!*Pattern {
        const pool = global_pool;
        const w = @as(usize, @intCast(width));
        const h = @as(usize, @intCast(height));
        const size = w * h * @as(usize, channels);
        
        // Use memory pool if available and pattern is not too large
        if (pool != null and size <= pool.?.config.max_pattern_size) {
            return pool.?.getPattern(w, h, channels);
        }
        
        // Fall back to direct allocation
        const data = try allocator.alloc(u8, size);
        const pattern = try allocator.create(Pattern);
        pattern.* = .{
            .data = data,
            .width = w,
            .height = h,
            .pattern_type = .Visual,
            .complexity = 0.0,
            .stability = 0.0,
            .allocator = allocator,
        };
        
        return pattern;
    }

    pub fn deinit(self: *Pattern, allocator: std.mem.Allocator) void {
        const pool = global_pool;
        
        // If using memory pool and pattern is within size limits
        if (pool != null and self.data.len <= pool.?.config.max_pattern_size) {
            pool.?.releasePattern(self);
        } else {
            // Direct deallocation
            allocator.free(self.data);
            allocator.destroy(self);
        }
    }

    pub fn analyze(self: *Pattern) void {
        // Basic pattern analysis placeholder
        self.complexity = calculateComplexity(self.data);
        self.stability = calculateStability(self.data);
    }

    fn calculateComplexity(data: []const u8) f64 {
        // Placeholder complexity calculation
        return @as(f64, @floatFromInt(data.len)) / 100.0;
    }

    fn calculateStability(data: []const u8) f64 {
        // Placeholder stability calculation
        var sum: u32 = 0;
        for (data) |byte| {
            sum += byte;
        }
        return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(data.len));
    }

    /// Save the pattern to a file
    pub fn saveToFile(self: *const Pattern, file_path: []const u8) !void {
        try pattern_serialization.savePatternToFile(self.allocator, self, file_path);
    }

    /// Load a pattern from a file
    pub fn loadFromFile(allocator: std.mem.Allocator, file_path: []const u8) !*Pattern {
        return try pattern_serialization.loadPatternFromFile(allocator, file_path);
    }

    /// Create a zero-copy view of a portion of this pattern
    pub fn createView(self: *const Pattern, x: usize, y: usize, width: usize, height: usize) Pattern {
        return pattern_memory.ZeroCopyOps.createView(self, x, y, width, height);
    }
    
    /// Apply a transformation in-place if possible, or create a new pattern if necessary
    pub fn transformInPlace(
        self: *Pattern,
        transform_fn: fn ([]u8) void
    ) !*Pattern {
        return try pattern_memory.ZeroCopyOps.transformInPlace(self, transform_fn);
    }
    
    /// Serialize the pattern to a JSON string
    pub fn toJson(self: *const Pattern) ![]const u8 {
        return try pattern_serialization.serializeToJson(self.allocator, self);
    }

    /// Deserialize a pattern from a JSON string
    pub fn fromJson(allocator: std.mem.Allocator, json_str: []const u8) !*Pattern {
        return try pattern_serialization.deserializeFromJson(allocator, json_str);
    }
};
