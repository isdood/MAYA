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

/// Represents a 4D pattern with GLIMMER encoding support
pub const Pattern = struct {
    data: []f32,  // Using f32 for GLIMMER color channels and intensity
    width: u32,
    height: u32,
    depth: u32 = 1,  // Default to 1 for backward compatibility
    time_steps: u32 = 1,  // Default to 1 for static patterns
    channels: u32 = 4,    // RGBA by default
    owns_data: bool,
    
    // GLIMMER encoding parameters
    glimmer_scale: f32 = 1.0,  // Intensity scaling
    glimmer_phase: f32 = 0.0,  // Phase offset for temporal patterns
    
    /// Creates a new 4D pattern that owns its data
    pub fn create(allocator: Allocator, data: []const f32, width: u32, height: u32, depth: u32, time_steps: u32) !*@This() {
        const pattern = try allocator.create(@This());
        const data_copy = try allocator.dupe(f32, data);
        
        pattern.* = .{
            .data = data_copy,
            .width = width,
            .height = height,
            .depth = depth,
            .time_steps = time_steps,
            .channels = 4, // Default to RGBA
            .owns_data = true,
        };
        
        return pattern;
    }
    
    /// Creates a new pattern from raw bytes (for backward compatibility)
    pub fn fromBytes(allocator: Allocator, data: []const u8, width: u32, height: u32) !*@This() {
        const pattern = try allocator.create(@This());
        const float_data = try allocator.alloc(f32, data.len);
        
        // Convert u8 [0-255] to f32 [0.0-1.0]
        for (data, 0..) |byte, i| {
            float_data[i] = @as(f32, @floatFromInt(byte)) / 255.0;
        }
        
        pattern.* = .{
            .data = float_data,
            .width = width,
            .height = height,
            .depth = 1,
            .time_steps = 1,
            .channels = 4,
            .owns_data = true,
        };
        
        return pattern;
    }
    
    /// Creates a 4D pattern that doesn't own its data
    pub fn fromSlice(data: []const f32, width: u32, height: u32, depth: u32, time_steps: u32) @This() {
        return .{
            .data = @constCast(data),
            .width = width,
            .height = height,
            .depth = depth,
            .time_steps = time_steps,
            .channels = 4,
            .owns_data = false,
        };
    }
    
    /// Gets the index into the data array for a 4D coordinate
    pub fn getIndex(self: @This(), x: u32, y: u32, z: u32, t: u32, c: u32) usize {
        return (@as(usize, t) * self.depth * self.height * self.width * self.channels) +
               (@as(usize, z) * self.height * self.width * self.channels) +
               (@as(usize, y) * self.width * self.channels) +
               (@as(usize, x) * self.channels) + c;
    }
    
    /// Gets the value at a 4D coordinate and channel
    pub fn getValue(self: @This(), x: u32, y: u32, z: u32, t: u32, channel: u32) f32 {
        const idx = self.getIndex(x, y, z, t, channel);
        return if (idx < self.data.len) self.data[idx] else 0.0;
    }
    
    /// Sets the value at a 4D coordinate and channel
    pub fn setValue(self: *@This(), x: u32, y: u32, z: u32, t: u32, channel: u32, value: f32) void {
        const idx = self.getIndex(x, y, z, t, channel);
        if (idx < self.data.len) {
            self.data[idx] = value;
        }
    }
    
    /// Frees the pattern's resources if it owns them
    pub fn deinit(self: *@This(), allocator: Allocator) void {
        if (self.owns_data) {
            allocator.free(self.data);
        }
    }
};

/// Parameters for pattern matching with 4D support
pub const PatternMatchParams = struct {
    // Scale parameters
    multi_scale: bool = false,
    min_scale: Vec4 = Vec4.one(),
    max_scale: Vec4 = Vec4.one(),
    scale_step: f32 = 0.1,
    
    // Rotation parameters (in degrees)
    rotation_invariant: bool = false,
    rotation_step: Vec3 = Vec3.one().scale(15.0), // x,y,z rotation steps
    
    // 4D transformation parameters
    enable_4d: bool = false,
    time_warp: f32 = 1.0, // Time scaling factor
    
    // Gravity-well attention parameters
    gravity_well: bool = false,
    well_center: Vec4 = Vec4.zero(),  // Center of attention in 4D space
    well_mass: f32 = 1.0,            // Strength of the gravity well
    well_radius: f32 = 1.0,          // Radius of influence
    
    // Spiral processing parameters
    spiral_processing: bool = false,
    spiral_ratio: f32 = 1.61803398875, // Golden ratio by default
    spiral_turns: u32 = 5,             // Number of spiral turns
    spiral_phase: f32 = 0.0,           // Phase offset for spiral
    
    // Quantum tunneling parameters
    enable_tunneling: bool = false,
    tunneling_probability: f32 = 0.1,  // Base probability of tunneling
    tunneling_distance: f32 = 5.0,     // Maximum tunneling distance
    
    // Pattern matching thresholds
    partial_matching: bool = false,
    min_match_threshold: f32 = 0.7,
    max_scale_diff: f32 = 0.3,
    max_rotation_diff: Vec3 = Vec3.one().scale(15.0),
    
    /// Creates a default 2D matching configuration
    pub fn default2D() @This() {
        return @This(){
            .min_scale = Vec4.new(0.5, 0.5, 1.0, 1.0),
            .max_scale = Vec4.new(2.0, 2.0, 1.0, 1.0),
        };
    }
    
    /// Creates a 4D matching configuration
    pub fn default4D() @This() {
        return @This(){
            .enable_4d = true,
            .min_scale = Vec4.new(0.5, 0.5, 0.5, 0.5),
            .max_scale = Vec4.new(2.0, 2.0, 2.0, 2.0),
            .gravity_well = true,
            .spiral_processing = true,
        };
    }
};

/// 4D vector type for transformations
pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
    
    pub fn new(x: f32, y: f32, z: f32, w: f32) @This() {
        return @This(){ .x = x, .y = y, .z = z, .w = w };
    }
    
    pub fn zero() @This() {
        return @This(){ .x = 0, .y = 0, .z = 0, .w = 0 };
    }
    
    pub fn one() @This() {
        return @This(){ .x = 1, .y = 1, .z = 1, .w = 1 };
    }
    
    pub fn scale(self: @This(), s: f32) @This() {
        return @This(){
            .x = self.x * s,
            .y = self.y * s,
            .z = self.z * s,
            .w = self.w * s,
        };
    }
    
    pub fn length(self: @This()) f32 {
        return @sqrt(self.x*self.x + self.y*self.y + self.z*self.z + self.w*self.w);
    }
    
    pub fn normalize(self: @This()) @This() {
        const len = self.length();
        if (len > 0) {
            return self.scale(1.0 / len);
        }
        return self;
    }
};

/// Parameters for 4D pattern transformation
pub const TransformParams = struct {
    // 4D transformation parameters
    scale: Vec4 = Vec4.one(),
    rotation: Vec4 = Vec4.zero(),  // Rotation angles in degrees for each plane
    translation: Vec4 = Vec4.zero(),
    
    // Pattern matching parameters
    match_params: PatternMatchParams = .{},
    
    /// Creates a unique key for these transformation parameters
    pub fn toKey(self: @This(), allocator: Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, 
            "{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}:{d}", .{
            self.scale.x, self.scale.y, self.scale.z, self.scale.w,
            self.rotation.x, self.rotation.y, self.rotation.z, self.rotation.w,
            self.translation.x, self.translation.y, self.translation.z, self.translation.w
        });
    }
    
    /// Composes two 4D transformations (applies other transformation after this one)
    pub fn compose(self: @This(), other: TransformParams) TransformParams {
        // Combine scales (element-wise multiplication)
        const new_scale = Vec4{
            .x = self.scale.x * other.scale.x,
            .y = self.scale.y * other.scale.y,
            .z = self.scale.z * other.scale.z,
            .w = self.scale.w * other.scale.w,
        };
        
        // Combine rotations (simple addition for now, should use quaternions for 3D rotations)
        const new_rotation = Vec4{
            .x = @mod(self.rotation.x + other.rotation.x, 360.0),
            .y = @mod(self.rotation.y + other.rotation.y, 360.0),
            .z = @mod(self.rotation.z + other.rotation.z, 360.0),
            .w = @mod(self.rotation.w + other.rotation.w, 360.0),
        };
        
        // Combine translations (scale by self's scale)
        const new_translation = Vec4{
            .x = self.translation.x + other.translation.x * self.scale.x,
            .y = self.translation.y + other.translation.y * self.scale.y,
            .z = self.translation.z + other.translation.z * self.scale.z,
            .w = self.translation.w + other.translation.w * self.scale.w,
        };
        
        return TransformParams{
            .scale = new_scale,
            .rotation = new_rotation,
            .translation = new_translation,
            .match_params = other.match_params, // Use the more specific match params
        };
    }
    
    /// Applies gravity-well attention to a 4D point
    pub fn applyGravityWell(self: @This(), pos: Vec4, match_params: PatternMatchParams) Vec4 {
        if (!match_params.gravity_well) return pos;
        
        const center = match_params.well_center;
        const mass = match_params.well_mass;
        const radius = match_params.well_radius;
        
        // Calculate vector to center
        const to_center = Vec4{
            .x = center.x - pos.x,
            .y = center.y - pos.y,
            .z = center.z - pos.z,
            .w = center.w - pos.w,
        };
        
        const dist_sq = to_center.x*to_center.x + to_center.y*to_center.y + 
                        to_center.z*to_center.z + to_center.w*to_center.w;
        const dist = @sqrt(dist_sq);
        
        if (dist > radius || dist < 0.0001) return pos;
        
        // Apply inverse square law force
        const strength = mass / (dist_sq + 0.01); // Add small epsilon to avoid division by zero
        const force = to_center.normalize().scale(strength * (1.0 - dist/radius));
        
        // Apply the force
        return Vec4{
            .x = pos.x + force.x,
            .y = pos.y + force.y,
            .z = pos.z + force.z,
            .w = pos.w + force.w,
        };
    }
    
    /// Samples a point along a Fibonacci spiral in 4D
    pub fn sampleSpiral4D(self: @This(), t: f32, match_params: PatternMatchParams) Vec4 {
        if (!match_params.spiral_processing) {
            return Vec4.zero();
        }
        
        const phi = match_params.spiral_ratio;
        const n = match_params.spiral_turns;
        const phase = match_params.spiral_phase;
        
        // Golden angle in 4D
        const angle = std.math.tau * t * @as(f32, @floatFromInt(n)) + phase;
        const r = t;
        
        // 4D Fibonacci spiral coordinates
        return Vec4{
            .x = r * @sin(angle),
            .y = r * @cos(angle),
            .z = r * @sin(angle * phi),
            .w = r * @cos(angle * phi),
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
        const updateBestResult = struct {
            fn update(
                self_ptr: *PatternTransformCache,
                current: *?*Pattern,
                score: f32,
                new_pattern: *Pattern,
                best_score_ptr: *f32,
            ) !void {
                if (score > best_score_ptr.*) {
                    best_score_ptr.* = score;
                    if (current.*) |prev| {
                        prev.deinit(self_ptr.allocator);
                        self_ptr.allocator.destroy(prev);
                    }
                    current.* = try self_ptr.createPattern(new_pattern.data, new_pattern.width, new_pattern.height);
                }
            }
        };
        
        // Try different scales if multi-scale is enabled
        if (match_params.multi_scale) {
            var scale = match_params.min_scale;
            while (scale <= match_params.max_scale) : (scale += match_params.scale_step) {
                const scaled_params = TransformParams{
                    .scale_x = scale,
                    .scale_y = scale,
                    .rotation = params.rotation,
                    .translate_x = params.translate_x,
                    .translate_y = params.translate_y,
                    .match_params = params.match_params,
                };
                
                const transformed = try self.applySimpleTransform(pattern, scaled_params);
                defer {
                    transformed.deinit(self.allocator);
                    self.allocator.destroy(transformed);
                }
                
                const score = self.calculateMatchScore(transformed, pattern);
                try updateBestResult.update(
                    self, &best_result, score, transformed, &best_score
                );
            }
        }
        
        // Try different rotations if rotation-invariant is enabled
        if (match_params.rotation_invariant) {
            var rotation: f32 = 0.0;
            while (rotation < 360.0) : (rotation += match_params.rotation_step) {
                const rotated_params = TransformParams{
                    .scale_x = params.scale_x,
                    .scale_y = params.scale_y,
                    .rotation = rotation,
                    .translate_x = params.translate_x,
                    .translate_y = params.translate_y,
                    .match_params = params.match_params,
                };
                
                const transformed = try self.applySimpleTransform(pattern, rotated_params);
                defer {
                    transformed.deinit(self.allocator);
                    self.allocator.destroy(transformed);
                }
                
                const score = self.calculateMatchScore(transformed, pattern);
                try updateBestResult.update(
                    self, &best_result, score, transformed, &best_score
                );
            }
        }
        
        // Handle partial pattern matching
        if (match_params.partial_matching) {
            const window_width = @max(1, @as(u32, @intFromFloat(@as(f32, @floatFromInt(pattern.width)) * 
                (1.0 - match_params.max_scale_diff))));
            const window_height = @max(1, @as(u32, @intFromFloat(@as(f32, @floatFromInt(pattern.height)) * 
                (1.0 - match_params.max_scale_diff))));
            
            // Simplified partial matching - just return the best matching window
            // In a real implementation, this would use more sophisticated pattern matching
            const partial_params = TransformParams{
                .scale_x = params.scale_x * 0.8, // Example: slightly scaled down
                .scale_y = params.scale_y * 0.8,
                .rotation = params.rotation,
                .translate_x = params.translate_x,
                .translate_y = params.translate_y,
                .match_params = .{},
            };
            
            const partial_result = try self.applySimpleTransform(pattern, partial_params);
            defer {
                partial_result.deinit(self.allocator);
                self.allocator.destroy(partial_result);
            }
            
            const score = self.calculateMatchScore(partial_result, pattern);
            if (score >= match_params.min_match_threshold) {
                try updateBestResult.update(
                    self, &best_result, score, partial_result, &best_score
                );
            }
        }
        
        // Return the best result or fall back to simple transform
        if (best_result) |result| {
            return try self.createPattern(result.data, result.width, result.height);
        }
        
        // Fallback to simple transformation if no good match found
        return try self.applySimpleTransform(pattern, params);
    }
    
    /// Calculates a match score between two patterns (simplified implementation)
    fn calculateMatchScore(self: *@This(), a: *const Pattern, b: *const Pattern) f32 {
        _ = self; // Unused parameter
        // This is a simplified implementation that just compares dimensions
        // In a real implementation, this would use more sophisticated pattern matching
        const size_ratio = @as(f32, @floatFromInt(a.width * a.height)) / 
                          @as(f32, @floatFromInt(b.width * b.height));
        return 1.0 / (1.0 + @abs(size_ratio - 1.0));
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

