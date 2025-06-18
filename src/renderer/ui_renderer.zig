const std = @import("std");
const vk = @import("vulkan_types.zig").vk;
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const colors = @import("../glimmer/colors.zig").GlimmerColors;
const VulkanRenderer = @import("vulkan.zig").VulkanRenderer;

pub const UIRenderer = struct {
    const Self = @This();

    vulkan_renderer: *VulkanRenderer,
    layouts: std.ArrayList(*layout.Layout),
    theme: layout.ResizeHandleTheme,
    allocator: std.mem.Allocator,

    pub fn init(vulkan_renderer: *VulkanRenderer, theme: layout.ResizeHandleTheme) !Self {
        return Self{
            .vulkan_renderer = vulkan_renderer,
            .layouts = std.ArrayList(*layout.Layout).init(std.heap.page_allocator),
            .theme = theme,
            .allocator = std.heap.page_allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.layouts.items) |layout_item| {
            layout_item.deinit();
        }
        self.layouts.deinit();
    }

    pub fn addLayout(self: *Self, layout_item: *layout.Layout) !void {
        try self.layouts.append(layout_item);
    }

    pub fn removeLayout(self: *Self, layout_item: *layout.Layout) void {
        for (self.layouts.items, 0..) |item, i| {
            if (item == layout_item) {
                _ = self.layouts.swapRemove(i);
                break;
            }
        }
    }

    pub fn render(self: *Self) !void {
        // Update layouts
        for (self.layouts.items) |layout_item| {
            try layout_item.update();
        }

        // Render layouts
        for (self.layouts.items) |layout_item| {
            try layout_item.render();
        }

        // Draw frame
        try self.vulkan_renderer.drawFrame();
    }

    pub fn setTheme(self: *Self, new_theme: layout.ResizeHandleTheme) void {
        self.theme = new_theme;
        for (self.layouts.items) |layout_item| {
            if (layout_item.* == .resizable) {
                for (layout_item.resizable.handles.items) |*handle| {
                    handle.setTheme(new_theme);
                }
            }
        }
    }
};

// Helper functions for converting between UI and Vulkan coordinates
pub fn uiToVulkanCoords(ui_x: f32, ui_y: f32, window_width: u32, window_height: u32) [2]f32 {
    return .{
        (ui_x / @as(f32, @floatFromInt(window_width))) * 2.0 - 1.0,
        1.0 - (ui_y / @as(f32, @floatFromInt(window_height))) * 2.0,
    };
}

pub fn vulkanToUICoords(vk_x: f32, vk_y: f32, window_width: u32, window_height: u32) [2]f32 {
    return .{
        ((vk_x + 1.0) / 2.0) * @as(f32, @floatFromInt(window_width)),
        (1.0 - (vk_y + 1.0) / 2.0) * @as(f32, @floatFromInt(window_height)),
    };
}

// Helper functions for converting between UI and Vulkan colors
pub fn uiToVulkanColor(color: colors.Color) [4]f32 {
    return .{
        @as(f32, @floatFromInt(color.r)) / 255.0,
        @as(f32, @floatFromInt(color.g)) / 255.0,
        @as(f32, @floatFromInt(color.b)) / 255.0,
        @as(f32, @floatFromInt(color.a)) / 255.0,
    };
}

pub fn vulkanToUIColor(color: [4]f32) colors.Color {
    return colors.Color{
        .r = @intFromFloat(color[0] * 255.0),
        .g = @intFromFloat(color[1] * 255.0),
        .b = @intFromFloat(color[2] * 255.0),
        .a = @intFromFloat(color[3] * 255.0),
    };
} 