const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;

/// Represents a pattern that can be transformed
pub const Pattern = struct {
    data: []u8,
    width: u32,
    height: u32,
    owns_data: bool,
    
    /// Creates a new pattern that owns its data
    pub fn create(allocator: Allocator, data: []const u8, width: u32, height: u32) !*@This() {
        const pattern = try allocator.create(@This());
        const data_copy = try allocator.dupe(u8, data);
        
        pattern.* = .{
            .data = data_copy,
            .width = width,
            .height = height,
            .owns_data = true,
        };
        
        return pattern;
    }
    
    /// Creates a pattern that doesn't own its data
    pub fn fromSlice(data: []const u8, width: u32, height: u32) @This() {
        return .{
            .data = @constCast(data),
            .width = width,
            .height = height,
            .owns_data = false,
        };
    }
    
    /// Frees the pattern's resources if it owns them
    pub fn deinit(self: *@This(), allocator: Allocator) void {
        if (self.owns_data) {
            allocator.free(self.data);
        }
    }
};

/// Parameters for pattern transformation
pub const TransformParams = struct {
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
    angle: f32 = 0.0,  // in degrees
    translate_x: i32 = 0,
    translate_y: i32 = 0,
    
    /// Creates a unique key for these parameters
    pub fn toKey(self: @This(), allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{d}:{d}:{d}:{d}:{d}", .{
            self.scale_x,
            self.scale_y,
            self.angle,
            self.translate_x,
            self.translate_y,
        });
    }
};

/// Cache for transformed patterns
pub const PatternTransformCache = struct {
    allocator: Allocator,
    lru: StringArrayHashMap(*Pattern),
    lru_keys: ArrayList([]const u8),
    max_entries: usize,
    
    /// Initializes a new PatternTransformCache
    pub fn init(allocator: Allocator, max_entries: usize) !@This() {
        return .{
            .allocator = allocator,
            .lru = StringArrayHashMap(*Pattern).init(allocator),
            .lru_keys = ArrayList([]const u8).init(allocator),
            .max_entries = max_entries,
        };
    }
    
    /// Deinitializes the cache, freeing all resources
    pub fn deinit(self: *@This()) void {
        // Free all cached patterns and their data
        var it = self.lru.iterator();
        while (it.next()) |entry| {
            // Free the pattern data and the pattern itself
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
            // The key is owned by the hash map and will be freed by lru.deinit()
        }
        
        // Free all keys in the LRU list
        for (self.lru_keys.items) |k| {
            self.allocator.free(k);
        }
        self.lru_keys.clearAndFree();
        
        // Deinitialize the containers
        self.lru.deinit();
        self.lru_keys.deinit();
    }
    
    /// Gets a transformed pattern from cache or applies the transformation
    pub fn getOrTransform(self: *@This(), pattern: *const Pattern, params: TransformParams) !*Pattern {
        // Generate a cache key from the transformation parameters
        const key = try params.toKey(self.allocator);
        defer self.allocator.free(key);
        
        // Check cache
        if (self.lru.get(key)) |cached| {
            // Move to front of LRU
            self.moveToFront(key);
            
            // Return a copy of the cached pattern
            const result = try self.allocator.create(Pattern);
            errdefer self.allocator.destroy(result);
            
            const data_copy = try self.allocator.dupe(u8, cached.data);
            errdefer self.allocator.free(data_copy);
            
            result.* = .{
                .data = data_copy,
                .width = cached.width,
                .height = cached.height,
                .owns_data = true,
            };
            
            return result;
        }
        
        // Not in cache, apply transformation
        const transformed = try self.applyTransform(pattern, params);
        errdefer {
            transformed.deinit(self.allocator);
            self.allocator.destroy(transformed);
        }
        
        // Create a copy of the transformed data for caching
        const cached_data = try self.allocator.dupe(u8, transformed.data);
        errdefer self.allocator.free(cached_data);
        
        const cached_pattern = try self.allocator.create(Pattern);
        errdefer self.allocator.destroy(cached_pattern);
        
        cached_pattern.* = .{
            .data = cached_data,
            .width = transformed.width,
            .height = transformed.height,
            .owns_data = true,
        };
        
        // Create a copy of the key for the cache
        const key_copy = try self.allocator.dupe(u8, key);
        
        // Add to cache - this takes ownership of key_copy and cached_pattern
        if (self.addToCache(key_copy, cached_pattern)) |_| {
            // Successfully added to cache, which now owns the memory
            // The key_copy will be freed when the entry is evicted or cache is deinitialized
        } else |err| {
            // If addToCache fails, we need to clean up the key and pattern
            self.allocator.free(key_copy);
            cached_pattern.deinit(self.allocator);
            self.allocator.destroy(cached_pattern);
            return err;
        }
        
        // Return the transformed pattern (caller is responsible for freeing it)
        return transformed;
    }
    
    /// Applies transformation to a pattern
    fn applyTransform(
        self: *@This(),
        pattern: *const Pattern,
        params: TransformParams,
    ) !*Pattern {
        // For now, just implement basic scaling
        const new_width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(pattern.width)) * params.scale_x));
        const new_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(pattern.height)) * params.scale_y));
        
        // Allocate memory for the new pattern
        const result = try self.allocator.create(Pattern);
        errdefer self.allocator.destroy(result);
        
        const data = try self.allocator.alloc(u8, new_width * new_height * 4);
        errdefer self.allocator.free(data);
        
        // Simple nearest-neighbor scaling
        for (0..new_height) |y| {
            const src_y = y * pattern.height / new_height;
            for (0..new_width) |x| {
                const src_x = x * pattern.width / new_width;
                const src_idx = (src_y * pattern.width + src_x) * 4;
                const dst_idx = (y * new_width + x) * 4;
                
                @memcpy(data[dst_idx..dst_idx+4], pattern.data[src_idx..src_idx+4]);
            }
        }
        
        result.* = .{
            .data = data,
            .width = new_width,
            .height = new_height,
            .owns_data = true,
        };
        
        return result;
    }
    
    /// Adds a pattern to the cache, evicting LRU if necessary
    /// Takes ownership of both key and pattern - they will be freed when evicted or cache is deinitialized
    fn addToCache(self: *@This(), key: []const u8, pattern: *Pattern) !void {
        // Check if we need to evict
        if (self.lru.count() >= self.max_entries and self.lru_keys.items.len > 0) {
            // Remove the least recently used item (last in the list)
            const lru_key = self.lru_keys.orderedRemove(self.lru_keys.items.len - 1);
            if (self.lru.fetchOrderedRemove(lru_key)) |entry| {
                // Clean up the old pattern
                entry.value.deinit(self.allocator);
                self.allocator.destroy(entry.value);
                // The key was already duplicated when added to lru_keys, so we need to free it
                self.allocator.free(lru_key);
            }
        }
        
        // Add to cache - this takes ownership of the key and pattern
        try self.lru.put(key, pattern);
        
        // Insert the key at the front of the LRU list
        // We need to duplicate the key since the hash map takes ownership of the original
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        
        try self.lru_keys.insert(0, key_copy);
    }
    
    /// Helper to create a new pattern instance
    fn createPattern(self: *@This(), data: []const u8, width: u32, height: u32) !*Pattern {
        const pattern = try self.allocator.create(Pattern);
        const data_copy = try self.allocator.dupe(u8, data);
        
        pattern.* = .{
            .data = data_copy,
            .width = width,
            .height = height,
            .owns_data = true,
        };
        
        return pattern;
    }
    
    /// Moves a key to the front of the LRU list
    fn moveToFront(self: *@This(), key: []const u8) void {
        // Find the key in the LRU list
        for (self.lru_keys.items, 0..) |k, i| {
            if (std.mem.eql(u8, k, key)) {
                // Move to front
                const item = self.lru_keys.orderedRemove(i);
                self.lru_keys.insert(0, item) catch {
                    // If insertion fails, just append (shouldn't happen with proper sizing)
                    self.lru_keys.append(item) catch {};
                };
                break;
            }
        }
    }
};

// Tests
const TestContext = struct {
    allocator: Allocator,
    cache: PatternTransformCache,
    
    fn init(allocator: Allocator) !@This() {
        return .{
            .allocator = allocator,
            .cache = try PatternTransformCache.init(allocator, 10),
        };
    }
    
    fn deinit(self: *@This()) void {
        self.cache.deinit();
    }
};

