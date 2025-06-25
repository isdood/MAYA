const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;
const Thread = std.Thread;
const time = std.time;
const net = std.net;
const http = std.http;
const json = std.json;

// Default HTTP server port for metrics
const DEFAULT_METRICS_PORT: u16 = 8080;
// Default metrics update interval in seconds
const DEFAULT_METRICS_UPDATE_INTERVAL: u64 = 60;

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

/// Parameters for pattern matching
pub const PatternMatchParams = struct {
    /// Enable multi-scale pattern matching
    multi_scale: bool = false,
    /// Minimum scale factor for multi-scale matching (e.g., 0.5 for half size)
    min_scale: f32 = 0.5,
    /// Maximum scale factor for multi-scale matching (e.g., 2.0 for double size)
    max_scale: f32 = 2.0,
    /// Scale step size for multi-scale matching
    scale_step: f32 = 0.1,
    
    /// Enable rotation-invariant matching
    rotation_invariant: bool = false,
    /// Rotation step in degrees for rotation-invariant matching
    rotation_step: f32 = 15.0,
    
    /// Enable partial pattern matching
    partial_matching: bool = false,
    /// Minimum match threshold for partial matching (0.0 to 1.0)
    min_match_threshold: f32 = 0.7,
    /// Maximum allowed scale difference for partial matching (0.0 to 1.0)
    max_scale_diff: f32 = 0.3,
    /// Maximum allowed rotation difference for partial matching in degrees
    max_rotation_diff: f32 = 15.0,
};

/// Parameters for pattern transformation
pub const TransformParams = struct {
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
    rotation: f32 = 0.0, // in degrees
    translate_x: i32 = 0,
    translate_y: i32 = 0,
    
    /// Pattern matching parameters
    match_params: PatternMatchParams = .{},
    
    /// Creates a unique key for these transformation parameters
    pub fn toKey(self: @This(), allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{d}:{d}:{d}:{d}:{d}:{d}", .{
            self.scale_x, 
            self.scale_y, 
            self.rotation,
            self.translate_x,
            self.translate_y,
            @as(u32, @bitCast(self.match_params)),
        });
    }
    
    /// Composes two transformations (applies other transformation after this one)
    pub fn compose(self: @This(), other: TransformParams) TransformParams {
        // For simplicity, just combine translations for now
        // In a more complete implementation, we'd handle the full matrix composition
        return TransformParams{
            .scale_x = self.scale_x * other.scale_x,
            .scale_y = self.scale_y * other.scale_y,
            .rotation = @mod(self.rotation + other.rotation, 360.0),
            .translate_x = self.translate_x + @as(i32, @intFromFloat(@as(f32, @floatFromInt(other.translate_x)) * self.scale_x)),
            .translate_y = self.translate_y + @as(i32, @intFromFloat(@as(f32, @floatFromInt(other.translate_y)) * self.scale_y)),
        };
    }
};

/// Statistics for the pattern transform cache
pub const CacheStats = struct {
    // Basic metrics
    hits: u64 = 0,
    misses: u64 = 0,
    evictions: u64 = 0,
    total_cached_bytes: u64 = 0,
    peak_cached_bytes: u64 = 0,
    
    // Transformation metrics
    total_transform_time_ns: u64 = 0,
    transform_count: u64 = 0,
    
    // Timestamp for last reset
    last_reset_timestamp: i64 = 0,
    
    // Calculate hit ratio (hits / (hits + misses))
    pub fn hitRatio(self: @This()) f64 {
        const total = @as(f64, @floatFromInt(self.hits + self.misses));
        return if (total > 0) @as(f64, @floatFromInt(self.hits)) / total else 0.0;
    }
    
    /// Returns the average transformation time in nanoseconds
    pub fn avgTransformTimeNs(self: @This()) u64 {
        const total_transforms = self.hits + self.misses;
        return if (total_transforms > 0) self.total_transform_time_ns / total_transforms else 0;
    }
    
    /// Exports the stats in Prometheus format
    pub fn exportPrometheus(self: @This(), writer: anytype) !void {
        try writer.print("pattern_transform_cache_hits{type=\"total\"} {d}\n", .{self.hits});
        try writer.print("pattern_transform_cache_misses{type=\"total\"} {d}\n", .{self.misses});
        try writer.print("pattern_transform_cache_evictions{type=\"total\"} {d}\n", .{self.evictions});
        try writer.print("pattern_transform_cache_total_cached_bytes{type=\"total\"} {d}\n", .{self.total_cached_bytes});
        try writer.print("pattern_transform_cache_peak_cached_bytes{type=\"total\"} {d}\n", .{self.peak_cached_bytes});
        try writer.print("pattern_transform_cache_total_transform_time_ns{type=\"total\"} {d}\n", .{self.total_transform_time_ns});
        try writer.print("pattern_transform_cache_transform_count{type=\"total\"} {d}\n", .{self.transform_count});
    }
};

/// Configuration for the metrics HTTP server
pub const MetricsServerConfig = struct {
    enabled: bool = false,
    port: u16 = DEFAULT_METRICS_PORT,
    update_interval_seconds: u64 = DEFAULT_METRICS_UPDATE_INTERVAL,
};

/// Cache for transformed patterns with metrics and statistics
pub const PatternTransformCache = struct {
    allocator: Allocator,
    lru: StringArrayHashMap(*Pattern),
    lru_keys: ArrayList([]const u8),
    entry_timestamps: StringArrayHashMap(u64), // Key -> timestamp_ns
    mutex: Thread.Mutex,
    stats: CacheStats = .{},
    max_entries: usize = 1000,
    max_size_bytes: u64 = 0, // 0 means no size limit
    current_size_bytes: u64 = 0,
    ttl_ns: u64 = 0, // 0 means no TTL
    metrics_config: MetricsServerConfig = .{},
    metrics_server: ?*http.Server = null,
    metrics_server_thread: ?Thread = null,
    
    /// Starts the metrics HTTP server if enabled in the configuration
    pub fn startMetricsServer(self: *@This()) !void {
        if (!self.metrics_config.enabled) return;
        
        // Initialize the HTTP server
        var server = try self.allocator.create(http.Server);
        errdefer self.allocator.destroy(server);
        
        try server.listen(try net.Address.parseIp("0.0.0.0", self.metrics_config.port));
        
        // Store the server reference
        self.metrics_server = server;
        
        // Start the server in a new thread
        self.metrics_server_thread = try Thread.spawn(.{}, handleMetricsRequests, .{self});
        std.log.info("Metrics server started on port {}", .{self.metrics_config.port});
    }
    
    /// Stops the metrics HTTP server if it's running
    pub fn stopMetricsServer(self: *@This()) void {
        if (self.metrics_server) |server| {
            server.deinit();
            self.metrics_server = null;
        }
        
        if (self.metrics_server_thread) |*thread| {
            thread.join();
            self.metrics_server_thread = null;
        }
    }
    
    /// Handles incoming HTTP requests for metrics
    fn handleMetricsRequests(self: *@This()) void {
        const server = self.metrics_server orelse return;
        
        while (true) {
            var response = server.accept(.{
                .allocator = self.allocator,
            }) catch |err| {
                std.log.err("Error accepting connection: {}", .{err});
                continue;
            };
            
            defer response.deinit();
            
            response.wait() catch |err| {
                std.log.err("Error waiting for request: {}", .{err});
                continue;
            };
            
            // Only handle GET requests to /metrics
            if (std.mem.eql(u8, response.request.target, "/metrics") and 
                response.request.method == .GET) {
                
                // Get a snapshot of the current stats
                const stats = self.getStats();
                
                // Format the response
                var buffer: [8192]u8 = undefined;
                var fbs = std.io.fixedBufferStream(&buffer);
                
                // Write Prometheus metrics
                stats.exportPrometheus(fbs.writer()) catch |err| {
                    std.log.err("Error writing metrics: {}", .{err});
                    _ = response.respond("Internal Server Error", .{ .status = .internal_server_error });
                    continue;
                };
                
                // Send the response
                _ = response.respond(fbs.getWritten(), .{
                    .status = .ok,
                    .content_type = "text/plain; version=0.0.4"
                }) catch |err| {
                    std.log.err("Error sending response: {}", .{err});
                };
            } else {
                // Return 404 for unknown paths
                _ = response.respond("Not Found", .{ .status = .not_found }) catch |err| {
                    std.log.err("Error sending 404: {}", .{err});
                };
            }
        }
    }
    
    /// Initializes a new PatternTransformCache with default settings
    pub fn init(allocator: Allocator, max_entries: usize) !@This() {
        // Allocate the mutex on the heap since we need to pass a mutable reference to it
        const mutex = try allocator.create(Thread.Mutex);
        mutex.* = Thread.Mutex{};
        
        var cache = @This(){
            .allocator = allocator,
            .lru = StringArrayHashMap(*Pattern).init(allocator),
            .lru_keys = ArrayList([]const u8).init(allocator),
            .entry_timestamps = StringArrayHashMap(u64).init(allocator),
            .mutex = mutex.*,
            .max_entries = max_entries,
            .max_size_bytes = 0,
            .current_size_bytes = 0,
            .ttl_ns = 0,
        };
        errdefer cache.deinit();
        
        return cache;
    }
    
    /// Initializes a new PatternTransformCache with the given options
    pub fn initWithOptions(
        allocator: Allocator,
        max_entries: usize,
        max_size_mb: ?usize,
        default_ttl_seconds: ?u64
    ) !@This() {
        // Allocate the mutex on the heap since we need to pass a mutable reference to it
        const mutex = try allocator.create(Thread.Mutex);
        mutex.* = Thread.Mutex{};
        
        const max_size_bytes = if (max_size_mb) |mb| mb * 1024 * 1024 else 0;
        const ttl_ns = if (default_ttl_seconds) |s| s * 1_000_000_000 else 0;
        
        var cache = @This(){
            .allocator = allocator,
            .lru = StringArrayHashMap(*Pattern).init(allocator),
            .lru_keys = ArrayList([]const u8).init(allocator),
            .entry_timestamps = StringArrayHashMap(u64).init(allocator),
            .max_entries = max_entries,
            .max_size_bytes = max_size_bytes,
            .default_ttl_ns = ttl_ns,
            .current_size_bytes = 0,
            .stats = .{},
            .mutex = mutex,
        };
        errdefer cache.deinit();
        
        return cache;
    }
    
    /// Deinitializes the cache, freeing all resources
    pub fn deinit(self: *@This()) void {
        // Free all cached patterns and their data
        var it = self.lru.iterator();
        while (it.next()) |entry| {
            const pattern = entry.value_ptr.*;
            if (pattern.owns_data) {
                self.allocator.free(pattern.data);
            }
            self.allocator.destroy(pattern);
            self.allocator.free(entry.key_ptr.*);
        }
        
        // Free the LRU map, timestamps, and keys list
        self.lru.deinit();
        self.entry_timestamps.deinit();
        
        // Free all keys in the LRU keys list
        for (self.lru_keys.items) |key| {
            self.allocator.free(key);
        }
        self.lru_keys.deinit();
        
        // Free the mutex
        self.allocator.destroy(self.mutex);
    }
    
    /// Evicts entries based on time-to-live and size constraints
    /// Returns the number of entries evicted
    fn evictIfNeeded(self: *@This()) !usize {
        var evicted: usize = 0;
        const now = time.nanoTimestamp();
        
        // Check if we need to evict based on entry count
        while (self.lru.count() >= self.max_entries and self.lru_keys.items.len > 0) {
            try self.evictOne();
            evicted += 1;
        }
        
        // Check if we need to evict based on size
        while (self.max_size_bytes > 0 and 
               self.current_size_bytes > self.max_size_bytes and 
               self.lru_keys.items.len > 0) {
            try self.evictOne();
            evicted += 1;
        }
        
        // Check for expired entries if TTL is enabled
        if (self.default_ttl_ns > 0) {
            var i: usize = 0;
            while (i < self.lru_keys.items.len) {
                const key = self.lru_keys.items[i];
                if (self.entry_timestamps.get(key)) |timestamp| {
                    if (now - @as(i64, @intCast(timestamp)) > @as(i64, @intCast(self.default_ttl_ns))) {
                        // Entry has expired, evict it
                        try self.evictByKey(key);
                        evicted += 1;
                        continue; // Don't increment i as we removed an item
                    }
                }
                i += 1;
            }
        }
        
        return evicted;
    }
    
    /// Evicts a single entry (the least recently used)
    fn evictOne(self: *@This()) !void {
        if (self.lru_keys.pop()) |key| {
            defer self.allocator.free(key);
            try self.evictByKey(key);
        }
    }
    
    /// Evicts a specific entry by key
    fn evictByKey(self: *@This(), key: []const u8) !void {
        if (self.lru.fetchSwapRemove(key)) |kv| {
            const pattern = kv.value;
            
            // Update size tracking
            if (self.max_size_bytes > 0) {
                });
            }
        }
    }
    
    /// Moves a key to the front of the LRU list
    fn moveToFront(self: *@This(), key: []const u8) void {
        // Find the key in the LRU list and move it to the front
        for (self.lru_keys.items, 0..) |k, i| {
            if (std.mem.eql(u8, k, key)) {
                // Move to front by removing and re-inserting
                const item = self.lru_keys.orderedRemove(i);
                self.lru_keys.insert(0, item) catch {
                    // If insert fails, put it back where it was
                    self.lru_keys.insert(i, item) catch unreachable;
                    return;
                };
                break;
            }
        }
    }
    
    /// Gets a transformed pattern from the cache or applies the transformation if not found
    pub fn getOrTransform(self: *@This(), pattern: *const Pattern, params: TransformParams) !*Pattern {
        var timer = time.Timer.start() catch unreachable;
        defer {
            const elapsed = timer.read();
            var self_mut = self;
            self_mut.mutex.lock();
            defer self_mut.mutex.unlock();
            
            // Update metrics
            self_mut.stats.total_transform_time_ns += elapsed;
            self_mut.stats.transform_count += 1;
            
            // Log performance periodically
            if (self_mut.stats.transform_count % 100 == 0) {
                const avg_time_ms = @as(f64, @floatFromInt(self_mut.stats.total_transform_time_ns)) / 
                                 (@as(f64, @floatFromInt(self_mut.stats.transform_count)) * 1_000_000.0);
                const hit_ratio = self_mut.stats.hitRatio() * 100.0;
                
                std.log.info("Cache stats - Hits: {}, Misses: {}, Hit Ratio: {d:.2}%, Avg Transform Time: {d:.3}ms", .{
                    self_mut.stats.hits,
                    self_mut.stats.misses,
                    hit_ratio,
                    avg_time_ms,
                });
                
                // Log cache size if size limits are enabled
                if (self_mut.max_size_bytes > 0) {
                    const mb_used = @as(f64, @floatFromInt(self_mut.stats.total_cached_bytes)) / (1024.0 * 1024.0);
                    const mb_max = @as(f64, @floatFromInt(self_mut.max_size_bytes)) / (1024.0 * 1024.0);
                    const usage_percent = (mb_used / mb_max) * 100.0;
                    
                    std.log.info("Cache usage: {d:.1}MB / {d:.1}MB ({d:.1}%)", .{
                        mb_used,
                        mb_max,
                        usage_percent,
                    });
                }
            }
        }
        
        // Generate a cache key from the transformation parameters
        const key = try params.toKey(self.allocator);
        defer self.allocator.free(key);
        
        // Check cache with lock held
        {
            var self_mut = self;
            self_mut.mutex.lock();
            defer self_mut.mutex.unlock();
            
            if (self_mut.lru.get(key)) |cached| {
                // Cache hit
                self_mut.stats.hits += 1;
                self_mut.moveToFront(key);
                
                // Log cache hit rate periodically
                const total_requests = self_mut.stats.hits + self_mut.stats.misses;
                if (total_requests % 100 == 0) {
                    const hit_ratio = self_mut.stats.hitRatio() * 100.0;
                    std.log.debug("Cache hit: {d:.1}% ({} hits, {} misses)", .{
                        hit_ratio,
                        self_mut.stats.hits,
                        self_mut.stats.misses,
                    });
                }
            
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
            } else {
                // Cache miss
                self_mut.stats.misses += 1;
                
                // Log cache miss rate periodically
                const total_requests = self_mut.stats.hits + self_mut.stats.misses;
                if (total_requests % 100 == 0) {
                    const hit_ratio = self_mut.stats.hitRatio() * 100.0;
                    std.log.debug("Cache miss - current hit rate: {d:.1}% ({} hits, {} misses)", .{
                        hit_ratio,
                        self_mut.stats.hits,
                        self_mut.stats.misses,
                    });
                }
            }
        }
        
        // Not in cache, apply transformation
        const transformed = if (params.match_params.multi_scale || params.match_params.rotation_invariant || params.match_params.partial_matching)
            try self.applyAdvancedTransform(pattern, params)
        else
            try self.applySimpleTransform(pattern, params);
            
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
        
        // Add to cache
        try self.addToCache(key, cached_pattern, cached_data.len);
        
        // Log cache size periodically if size limits are enabled
        if (self.max_size_bytes > 0 && self.stats.total_cached_bytes % (10 * 1024 * 1024) == 0) {
            const mb_used = @as(f64, @floatFromInt(self.stats.total_cached_bytes)) / (1024.0 * 1024.0);
            const mb_max = @as(f64, @floatFromInt(self.max_size_bytes)) / (1024.0 * 1024.0);
            const usage_percent = (mb_used / mb_max) * 100.0;
            
            std.log.info("Cache usage: {d:.1}MB / {d:.1}MB ({d:.1}%)", .{
                mb_used,
                mb_max,
                usage_percent,
            });
        }
        
        // Return the transformed pattern (caller is responsible for freeing it)
        return transformed;
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

