@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-06 18:08:24",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/renderer/renderer.zig",
    "type": "zig",
    "hash": "8d41c0a9d05fa751c76c5b547ac0fa8b50f04fb6"
  }
}
@pattern_meta@

const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const PerformanceMetrics = @import("performance_metrics.zig").PerformanceMetrics;

pub const Renderer = struct {
    const Self = @This();

    // ... existing code ...

    performance_metrics: ?*PerformanceMetrics,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        self.* = Self{
            // ... existing initialization ...
            .performance_metrics = null,
        };

        // Initialize performance metrics after device creation
        self.performance_metrics = try PerformanceMetrics.init(
            self.device,
            self.physical_device,
            allocator
        );

        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.performance_metrics) |*metrics| {
            metrics.deinit(self.device);
        }
        // ... existing cleanup ...
        allocator.destroy(self);
    }

    pub fn beginFrame(self: *Self) !void {
        // ... existing begin frame code ...

        // Begin performance metrics collection
        if (self.performance_metrics) |*metrics| {
            metrics.beginFrame(self.device, self.command_buffer);
        }

        // ... rest of begin frame code ...
    }

    pub fn endFrame(self: *Self) !void {
        // ... existing end frame code ...

        // End performance metrics collection
        if (self.performance_metrics) |*metrics| {
            metrics.endFrame(self.device, self.command_buffer);
            try metrics.updateMetrics(self.device);
        }

        // ... rest of end frame code ...
    }

    pub fn getPerformanceMetrics(self: *Self) ?struct {
        fps: f32,
        frame_time: f32,
        gpu_usage: f32,
        vram_usage: f32,
        cpu_usage: f32,
        memory_usage: f32,
    } {
        if (self.performance_metrics) |*metrics| {
            return metrics.getMetrics();
        }
        return null;
    }
}; 