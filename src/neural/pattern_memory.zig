//! Memory management utilities for pattern processing
//! Implements memory pooling and zero-copy operations for patterns

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Pattern = @import("pattern.zig").Pattern;

/// Configuration for the pattern memory pool
pub const PoolConfig = struct {
    /// Initial number of patterns to pre-allocate
    initial_capacity: usize = 64,
    /// Maximum size of a pattern to be stored in the pool (in bytes)
    max_pattern_size: usize = 1024 * 1024, // 1MB
    /// Whether to enable thread-safe operations
    thread_safe: bool = true,
};

/// A memory pool for pattern allocation
pub const PatternPool = struct {
    allocator: Allocator,
    config: PoolConfig,
    free_lists: std.ArrayListUnmanaged([]u8) = .{},
    mutex: if (builtin.single_threaded) void else std.Thread.Mutex = .{},
    
    /// Initialize a new pattern pool
    pub fn init(allocator: Allocator, config: PoolConfig) !*@This() {
        const self = try allocator.create(@This());
        self.* = .{
            .allocator = allocator,
            .config = config,
        };
        try self.free_lists.ensureTotalCapacity(allocator, config.initial_capacity);
        return self;
    }
    
    /// Deinitialize the pattern pool
    pub fn deinit(self: *@This()) void {
        self.lock();
        defer self.unlock();
        
        for (self.free_lists.items) |block| {
            self.allocator.free(block);
        }
        self.free_lists.deinit(self.allocator);
        self.allocator.destroy(self);
    }
    
    /// Get a pattern from the pool or allocate a new one
    pub fn getPattern(self: *@This(), width: usize, height: usize, channels: u8) !*Pattern {
        const size = width * height * channels;
        
        // For large patterns or if pool is disabled, allocate directly
        if (size > self.config.max_pattern_size) {
            return try Pattern.initPattern(self.allocator, @intCast(width), @intCast(height), channels);
        }
        
        self.lock();
        defer self.unlock();
        
        // Try to find a suitable block in the free list
        if (self.free_lists.popOrNull()) |block| {
            if (block.len >= size) {
                const pattern = try self.allocator.create(Pattern);
                pattern.* = .{
                    .data = block[0..size],
                    .width = width,
                    .height = height,
                    .pattern_type = .Visual,
                    .complexity = 0.0,
                    .stability = 0.0,
                    .allocator = self.allocator,
                };
                return pattern;
            }
            // Block is too small, free it
            self.allocator.free(block);
        }
        
        // No suitable block found, allocate a new one
        return try Pattern.initPattern(self.allocator, @intCast(width), @intCast(height), channels);
    }
    
    /// Return a pattern to the pool
    pub fn releasePattern(self: *@This(), pattern: *Pattern) void {
        // Don't pool large patterns
        if (pattern.data.len > self.config.max_pattern_size) {
            pattern.deinit(self.allocator);
            return;
        }
        
        self.lock();
        defer self.unlock();
        
        // Store the data block in the free list
        if (self.free_lists.items.len < self.config.initial_capacity * 2) {
            if (self.free_lists.append(self.allocator, pattern.data)) |_| {
                // Successfully added to free list, prevent deallocation
                pattern.data = undefined;
                self.allocator.destroy(pattern);
                return;
            } else |_| {
                // If we can't add to free list, just deallocate
            }
        }
        
        // Free the pattern if we couldn't pool it
        pattern.deinit(self.allocator);
    }
    
    inline fn lock(self: *@This()) void {
        if (!builtin.single_threaded and self.config.thread_safe) {
            self.mutex.lock();
        }
    }
    
    inline fn unlock(self: *@This()) void {
        if (!builtin.single_threaded and self.config.thread_safe) {
            self.mutex.unlock();
        }
    }
};

/// Zero-copy pattern operations
pub const ZeroCopyOps = struct {
    /// Create a view into a pattern without copying data
    pub fn createView(original: *const Pattern, x: usize, y: usize, width: usize, height: usize) Pattern {
        const start = (y * original.width + x) * 4; // Assuming 4 channels (RGBA)
        const end = start + (width * height * 4);
        
        return .{
            .data = original.data[start..end],
            .width = width,
            .height = height,
            .pattern_type = original.pattern_type,
            .complexity = original.complexity,
            .stability = original.stability,
            .allocator = original.allocator,
        };
    }
    
    /// Apply a transformation in-place if possible, or create a new pattern if necessary
    pub fn transformInPlace(
        pattern: *Pattern,
        transform_fn: fn ([]u8) void
    ) !*Pattern {
        // Check if we can modify in-place
        if (std.meta.isReadOnly(pattern.data.ptr)) {
            // Can't modify in-place, create a copy
            const new_pattern = try Pattern.init(
                pattern.allocator,
                pattern.data,
                pattern.width,
                pattern.height
            );
            transform_fn(new_pattern.data);
            return new_pattern;
        }
        
        // Modify in-place
        transform_fn(pattern.data);
        return pattern;
    }
};

// Tests
const testing = std.testing;

test "PatternPool basic allocation" {
    var pool = try PatternPool.init(testing.allocator, .{});
    defer pool.deinit();
    
    const pattern = try pool.getPattern(32, 32, 4);
    defer pool.releasePattern(pattern);
    
    try testing.expectEqual(@as(usize, 32), pattern.width);
    try testing.expectEqual(@as(usize, 32), pattern.height);
    try testing.expectEqual(@as(usize, 32 * 32 * 4), pattern.data.len);
}

test "ZeroCopyOps view creation" {
    var pool = try PatternPool.init(testing.allocator, .{});
    defer pool.deinit();
    
    const pattern = try pool.getPattern(32, 32, 4);
    defer pool.releasePattern(pattern);
    
    const view = ZeroCopyOps.createView(pattern, 8, 8, 16, 16);
    try testing.expectEqual(@as(usize, 16), view.width);
    try testing.expectEqual(@as(usize, 16), view.height);
    try testing.expectEqual(@as(usize, 16 * 16 * 4), view.data.len);
}

test "ZeroCopyOps in-place transformation" {
    var pool = try PatternPool.init(testing.allocator, .{});
    defer pool.deinit();
    
    const pattern = try pool.getPattern(32, 32, 4);
    defer pool.releasePattern(pattern);
    
    // Fill with test data
    @memset(pattern.data, 100);
    
    const transform_fn = struct {
        fn transform(data: []u8) void {
            for (data) |*pixel| {
                pixel.* +%= 50;
            }
        }
    }.transform;
    
    const transformed = try ZeroCopyOps.transformInPlace(pattern, transform_fn);
    
    // Verify transformation
    for (transformed.data) |pixel| {
        try testing.expectEqual(@as(u8, 150), pixel);
    }
}
