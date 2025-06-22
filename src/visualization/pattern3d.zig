// 🎨 MAYA 3D Pattern Visualization
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-22
// 👤 Author: isdood

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

/// 3D visualization configuration
pub const Visualization3DConfig = struct {
    // Scene settings
    width: u32 = 1024,
    height: u32 = 768,
    background_color: [4]f32 = .{ 0.1, 0.1, 0.1, 1.0 },
    
    // Camera settings
    fov: f32 = 60.0,
    near: f32 = 0.1,
    far: f32 = 1000.0,
    camera_position: [3]f32 = .{ 0, 0, 5 },
    
    // Lighting
    ambient_light: [3]f32 = .{ 0.5, 0.5, 0.5 },
    directional_light: [3]f32 = .{ 1.0, 1.0, 1.0 },
    light_position: [3]f32 = .{ 10.0, 10.0, 10.0 },
};

/// 3D pattern visualization state
pub const Visualization3DState = struct {
    allocator: Allocator,
    config: Visualization3DConfig,
    
    // Pattern data
    vertices: std.ArrayList([3]f32),
    colors: std.ArrayList([3]f32),
    indices: std.ArrayList(u32),
    
    // Transformation state
    rotation: [3]f32 = .{ 0, 0, 0 },
    scale: [3]f32 = .{ 1, 1, 1 },
    position: [3]f32 = .{ 0, 0, 0 },
    
    // Animation state
    animation_speed: f32 = 0.5,
    is_animating: bool = true,
    
    pub fn init(allocator: Allocator, config: Visualization3DConfig) !@This() {
        return .{
            .allocator = allocator,
            .config = config,
            .vertices = std.ArrayList([3]f32).init(allocator),
            .colors = std.ArrayList([3]f32).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.vertices.deinit();
        self.colors.deinit();
        self.indices.deinit();
    }
    
    /// Update the pattern data
    pub fn updatePattern(
        self: *@This(),
        vertices: []const [3]f32,
        colors: []const [3]f32,
        indices: []const u32,
    ) !void {
        try self.vertices.replaceRange(0, self.vertices.items.len, vertices);
        try self.colors.replaceRange(0, self.colors.items.len, colors);
        try self.indices.replaceRange(0, self.indices.items.len, indices);
    }
    
    /// Update the camera position
    pub fn setCameraPosition(self: *@This(), position: [3]f32) void {
        self.config.camera_position = position;
    }
    
    /// Rotate the pattern
    pub fn rotate(self: *@This(), x: f32, y: f32, z: f32) void {
        self.rotation[0] += x;
        self.rotation[1] += y;
        self.rotation[2] += z;
    }
    
    /// Scale the pattern
    pub fn setScale(self: *@This(), x: f32, y: f32, z: f32) void {
        self.scale = .{ x, y, z };
    }
    
    /// Toggle animation
    pub fn toggleAnimation(self: *@This()) void {
        self.is_animating = !self.is_animating;
    }
    
    /// Update animation state
    pub fn update(self: *@This(), delta_time: f32) void {
        if (self.is_animating) {
            self.rotate(
                delta_time * self.animation_speed * 0.5,
                delta_time * self.animation_speed * 0.3,
                delta_time * self.animation_speed * 0.2
            );
        }
    }
};

/// 3D visualization renderer
pub const Renderer3D = struct {
    state: *Visualization3DState,
    
    pub fn init(state: *Visualization3DState) @This() {
        return .{ .state = state };
    }
    
    /// Render the current state
    pub fn render(self: *const @This()) void {
        // In a real implementation, this would use OpenGL/WebGL/WebGPU
        // to render the 3D scene. This is a placeholder that would be
        // implemented with the actual rendering backend.
        
        // For now, we'll just log the render call
        std.debug.print("Rendering 3D pattern with {} vertices and {} indices\n", .{
            self.state.vertices.items.len,
            self.state.indices.items.len,
        });
    }
};

/// Interactive controls for 3D visualization
pub const InteractionController = struct {
    state: *Visualization3DState,
    
    pub fn init(state: *Visualization3DState) @This() {
        return .{ .state = state };
    }
    
    /// Handle mouse movement
    pub fn onMouseMove(self: *const @This(), dx: f32, dy: f32) void {
        if (!self.state.is_animating) {
            self.state.rotate(dx * 0.01, dy * 0.01, 0);
        }
    }
    
    /// Handle mouse wheel
    pub fn onMouseWheel(self: *const @This(), delta: f32) void {
        const scale = 1.0 + delta * 0.1;
        self.state.scale[0] *= scale;
        self.state.scale[1] *= scale;
        self.state.scale[2] *= scale;
    }
    
    /// Handle keyboard input
    pub fn onKeyPress(self: *const @This(), key: []const u8) void {
        if (std.mem.eql(u8, key, " ")) {
            self.state.toggleAnimation();
        }
    }
};

// Tests
const testing = std.testing;

test "Visualization3DState initialization" {
    const allocator = testing.allocator;
    const config = Visualization3DConfig{};
    var state = try Visualization3DState.init(allocator, config);
    defer state.deinit();
    
    try testing.expectEqual(@as(usize, 0), state.vertices.items.len);
    try testing.expectEqual(@as(usize, 0), state.colors.items.len);
    try testing.expectEqual(@as(usize, 0), state.indices.items.len);
}

test "Visualization3DState pattern update" {
    const allocator = testing.allocator;
    var state = try Visualization3DState.init(allocator, .{});
    defer state.deinit();
    
    const vertices = [_][3]f32{
        .{ -1, -1, 0 },
        .{ 1, -1, 0 },
        .{ 0, 1, 0 },
    };
    
    const colors = [_][3]f32{
        .{ 1, 0, 0 },
        .{ 0, 1, 0 },
        .{ 0, 0, 1 },
    };
    
    const indices = [_]u32{ 0, 1, 2 };
    
    try state.updatePattern(&vertices, &colors, &indices);
    
    try testing.expectEqual(@as(usize, 3), state.vertices.items.len);
    try testing.expectEqual(@as(usize, 3), state.colors.items.len);
    try testing.expectEqual(@as(usize, 3), state.indices.items.len);
}
