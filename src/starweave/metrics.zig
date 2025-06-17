const std = @import("std");
const time = std.time;
const Allocator = std.mem.Allocator;
const Atomic = std.atomic.Atomic;
const Mutex = std.Thread.Mutex;
const builtin = @import("builtin");

/// Types of metrics that can be collected
pub const MetricType = enum {
    /// Counter that can only increase
    counter,
    
    /// Gauge that can increase or decrease
    gauge,
    
    /// Histogram for statistical analysis
    histogram,
    
    /// Summary for statistical analysis with quantiles
    summary,
};

/// Label for metrics
pub const Label = struct {
    name: []const u8,
    value: []const u8,
};

/// A single metric data point
pub const DataPoint = struct {
    timestamp: i64,
    value: f64,
    labels: []const Label,
};

/// Configuration for a metric
pub const MetricConfig = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    labels: ?[]const Label = null,
    buckets: ?[]const f64 = null, // For histograms
    objectives: ?[]const struct { quantile: f64, epsilon: f64 } = null, // For summaries
};

/// Base metric interface
pub const Metric = struct {
    name: []const u8,
    description: ?[]const u8,
    metric_type: MetricType,
    
    pub fn init(allocator: Allocator, config: MetricConfig, metric_type: MetricType) !*Metric {
        const self = try allocator.create(Metric);
        self.* = .{
            .name = try allocator.dupe(u8, config.name),
            .description = if (config.description) |desc| 
                try allocator.dupe(u8, desc) else null,
            .metric_type = metric_type,
        };
        return self;
    }
    
    pub fn deinit(self: *Metric, allocator: Allocator) void {
        allocator.free(self.name);
        if (self.description) |desc| {
            allocator.free(desc);
        }
        allocator.destroy(self);
    }
};

/// A counter metric
pub const Counter = struct {
    base: Metric,
    value: Atomic(u64) = Atomic(u64).init(0),
    
    pub fn init(allocator: Allocator, config: MetricConfig) !*Counter {
        const self = try allocator.create(Counter);
        self.* = .{
            .base = try Metric.init(allocator, config, .counter),
        };
        return self;
    }
    
    pub fn deinit(self: *Counter, allocator: Allocator) void {
        self.base.deinit(allocator);
        allocator.destroy(self);
    }
    
    pub fn inc(self: *Counter, value: u64) void {
        _ = self.value.fetchAdd(value, .Monotonic);
    }
    
    pub fn get(self: *const Counter) u64 {
        return self.value.load(.Unordered);
    }
};

/// A gauge metric
pub const Gauge = struct {
    base: Metric,
    value: Atomic(i64) = Atomic(i64).init(0),
    
    pub fn init(allocator: Allocator, config: MetricConfig) !*Gauge {
        const self = try allocator.create(Gauge);
        self.* = .{
            .base = try Metric.init(allocator, config, .gauge),
        };
        return self;
    }
    
    pub fn deinit(self: *Gauge, allocator: Allocator) void {
        self.base.deinit(allocator);
        allocator.destroy(self);
    }
    
    pub fn set(self: *Gauge, value: i64) void {
        _ = self.value.swap(value, .Monotonic);
    }
    
    pub fn inc(self: *Gauge, value: i64) void {
        _ = self.value.fetchAdd(value, .Monotonic);
    }
    
    pub fn dec(self: *Gauge, value: i64) void {
        _ = self.value.fetchSub(value, .Monotonic);
    }
    
    pub fn get(self: *const Gauge) i64 {
        return self.value.load(.Unordered);
    }
};

/// A histogram metric
pub const Histogram = struct {
    base: Metric,
    sum: Atomic(f64) = Atomic(f64).init(0),
    count: Atomic(u64) = Atomic(u64).init(0),
    buckets: []const f64,
    counts: []Atomic(u64),
    
    pub fn init(allocator: Allocator, config: MetricConfig) !*Histogram {
        const buckets = config.buckets orelse 
            &[_]f64{ 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0 };
        
        const counts = try allocator.alloc(Atomic(u64), buckets.len + 1);
        for (counts) |*count| {
            count.* = Atomic(u64).init(0);
        }
        
        const self = try allocator.create(Histogram);
        self.* = .{
            .base = try Metric.init(allocator, config, .histogram),
            .buckets = try allocator.dupe(f64, buckets),
            .counts = counts,
        };
        
        return self;
    }
    
    pub fn deinit(self: *Histogram, allocator: Allocator) void {
        self.base.deinit(allocator);
        allocator.free(self.buckets);
        allocator.free(self.counts);
        allocator.destroy(self);
    }
    
    pub fn observe(self: *Histogram, value: f64) void {
        _ = self.sum.fetchAdd(value, .Monotonic);
        _ = self.count.fetchAdd(1, .Monotonic);
        
        // Find the bucket for this value
        var i: usize = 0;
        while (i < self.buckets.len and value > self.buckets[i]) : (i += 1) {}
        
        // Increment the appropriate counter
        _ = self.counts[i].fetchAdd(1, .Monotonic);
    }
    
    pub fn getSum(self: *const Histogram) f64 {
        return @bitCast(f64, self.sum.load(.Unordered, .{}));
    }
    
    pub fn getCount(self: *const Histogram) u64 {
        return self.count.load(.Unordered);
    }
};

/// A registry for metrics
pub const Registry = struct {
    allocator: Allocator,
    metrics: std.StringArrayHashMap(*Metric),
    mutex: Mutex = .{},
    
    pub fn init(allocator: Allocator) !*Registry {
        const self = try allocator.create(Registry);
        self.* = .{
            .allocator = allocator,
            .metrics = std.StringArrayHashMap(*Metric).init(allocator),
        };
        return self;
    }
    
    pub fn deinit(self: *Registry) void {
        var it = self.metrics.iterator();
        while (it.next()) |entry| {
            const metric = entry.value_ptr.*;
            metric.deinit(self.allocator);
        }
        self.metrics.deinit();
        self.allocator.destroy(self);
    }
    
    pub fn registerCounter(self: *Registry, config: MetricConfig) !*Counter {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.metrics.contains(config.name)) {
            return error.MetricAlreadyRegistered;
        }
        
        const counter = try Counter.init(self.allocator, config);
        try self.metrics.putNoClobber(counter.base.name, &counter.base);
        return counter;
    }
    
    pub fn registerGauge(self: *Registry, config: MetricConfig) !*Gauge {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.metrics.contains(config.name)) {
            return error.MetricAlreadyRegistered;
        }
        
        const gauge = try Gauge.init(self.allocator, config);
        try self.metrics.putNoClobber(gauge.base.name, &gauge.base);
        return gauge;
    }
    
    pub fn registerHistogram(self: *Registry, config: MetricConfig) !*Histogram {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.metrics.contains(config.name)) {
            return error.MetricAlreadyRegistered;
        }
        
        const histogram = try Histogram.init(self.allocator, config);
        try self.metrics.putNoClobber(histogram.base.name, &histogram.base);
        return histogram;
    }
    
    pub fn getCounter(self: *Registry, name: []const u8) ?*Counter {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.metrics.get(name)) |metric| {
            if (metric.metric_type == .counter) {
                return @fieldParentPtr(Counter, metric, "base");
            }
        }
        return null;
    }
    
    pub fn getGauge(self: *Registry, name: []const u8) ?*Gauge {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.metrics.get(name)) |metric| {
            if (metric.metric_type == .gauge) {
                return @fieldParentPtr(Gauge, metric, "base");
            }
        }
        return null;
    }
    
    pub fn getHistogram(self: *Registry, name: []const u8) ?*Histogram {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.metrics.get(name)) |metric| {
            if (metric.metric_type == .histogram) {
                return @fieldParentPtr(Histogram, metric, "base");
            }
        }
        return null;
    }
};

/// Default metrics registry
var default_registry: ?*Registry = null;
var registry_mutex = std.Thread.Mutex{};

/// Initialize the default metrics registry
pub fn initDefaultRegistry(allocator: Allocator) !void {
    registry_mutex.lock();
    defer registry_mutex.unlock();
    
    if (default_registry != null) {
        return;
    }
    
    default_registry = try Registry.init(allocator);
}

/// Get the default metrics registry
pub fn getDefaultRegistry() !*Registry {
    registry_mutex.lock();
    defer registry_mutex.unlock();
    
    if (default_registry) |registry| {
        return registry;
    }
    
    return error.DefaultRegistryNotInitialized;
}

test "metrics export" {
    const allocator = std.testing.allocator;
    var registry = try Registry.init(allocator);
    defer registry.deinit();
    
    // Register some metrics
    const requests = try registry.registerCounter(.{
        .name = "http_requests_total",
        .description = "Total number of HTTP requests",
    });
    
    const duration = try registry.registerHistogram(.{
        .name = "http_request_duration_seconds",
        .description = "HTTP request duration in seconds",
        .buckets = &[_]f64{ 0.1, 0.5, 1.0, 2.5, 5.0 },
    });
    
    // Update metrics
    requests.inc(1);
    duration.observe(0.42);
    
    // Verify metrics were updated
    try std.testing.expectEqual(@as(u64, 1), requests.get());
    try std.testing.expectApproxEqAbs(@as(f64, 0.42), duration.getSum(), 0.001);
    try std.testing.expectEqual(@as(u64, 1), duration.getCount());
}
