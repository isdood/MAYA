// 🎨 MAYA Pattern Evolution View
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-22
// 👤 Author: isdood

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Evolution view configuration
pub const EvolutionViewConfig = struct {
    width: u32 = 1024,
    height: u32 = 768,
    history_length: u32 = 100,  // Number of generations to keep in history
    update_interval_ms: u32 = 16, // ~60 FPS
    
    // Visual settings
    background_color: [4]f32 = .{ 0.05, 0.05, 0.05, 1.0 },
    grid_color: [4]f32 = .{ 0.2, 0.2, 0.2, 1.0 },
    line_color: [4]f32 = .{ 0.0, 0.8, 0.4, 1.0 },
    point_color: [4]f32 = .{ 1.0, 0.2, 0.2, 1.0 },
    
    // Animation settings
    animation_duration: f32 = 1.0, // seconds
    interpolation: enum { linear, ease_in_out } = .ease_in_out,
};

/// Evolution data point
pub const EvolutionDataPoint = struct {
    generation: u64,
    fitness: f32,
    timestamp: i64, // Unix timestamp in milliseconds
};

/// Evolution view state
pub const EvolutionView = struct {
    allocator: Allocator,
    config: EvolutionViewConfig,
    data: std.ArrayList(EvolutionDataPoint),
    
    // View state
    view_offset: [2]f32 = .{ 0, 0 },
    view_scale: [2]f32 = .{ 1.0, 1.0 },
    
    // Animation state
    last_update: i64 = 0,
    animation_start: i64 = 0,
    is_animating: bool = false,
    
    pub fn init(allocator: Allocator, config: EvolutionViewConfig) !@This() {
        return .{
            .allocator = allocator,
            .config = config,
            .data = std.ArrayList(EvolutionDataPoint).init(allocator),
            .last_update = std.time.milliTimestamp(),
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.data.deinit();
    }
    
    /// Add a new data point to the evolution view
    pub fn addDataPoint(self: *@This(), generation: u64, fitness: f32) !void {
        const now = std.time.milliTimestamp();
        try self.data.append(.{
            .generation = generation,
            .fitness = fitness,
            .timestamp = now,
        });
        
        // Trim history if needed
        if (self.data.items.len > self.config.history_length) {
            _ = self.data.orderedRemove(0);
        }
        
        // Start animation for the new point
        self.startAnimation();
    }
    
    /// Start animation
    fn startAnimation(self: *@This()) void {
        self.animation_start = std.time.milliTimestamp();
        self.is_animating = true;
    }
    
    /// Update animation state
    pub fn update(self: *@This()) void {
        if (!self.is_animating) return;
        
        const now = std.time.milliTimestamp();
        const elapsed = @as(f32, @floatFromInt(now - self.animation_start)) / 1000.0;
        
        if (elapsed >= self.config.animation_duration) {
            self.is_animating = false;
            return;
        }
        
        // In a real implementation, this would update the animation state
        // The actual rendering would be handled by the render function
    }
    
    /// Handle view manipulation (pan/zoom)
    pub fn panView(self: *@This(), dx: f32, dy: f32) void {
        self.view_offset[0] += dx / self.view_scale[0];
        self.view_offset[1] += dy / self.view_scale[1];
    }
    
    pub fn zoomView(self: *@This(), factor: f32, cx: f32, cy: f32) void {
        const new_scale_x = self.view_scale[0] * factor;
        const new_scale_y = self.view_scale[1] * factor;
        
        // Apply constraints (optional)
        const min_scale = 0.1;
        const max_scale = 10.0;
        
        if (new_scale_x >= min_scale and new_scale_x <= max_scale and
            new_scale_y >= min_scale and new_scale_y <= max_scale) {
            
            // Adjust offset to zoom toward mouse position
            self.view_offset[0] = (self.view_offset[0] - cx) * (self.view_scale[0] / new_scale_x) + cx;
            self.view_offset[1] = (self.view_offset[1] - cy) * (self.view_scale[1] / new_scale_y) + cy;
            
            self.view_scale = .{ new_scale_x, new_scale_y };
        }
    }
    
    /// Render the evolution view
    pub fn render(self: *const @This()) void {
        // In a real implementation, this would use a 2D rendering context
        // to draw the evolution graph. This is a placeholder that would be
        // implemented with the actual rendering backend.
        
        // For now, we'll just log the render call
        std.debug.print("Rendering evolution view with {} data points\n", .{
            self.data.items.len,
        });
        
        if (self.data.items.len > 0) {
            const latest = self.data.items[self.data.items.len - 1];
            std.debug.print("Latest generation: {}, fitness: {}\n", .{
                latest.generation,
                latest.fitness,
            });
        }
    }
};

// Tests
const testing = std.testing;

test "EvolutionView initialization" {
    const allocator = testing.allocator;
    const config = EvolutionViewConfig{};
    var view = try EvolutionView.init(allocator, config);
    defer view.deinit();
    
    try testing.expectEqual(@as(usize, 0), view.data.items.len);
}

test "EvolutionView add data points" {
    const allocator = testing.allocator;
    var view = try EvolutionView.init(allocator, .{ .history_length = 3 });
    defer view.deinit();
    
    try view.addDataPoint(1, 0.5);
    try view.addDataPoint(2, 0.7);
    try view.addDataPoint(3, 0.9);
    try view.addDataPoint(4, 0.8); // Should remove the first point
    
    try testing.expectEqual(@as(usize, 3), view.data.items.len);
    try testing.expectEqual(@as(u64, 2), view.data.items[0].generation);
    try testing.expectEqual(@as(u64, 4), view.data.items[2].generation);
}
