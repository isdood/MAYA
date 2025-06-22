// 🎨 MAYA Pattern Manipulation Tools
// ✨ Version: 1.0.0
// 📅 Created: 2025-06-22
// 👤 Author: isdood

const std = @import("std");
const math = std.math;
const Allocator = std.mem.Allocator;

/// Tool types
pub const ToolType = enum {
    select,
    move,
    rotate,
    scale,
    paint,
    erase,
    measure,
    slice,
    noise,
    smooth,
};

/// Tool configuration
pub const ToolConfig = struct {
    size: f32 = 1.0,
    opacity: f32 = 1.0,
    color: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
    hardness: f32 = 0.5,
    strength: f32 = 0.5,
    snap_to_grid: bool = true,
    grid_size: f32 = 0.1,
};

/// Tool state
pub const ToolState = struct {
    active: bool = false,
    position: [2]f32 = .{ 0, 0 },
    last_position: [2]f32 = .{ 0, 0 },
    pressure: f32 = 1.0,
    button: u8 = 0,
    modifiers: u8 = 0,
    
    pub fn isLeftButton(self: @This()) bool {
        return (self.button & 0x01) != 0;
    }
    
    pub fn isRightButton(self: @This()) bool {
        return (self.button & 0x02) != 0;
    }
    
    pub fn isMiddleButton(self: @This()) bool {
        return (self.button & 0x04) != 0;
    }
    
    pub fn hasCtrlModifier(self: @This()) bool {
        return (self.modifiers & 0x01) != 0;
    }
    
    pub fn hasShiftModifier(self: @This()) bool {
        return (self.modifiers & 0x02) != 0;
    }
    
    pub fn hasAltModifier(self: @This()) bool {
        return (self.modifiers & 0x04) != 0;
    }
};

/// Base tool interface
pub const Tool = struct {
    type: ToolType,
    config: ToolConfig,
    state: ToolState = .{},
    
    pub fn begin(self: *@This(), x: f32, y: f32, button: u8, modifiers: u8) void {
        self.state = .{
            .active = true,
            .position = .{ x, y },
            .last_position = .{ x, y },
            .button = button,
            .modifiers = modifiers,
        };
    }
    
    pub fn update(self: *@This(), x: f32, y: f32, pressure: f32) void {
        self.state.last_position = self.state.position;
        self.state.position = .{ x, y };
        self.state.pressure = pressure;
    }
    
    pub fn end(self: *@This()) void {
        self.state.active = false;
    }
    
    pub fn cancel(self: *@This()) void {
        self.state.active = false;
    }
    
    pub fn drawPreview(self: *const @This()) void {
        // Default implementation does nothing
        _ = self;
    }
};

/// Selection tool
pub const SelectTool = struct {
    base: Tool = .{ .type = .select },
    selection: std.ArrayList(usize),
    
    pub fn init(allocator: Allocator) @This() {
        return .{
            .selection = std.ArrayList(usize).init(allocator),
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.selection.deinit();
    }
    
    pub fn begin(self: *@This(), x: f32, y: f32, button: u8, modifiers: u8) void {
        self.base.begin(x, y, button, modifiers);
        
        if (self.base.state.isLeftButton() && !self.base.state.hasShiftModifier()) {
            // Clear selection if not holding shift
            self.selection.clearRetainingCapacity();
        }
    }
    
    pub fn drawPreview(self: *const @This()) void {
        // Draw selection rectangle or lasso
        _ = self;
    }
};

/// Move tool
pub const MoveTool = struct {
    base: Tool = .{ .type = .move },
    
    pub fn begin(self: *@This(), x: f32, y: f32, button: u8, modifiers: u8) void {
        self.base.begin(x, y, button, modifiers);
    }
    
    pub fn update(self: *@This(), x: f32, y: f32, pressure: f32) void {
        _ = pressure;
        const dx = x - self.base.state.last_position[0];
        const dy = y - self.base.state.last_position[1];
        
        // Apply movement to selected objects
        // This would be implemented to actually move the selected pattern elements
        _ = dx;
        _ = dy;
        
        self.base.state.position = .{ x, y };
    }
};

/// Paint tool
pub const PaintTool = struct {
    base: Tool = .{ .type = .paint },
    stroke_points: std.ArrayList([2]f32),
    
    pub fn init(allocator: Allocator) @This() {
        return .{
            .stroke_points = std.ArrayList([2]f32).init(allocator),
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.stroke_points.deinit();
    }
    
    pub fn begin(self: *@This(), x: f32, y: f32, button: u8, modifiers: u8) void {
        self.base.begin(x, y, button, modifiers);
        self.stroke_points.clearRetainingCapacity();
        self.stroke_points.append(.{ x, y }) catch {};
    }
    
    pub fn update(self: *@This(), x: f32, y: f32, pressure: f32) void {
        _ = pressure;
        self.base.update(x, y, pressure);
        self.stroke_points.append(.{ x, y }) catch {};
        
        // Apply paint to the pattern
        // This would be implemented to actually paint on the pattern
    }
    
    pub fn end(self: *@This()) void {
        self.base.end();
        
        // Finalize the stroke
        if (self.stroke_points.items.len > 1) {
            // Create a stroke from the points
            // This would be implemented to create the actual stroke in the pattern
        }
    }
};

/// Tool manager
pub const ToolManager = struct {
    allocator: Allocator,
    tools: std.EnumMap(ToolType, *Tool),
    active_tool: ToolType,
    
    pub fn init(allocator: Allocator) !@This() {
        var self = @This(){
            .allocator = allocator,
            .tools = std.EnumMap(ToolType, *Tool).init(allocator),
            .active_tool = .select,
        };
        
        // Initialize default tools
        try self.registerTool(.select, try allocator.create(SelectTool));
        try self.registerTool(.move, try allocator.create(MoveTool));
        try self.registerTool(.paint, try allocator.create(PaintTool));
        // Add more tools as needed
        
        return self;
    }
    
    pub fn deinit(self: *@This()) void {
        // Clean up tools
        var iter = self.tools.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.*) |tool| {
                switch (entry.key) {
                    .select => {
                        const select_tool = @fieldParentPtr(SelectTool, "base", tool);
                        select_tool.deinit();
                        self.allocator.destroy(select_tool);
                    },
                    .paint => {
                        const paint_tool = @fieldParentPtr(PaintTool, "base", tool);
                        paint_tool.deinit();
                        self.allocator.destroy(paint_tool);
                    },
                    else => {
                        self.allocator.destroy(tool);
                    },
                }
            }
        }
        self.tools.deinit();
    }
    
    fn registerTool(self: *@This(), tool_type: ToolType, tool: *Tool) !void {
        try self.tools.put(tool_type, tool);
    }
    
    pub fn setActiveTool(self: *@This(), tool_type: ToolType) void {
        if (self.tools.get(tool_type) != null) {
            self.active_tool = tool_type;
        }
    }
    
    pub fn getActiveTool(self: *const @This()) ?*Tool {
        return self.tools.get(self.active_tool);
    }
    
    pub fn beginToolAction(self: *@This(), x: f32, y: f32, button: u8, modifiers: u8) void {
        if (self.getActiveTool()) |tool| {
            tool.begin(x, y, button, modifiers);
        }
    }
    
    pub fn updateToolAction(self: *@This(), x: f32, y: f32, pressure: f32) void {
        if (self.getActiveTool()) |tool| {
            tool.update(x, y, pressure);
        }
    }
    
    pub fn endToolAction(self: *@This()) void {
        if (self.getActiveTool()) |tool| {
            tool.end();
        }
    }
};

// Tests
const testing = std.testing;

test "ToolManager initialization" {
    const allocator = testing.allocator;
    var manager = try ToolManager.init(allocator);
    defer manager.deinit();
    
    try testing.expect(manager.getActiveTool() != null);
    try testing.expectEqual(ToolType.select, manager.active_tool);
}

test "Tool switching" {
    const allocator = testing.allocator;
    var manager = try ToolManager.init(allocator);
    defer manager.deinit();
    
    manager.setActiveTool(.move);
    try testing.expectEqual(ToolType.move, manager.active_tool);
    
    manager.setActiveTool(.paint);
    try testing.expectEqual(ToolType.paint, manager.active_tool);
}
