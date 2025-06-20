@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-19 07:46:09",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/neural/adaptive_scaling.zig",
    "type": "zig",
    "hash": "fc1eaf9f0d983f8594050628b8d0441717bfe825"
  }
}
@pattern_meta@

const std = @import("std");
const ResourceManager = @import("resource_management.zig").ResourceManager;
const DistributedManager = @import("distributed_processing.zig").DistributedManager;
const SingleNodeOptimization = @import("single_node_optimization.zig");

/// Adaptive scaling configuration
pub const AdaptiveScalingConfig = struct {
    min_nodes: usize = 1,
    max_nodes: usize = 128,
    min_threads: usize = 2,
    max_threads: usize = 32,
    cpu_scale_up_threshold: f64 = 0.75,
    cpu_scale_down_threshold: f64 = 0.35,
    memory_scale_up_threshold: f64 = 0.8,
    memory_scale_down_threshold: f64 = 0.4,
    scale_interval: u64 = 5000, // 5 seconds
};

/// Adaptive scaling manager
pub const AdaptiveScalingManager = struct {
    config: AdaptiveScalingConfig,
    allocator: std.mem.Allocator,
    resource_manager: *ResourceManager,
    distributed_manager: *DistributedManager,
    thread_pool: *SingleNodeOptimization.AdaptiveThreadPool,
    is_running: bool,
    scaling_thread: ?std.Thread,

    pub fn init(
        allocator: std.mem.Allocator,
        resource_manager: *ResourceManager,
        distributed_manager: *DistributedManager,
        thread_pool: *SingleNodeOptimization.AdaptiveThreadPool,
    ) !*AdaptiveScalingManager {
        var manager = try allocator.create(AdaptiveScalingManager);
        manager.* = AdaptiveScalingManager{
            .config = AdaptiveScalingConfig{},
            .allocator = allocator,
            .resource_manager = resource_manager,
            .distributed_manager = distributed_manager,
            .thread_pool = thread_pool,
            .is_running = false,
            .scaling_thread = null,
        };
        try manager.start();
        return manager;
    }

    pub fn deinit(self: *AdaptiveScalingManager) void {
        self.stop();
        self.allocator.destroy(self);
    }

    pub fn start(self: *AdaptiveScalingManager) !void {
        self.is_running = true;
        self.scaling_thread = try std.Thread.spawn(.{}, AdaptiveScalingManager.scalingLoop, .{self});
    }

    pub fn stop(self: *AdaptiveScalingManager) void {
        self.is_running = false;
        if (self.scaling_thread) |thread| {
            thread.join();
        }
    }

    fn scalingLoop(self: *AdaptiveScalingManager) !void {
        while (self.is_running) {
            // Monitor resource usage
            const cpu_usage = try self.resource_manager.getCPUUsage();
            const memory_usage = try self.resource_manager.getMemoryUsage();

            // Scale threads (single node)
            var new_threads = self.thread_pool.current_threads;
            if (cpu_usage > self.config.cpu_scale_up_threshold && new_threads < self.config.max_threads) {
                new_threads += 1;
            } else if (cpu_usage < self.config.cpu_scale_down_threshold && new_threads > self.config.min_threads) {
                new_threads -= 1;
            }
            try self.thread_pool.scale(new_threads, fn (tid: usize) void { _ = tid; });

            // Scale nodes (distributed)
            var node_count = self.distributed_manager.nodes.items.len;
            if (memory_usage > self.config.memory_scale_up_threshold && node_count < self.config.max_nodes) {
                // Simulate adding a node (in real system, provision new node)
                _ = try self.distributed_manager.registerNode("auto:node", "auto");
            } else if (memory_usage < self.config.memory_scale_down_threshold && node_count > self.config.min_nodes) {
                // Simulate removing a node (in real system, deprovision node)
                // For demo, just mark last node inactive
                self.distributed_manager.nodes.items[node_count - 1].is_active = false;
            }

            std.time.sleep(self.config.scale_interval * std.time.ns_per_ms);
        }
    }
};

// Tests
test "adaptive scaling manager initialization" {
    const allocator = std.testing.allocator;
    var resource_manager = try ResourceManager.init(allocator, null, null);
    defer resource_manager.deinit();
    var distributed_manager = try DistributedManager.init(allocator, null, resource_manager, null);
    defer distributed_manager.deinit();
    var thread_pool = try SingleNodeOptimization.AdaptiveThreadPool.init(allocator, resource_manager, 2, 4);
    defer thread_pool.deinit();
    var manager = try AdaptiveScalingManager.init(allocator, resource_manager, distributed_manager, thread_pool);
    defer manager.deinit();
    try std.testing.expect(manager.is_running == true);
} 