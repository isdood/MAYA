// 🎨 MAYA Visualization System
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-22
// 👤 Author: isdood

// Core visualization components
pub const pattern3d = @import("pattern3d.zig");
pub const evolution_view = @import("evolution_view.zig");
pub const pattern_tools = @import("pattern_tools.zig");

// Re-export common types for convenience
pub const Visualization3DConfig = pattern3d.Visualization3DConfig;
pub const EvolutionViewConfig = evolution_view.EvolutionViewConfig;
pub const ToolType = pattern_tools.ToolType;
pub const ToolConfig = pattern_tools.ToolConfig;

/// Main visualization controller that manages all visualization components
pub const VisualizationController = struct {
    allocator: std.mem.Allocator,
    
    // 3D visualization
    pattern3d: ?*pattern3d.Visualization3DState = null,
    pattern3d_renderer: ?*pattern3d.Renderer3D = null,
    
    // Evolution view
    evolution_view: ?*evolution_view.EvolutionView = null,
    
    // Tools
    tool_manager: ?*pattern_tools.ToolManager = null,
    
    // Rendering state
    width: u32 = 1024,
    height: u32 = 768,
    needs_redraw: bool = true,
    
    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *@This()) void {
        if (self.pattern3d_renderer) |renderer| {
            self.allocator.destroy(renderer);
        }
        
        if (self.pattern3d) |state| {
            state.deinit();
            self.allocator.destroy(state);
        }
        
        if (self.evolution_view) |view| {
            view.deinit();
            self.allocator.destroy(view);
        }
        
        if (self.tool_manager) |manager| {
            manager.deinit();
            self.allocator.destroy(manager);
        }
    }
    
    /// Initialize 3D visualization
    pub fn init3DVisualization(self: *@This(), config: Visualization3DConfig) !void {
        if (self.pattern3d != null) return;
        
        self.pattern3d = try self.allocator.create(pattern3d.Visualization3DState);
        self.pattern3d.?.* = try pattern3d.Visualization3DState.init(
            self.allocator,
            config,
        );
        
        self.pattern3d_renderer = try self.allocator.create(pattern3d.Renderer3D);
        self.pattern3d_renderer.?.* = pattern3d.Renderer3D.init(self.pattern3d.?);
    }
    
    /// Initialize evolution view
    pub fn initEvolutionView(self: *@This(), config: EvolutionViewConfig) !void {
        if (self.evolution_view != null) return;
        
        self.evolution_view = try self.allocator.create(evolution_view.EvolutionView);
        self.evolution_view.?.* = try evolution_view.EvolutionView.init(
            self.allocator,
            config,
        );
    }
    
    /// Initialize tool manager
    pub fn initToolManager(self: *@This()) !void {
        if (self.tool_manager != null) return;
        
        self.tool_manager = try self.allocator.create(pattern_tools.ToolManager);
        self.tool_manager.?.* = try pattern_tools.ToolManager.init(self.allocator);
    }
    
    /// Update all visualizations
    pub fn update(self: *@This(), delta_time: f32) void {
        // Update 3D visualization
        if (self.pattern3d) |state| {
            state.update(delta_time);
            self.needs_redraw = true;
        }
        
        // Update evolution view
        if (self.evolution_view) |view| {
            view.update();
            if (view.is_animating) {
                self.needs_redraw = true;
            }
        }
    }
    
    /// Render all visualizations
    pub fn render(self: *@This()) void {
        if (!self.needs_redraw) return;
        
        // Render 3D visualization
        if (self.pattern3d_renderer) |renderer| {
            renderer.render();
        }
        
        // Render evolution view
        if (self.evolution_view) |view| {
            view.render();
        }
        
        // Draw tool previews
        if (self.tool_manager) |manager| {
            if (manager.getActiveTool()) |tool| {
                tool.drawPreview();
            }
        }
        
        self.needs_redraw = false;
    }
    
    /// Handle window resize
    pub fn onResize(self: *@This(), width: u32, height: u32) void {
        self.width = width;
        self.height = height;
        self.needs_redraw = true;
        
        // Update 3D viewport
        if (self.pattern3d) |state| {
            state.config.width = width;
            state.config.height = height;
        }
    }
    
    /// Handle mouse input
    pub fn onMouseEvent(self: *@This(), event: struct {
        x: f32,
        y: f32,
        dx: f32 = 0,
        dy: f32 = 0,
        button: u8 = 0,
        buttons: u8 = 0,
        modifiers: u8 = 0,
        pressed: bool = false,
        released: bool = false,
        wheel_x: f32 = 0,
        wheel_y: f32 = 0,
    }) void {
        // Forward to tool manager if we have one
        if (self.tool_manager) |manager| {
            if (event.pressed) {
                manager.beginToolAction(event.x, event.y, event.button, event.modifiers);
            } else if (event.released) {
                manager.endToolAction();
            } else if (event.dx != 0 or event.dy != 0) {
                manager.updateToolAction(event.x, event.y, 1.0);
            }
            
            // Handle mouse wheel for zooming
            if (event.wheel_y != 0) {
                if (self.pattern3d) |state| {
                    state.zoom(event.wheel_y * 0.1);
                }
                if (self.evolution_view) |view| {
                    view.zoomView(1.0 + event.wheel_y * 0.1, event.x, event.y);
                }
            }
        }
        
        self.needs_redraw = true;
    }
    
    /// Handle keyboard input
    pub fn onKeyEvent(self: *@This(), key: []const u8, pressed: bool, modifiers: u8) void {
        _ = modifiers;
        
        if (!pressed) return;
        
        // Toggle between tools using number keys
        if (std.mem.eql(u8, key, "1")) {
            if (self.tool_manager) |manager| {
                manager.setActiveTool(.select);
            }
        } else if (std.mem.eql(u8, key, "2")) {
            if (self.tool_manager) |manager| {
                manager.setActiveTool(.move);
            }
        } else if (std.mem.eql(u8, key, "3")) {
            if (self.tool_manager) |manager| {
                manager.setActiveTool(.paint);
            }
        }
        
        self.needs_redraw = true;
    }
};

// Tests
const testing = std.testing;

test "VisualizationController initialization" {
    const allocator = testing.allocator;
    var controller = try VisualizationController.init(allocator);
    defer controller.deinit();
    
    // Test 3D visualization initialization
    try controller.init3DVisualization(.{});
    try testing.expect(controller.pattern3d != null);
    try testing.expect(controller.pattern3d_renderer != null);
    
    // Test evolution view initialization
    try controller.initEvolutionView(.{});
    try testing.expect(controller.evolution_view != null);
    
    // Test tool manager initialization
    try controller.initToolManager();
    try testing.expect(controller.tool_manager != null);
}
