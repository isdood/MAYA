const std = @import("std");
const builtin = @import("builtin");
const time = std.time;

/// A single recorded metric with timestamp and metadata
pub const Metric = struct {
    name: []const u8,
    value: f64,
    timestamp: i64, // Unix timestamp in milliseconds
    tags: ?[]const []const u8,
    
    /// Format a metric as a string
    pub fn format(
        self: Metric,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const timestamp_str = std.fmt.allocPrint(
            std.heap.page_allocator,
            "{d}",
            .{self.timestamp},
        ) catch "unknown";
        defer std.heap.page_allocator.free(timestamp_str);
        
        try writer.print("{s} {d} {s}", .{
            self.name,
            self.value,
            timestamp_str,
        });
        
        if (self.tags) |tags| {
            try writer.writeAll(" ");
            for (tags, 0..) |tag, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.writeAll(tag);
            }
        }
    }
};

/// A collection of metrics with a fixed capacity
pub const MetricsCollector = struct {
    allocator: std.mem.Allocator,
    metrics: std.ArrayList(Metric),
    max_metrics: usize,
    
    /// Initialize a new metrics collector with a maximum capacity
    pub fn init(allocator: std.mem.Allocator, max_metrics: usize) MetricsCollector {
        return .{
            .allocator = allocator,
            .metrics = std.ArrayList(Metric).init(allocator),
            .max_metrics = max_metrics,
        };
    }
    
    /// Deinitialize the metrics collector and free all resources
    pub fn deinit(self: *MetricsCollector) void {
        self.metrics.deinit();
    }
    
    /// Record a new metric
    pub fn record(
        self: *MetricsCollector,
        name: []const u8,
        value: f64,
        tags: ?[]const []const u8,
    ) !void {
        // Remove oldest metrics if we're at capacity
        while (self.metrics.items.len >= self.max_metrics) {
            _ = self.metrics.orderedRemove(0);
        }
        
        try self.metrics.append(.{
            .name = try self.allocator.dupe(u8, name),
            .value = value,
            .timestamp = time.milliTimestamp(),
            .tags = if (tags) |t| try self.dupeTags(t) else null,
        });
    }
    
    /// Get all metrics
    pub fn getAll(self: *const MetricsCollector) []const Metric {
        return self.metrics.items;
    }
    
    /// Get metrics filtered by name and optional time range
    pub fn query(
        self: *const MetricsCollector,
        name: ?[]const u8,
        start_time: ?i64,
        end_time: ?i64,
    ) std.ArrayList(Metric) {
        var result = std.ArrayList(Metric).init(self.allocator);
        
        for (self.metrics.items) |metric| {
            if (name != null and !std.mem.eql(u8, metric.name, name.?)) continue;
            if (start_time != null and metric.timestamp < start_time.?) continue;
            if (end_time != null and metric.timestamp > end_time.?) continue;
            
            result.append(metric) catch continue;
        }
        
        return result;
    }
    
    /// Clear all metrics
    pub fn clear(self: *MetricsCollector) void {
        self.metrics.clearRetainingCapacity();
    }
    
    /// Helper to duplicate tag strings
    fn dupeTags(self: *const MetricsCollector, tags: []const []const u8) ![]const []const u8 {
        const result = try self.allocator.alloc([]const u8, tags.len);
        errdefer self.allocator.free(result);
        
        for (tags, 0..) |tag, i| {
            result[i] = try self.allocator.dupe(u8, tag);
        }
        
        return result;
    }
};

// Tests
const testing = std.testing;

test "metrics recording and retrieval" {
    var metrics = Metrics.init(testing.allocator);
    defer metrics.deinit();
    
    // Record some metrics
    try metrics.record("quantum_ops_per_sec", 1_000_000, "ops/s", "Quantum operations per second");
    try metrics.record("memory_usage", 42.5, "MB", "Memory usage");
    
    // Retrieve and verify
    const ops_metric = metrics.get("quantum_ops_per_sec") orelse return error.MetricNotFound;
    try testing.expectApproxEqAbs(ops_metric.value, 1_000_000, 0.001);
    
    const mem_metric = metrics.get("memory_usage") orelse return error.MetricNotFound;
    try testing.expectApproxEqAbs(mem_metric.value, 42.5, 0.001);
}

test "metrics formatting" {
    var metrics = Metrics.init(testing.allocator);
    defer metrics.deinit();
    
    try metrics.record("test_metric", 123.45, "units", "Test metric");
    
    var buffer: [1024]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buffer, "{}", .{metrics});
    
    try testing.expect(std.mem.containsAtLeast(u8, formatted, 1, "test_metric"));
    try testing.expect(std.mem.containsAtLeast(u8, formatted, 1, "123.45"));
    try testing.expect(std.mem.containsAtLeast(u8, formatted, 1, "units"));
}
