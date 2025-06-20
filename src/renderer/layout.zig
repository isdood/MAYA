@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-18 15:26:33",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/renderer/layout.zig",
    "type": "zig",
    "hash": "479c96d6d428a736d3ae10f04c5e70cd2e2cf6c2"
  }
}
@pattern_meta@

const std = @import("std");
const c = @cImport({
    @cInclude("cimgui.h");
});
const widgets = @import("widgets.zig");

/// Layout direction for widget arrangement
pub const Direction = enum {
    Horizontal,
    Vertical,
};

/// Alignment options for widgets within a layout
pub const Alignment = enum {
    Start,
    Center,
    End,
    SpaceBetween,
    SpaceAround,
};

/// Padding configuration for layouts
pub const Padding = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn all(value: f32) Padding {
        return .{
            .top = value,
            .right = value,
            .bottom = value,
            .left = value,
        };
    }

    pub fn horizontal(amount: f32) Padding {
        return .{
            .left = amount,
            .right = amount,
        };
    }

    pub fn vertical(amount: f32) Padding {
        return .{
            .top = amount,
            .bottom = amount,
        };
    }
};

/// Flex grow and shrink properties for flex layout
pub const FlexProperties = struct {
    grow: f32 = 0,
    shrink: f32 = 1,
    basis: f32 = 0,
};

/// Resize constraints for widgets within layouts
pub const ResizeConstraints = struct {
    min_width: f32,
    max_width: f32,
    min_height: f32,
    max_height: f32,
    aspect_ratio: ?f32 = null,
    preserve_aspect: bool = false,
    min_aspect_ratio: ?f32 = null,
    max_aspect_ratio: ?f32 = null,

    pub fn init(
        min_width: f32,
        max_width: f32,
        min_height: f32,
        max_height: f32,
        aspect_ratio: ?f32,
        preserve_aspect: bool,
        min_aspect_ratio: ?f32,
        max_aspect_ratio: ?f32,
    ) ResizeConstraints {
        return ResizeConstraints{
            .min_width = min_width,
            .max_width = max_width,
            .min_height = min_height,
            .max_height = max_height,
            .aspect_ratio = aspect_ratio,
            .preserve_aspect = preserve_aspect,
            .min_aspect_ratio = min_aspect_ratio,
            .max_aspect_ratio = max_aspect_ratio,
        };
    }

    pub fn apply(self: *const ResizeConstraints, size: *[2]f32) void {
        // Apply min/max constraints
        size[0] = @max(self.min_width, @min(self.max_width, size[0]));
        size[1] = @max(self.min_height, @min(self.max_height, size[1]));

        // Calculate current aspect ratio
        const current_ratio = size[0] / size[1];

        // Apply fixed aspect ratio if specified
        if (self.aspect_ratio) |ratio| {
            if (self.preserve_aspect) {
                if (current_ratio > ratio) {
                    size[0] = size[1] * ratio;
                } else {
                    size[1] = size[0] / ratio;
                }
            }
        }

        // Apply minimum aspect ratio constraint
        if (self.min_aspect_ratio) |min_ratio| {
            if (current_ratio < min_ratio) {
                // Adjust width to meet minimum aspect ratio
                const new_width = size[1] * min_ratio;
                if (new_width <= self.max_width) {
                    size[0] = new_width;
                } else {
                    // If width can't be increased, adjust height instead
                    size[1] = size[0] / min_ratio;
                }
            }
        }

        // Apply maximum aspect ratio constraint
        if (self.max_aspect_ratio) |max_ratio| {
            if (current_ratio > max_ratio) {
                // Adjust width to meet maximum aspect ratio
                const new_width = size[1] * max_ratio;
                if (new_width >= self.min_width) {
                    size[0] = new_width;
                } else {
                    // If width can't be decreased, adjust height instead
                    size[1] = size[0] / max_ratio;
                }
            }
        }

        // Ensure final size is within bounds
        size[0] = @max(self.min_width, @min(self.max_width, size[0]));
        size[1] = @max(self.min_height, @min(self.max_height, size[1]));
    }

    pub fn validate(self: *const ResizeConstraints) bool {
        // Check if constraints are valid
        if (self.min_width > self.max_width or self.min_height > self.max_height) {
            return false;
        }

        // Check if aspect ratio constraints are valid
        if (self.min_aspect_ratio) |min_ratio| {
            if (min_ratio <= 0) return false;
            if (self.max_aspect_ratio) |max_ratio| {
                if (min_ratio > max_ratio) return false;
            }
        }

        if (self.max_aspect_ratio) |max_ratio| {
            if (max_ratio <= 0) return false;
        }

        // Check if fixed aspect ratio is valid
        if (self.aspect_ratio) |ratio| {
            if (ratio <= 0) return false;
            if (self.min_aspect_ratio) |min_ratio| {
                if (ratio < min_ratio) return false;
            }
            if (self.max_aspect_ratio) |max_ratio| {
                if (ratio > max_ratio) return false;
            }
        }

        return true;
    }
};

/// Theme configuration for resize handles
pub const ResizeHandleTheme = struct {
    handle_size: f32 = 8,
    border_width: f32 = 1,
    corner_radius: f32 = 0,
    colors: struct {
        normal: c.ImVec4 = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.5 },
        hover: c.ImVec4 = .{ .x = 0.6, .y = 0.6, .z = 0.6, .w = 0.7 },
        active: c.ImVec4 = .{ .x = 0.7, .y = 0.7, .z = 0.7, .w = 0.8 },
        border: c.ImVec4 = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 },
        fixed_aspect: c.ImVec4 = .{ .x = 0.0, .y = 0.8, .z = 0.0, .w = 0.8 },
        min_aspect: c.ImVec4 = .{ .x = 1.0, .y = 0.5, .z = 0.0, .w = 0.8 },
        max_aspect: c.ImVec4 = .{ .x = 0.0, .y = 0.5, .z = 1.0, .w = 0.8 },
        ratio_bg: c.ImVec4 = .{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.5 },
        ratio_text: c.ImVec4 = .{ .x = 1.0, .y = 1.0, .z = 1.0, .w = 1.0 },
    },
    fonts: struct {
        ratio_size: f32 = 13,
        tooltip_size: f32 = 14,
    },
    animations: struct {
        hover_scale: f32 = 1.1,
        transition_speed: f32 = 0.2,
        color_transition_speed: f32 = 0.15,
        theme_transition_speed: f32 = 0.3,
    },

    pub fn init() ResizeHandleTheme {
        return ResizeHandleTheme{};
    }

    pub fn dark() ResizeHandleTheme {
        return ResizeHandleTheme{
            .colors = .{
                .normal = .{ .x = 0.3, .y = 0.3, .z = 0.3, .w = 0.5 },
                .hover = .{ .x = 0.4, .y = 0.4, .z = 0.4, .w = 0.7 },
                .active = .{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.8 },
                .border = .{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 1.0 },
                .fixed_aspect = .{ .x = 0.0, .y = 0.6, .z = 0.0, .w = 0.8 },
                .min_aspect = .{ .x = 0.8, .y = 0.4, .z = 0.0, .w = 0.8 },
                .max_aspect = .{ .x = 0.0, .y = 0.4, .z = 0.8, .w = 0.8 },
                .ratio_bg = .{ .x = 0.1, .y = 0.1, .z = 0.1, .w = 0.7 },
                .ratio_text = .{ .x = 0.9, .y = 0.9, .z = 0.9, .w = 1.0 },
            },
        };
    }

    pub fn light() ResizeHandleTheme {
        return ResizeHandleTheme{
            .colors = .{
                .normal = .{ .x = 0.7, .y = 0.7, .z = 0.7, .w = 0.5 },
                .hover = .{ .x = 0.8, .y = 0.8, .z = 0.8, .w = 0.7 },
                .active = .{ .x = 0.9, .y = 0.9, .z = 0.9, .w = 0.8 },
                .border = .{ .x = 0.2, .y = 0.2, .z = 0.2, .w = 1.0 },
                .fixed_aspect = .{ .x = 0.0, .y = 0.9, .z = 0.0, .w = 0.8 },
                .min_aspect = .{ .x = 1.0, .y = 0.6, .z = 0.0, .w = 0.8 },
                .max_aspect = .{ .x = 0.0, .y = 0.6, .z = 1.0, .w = 0.8 },
                .ratio_bg = .{ .x = 0.9, .y = 0.9, .z = 0.9, .w = 0.7 },
                .ratio_text = .{ .x = 0.1, .y = 0.1, .z = 0.1, .w = 1.0 },
            },
        };
    }

    pub fn custom(
        handle_size: f32,
        border_width: f32,
        corner_radius: f32,
        colors: struct {
            normal: c.ImVec4,
            hover: c.ImVec4,
            active: c.ImVec4,
            border: c.ImVec4,
            fixed_aspect: c.ImVec4,
            min_aspect: c.ImVec4,
            max_aspect: c.ImVec4,
            ratio_bg: c.ImVec4,
            ratio_text: c.ImVec4,
        },
    ) ResizeHandleTheme {
        return ResizeHandleTheme{
            .handle_size = handle_size,
            .border_width = border_width,
            .corner_radius = corner_radius,
            .colors = colors,
        };
    }

    pub fn lerpColor(a: c.ImVec4, b: c.ImVec4, t: f32) c.ImVec4 {
        return c.ImVec4{
            .x = a.x + (b.x - a.x) * t,
            .y = a.y + (b.y - a.y) * t,
            .z = a.z + (b.z - a.z) * t,
            .w = a.w + (b.w - a.w) * t,
        };
    }

    pub fn lerpFloat(a: f32, b: f32, t: f32) f32 {
        return a + (b - a) * t;
    }
};

/// Resize handle for widgets
pub const ResizeHandle = struct {
    const Self = @This();

    widget: widgets.Widget,
    target: *widgets.Widget,
    constraints: ResizeConstraints,
    theme: ResizeHandleTheme,
    target_theme: ResizeHandleTheme,
    is_dragging: bool,
    drag_start: [2]f32,
    start_size: [2]f32,
    is_at_min_aspect: bool = false,
    is_at_max_aspect: bool = false,
    hover_scale: f32 = 1.0,
    theme_transition: f32 = 0.0,
    allocator: std.mem.Allocator,

    pub fn init(
        id: [*:0]const u8,
        target: *widgets.Widget,
        constraints: ResizeConstraints,
        theme: ResizeHandleTheme,
        position: [2]f32,
        size: [2]f32,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, position, size),
            .target = target,
            .constraints = constraints,
            .theme = theme,
            .target_theme = theme,
            .is_dragging = false,
            .drag_start = .{ 0, 0 },
            .start_size = .{ 0, 0 },
            .is_at_min_aspect = false,
            .is_at_max_aspect = false,
            .hover_scale = 1.0,
            .theme_transition = 0.0,
            .allocator = std.heap.page_allocator,
        };
    }

    pub fn setTheme(self: *Self, new_theme: ResizeHandleTheme) void {
        self.target_theme = new_theme;
        self.theme_transition = 0.0;
    }

    pub fn render(_self: *Self) void {
        // Update theme transition
        if (_self.theme_transition < 1.0) {
            _self.theme_transition = @min(
                1.0,
                _self.theme_transition + _self.theme.animations.theme_transition_speed,
            );

            // Interpolate theme properties
            _self.theme.handle_size = ResizeHandleTheme.lerpFloat(
                _self.theme.handle_size,
                _self.target_theme.handle_size,
                _self.theme_transition,
            );
            _self.theme.border_width = ResizeHandleTheme.lerpFloat(
                _self.theme.border_width,
                _self.target_theme.border_width,
                _self.theme_transition,
            );
            _self.theme.corner_radius = ResizeHandleTheme.lerpFloat(
                _self.theme.corner_radius,
                _self.target_theme.corner_radius,
                _self.theme_transition,
            );

            // Interpolate colors
            _self.theme.colors.normal = ResizeHandleTheme.lerpColor(
                _self.theme.colors.normal,
                _self.target_theme.colors.normal,
                _self.theme_transition,
            );
            _self.theme.colors.hover = ResizeHandleTheme.lerpColor(
                _self.theme.colors.hover,
                _self.target_theme.colors.hover,
                _self.theme_transition,
            );
            _self.theme.colors.active = ResizeHandleTheme.lerpColor(
                _self.theme.colors.active,
                _self.target_theme.colors.active,
                _self.theme_transition,
            );
            _self.theme.colors.border = ResizeHandleTheme.lerpColor(
                _self.theme.colors.border,
                _self.target_theme.colors.border,
                _self.theme_transition,
            );
            _self.theme.colors.fixed_aspect = ResizeHandleTheme.lerpColor(
                _self.theme.colors.fixed_aspect,
                _self.target_theme.colors.fixed_aspect,
                _self.theme_transition,
            );
            _self.theme.colors.min_aspect = ResizeHandleTheme.lerpColor(
                _self.theme.colors.min_aspect,
                _self.target_theme.colors.min_aspect,
                _self.theme_transition,
            );
            _self.theme.colors.max_aspect = ResizeHandleTheme.lerpColor(
                _self.theme.colors.max_aspect,
                _self.target_theme.colors.max_aspect,
                _self.theme_transition,
            );
            _self.theme.colors.ratio_bg = ResizeHandleTheme.lerpColor(
                _self.theme.colors.ratio_bg,
                _self.target_theme.colors.ratio_bg,
                _self.theme_transition,
            );
            _self.theme.colors.ratio_text = ResizeHandleTheme.lerpColor(
                _self.theme.colors.ratio_text,
                _self.target_theme.colors.ratio_text,
                _self.theme_transition,
            );
        }

        // Draw resize handle
        const handle_pos = c.ImVec2{
            .x = _self.target.position[0] + _self.target.size[0] - _self.theme.handle_size,
            .y = _self.target.position[1] + _self.target.size[1] - _self.theme.handle_size,
        };
        const handle_rect = c.ImVec4{
            .x = handle_pos.x,
            .y = handle_pos.y,
            .z = handle_pos.x + _self.theme.handle_size,
            .w = handle_pos.y + _self.theme.handle_size,
        };

        // Handle mouse interaction
        const mouse_pos = c.igGetMousePos();
        const is_hovered = mouse_pos.x >= handle_rect.x and
            mouse_pos.x <= handle_rect.z and
            mouse_pos.y >= handle_rect.y and
            mouse_pos.y <= handle_rect.w;

        // Update hover scale with smooth transition
        const target_scale = if (is_hovered)
            1.0 + _self.theme.animations.hover_scale
        else
            1.0;
        _self.hover_scale = ResizeHandleTheme.lerpFloat(
            _self.hover_scale,
            target_scale,
            _self.theme.animations.transition_speed,
        );

        // Determine handle color based on state and constraints
        var target_color = _self.theme.colors.normal;
        if (_self.is_dragging) {
            target_color = _self.theme.colors.active;
        } else if (is_hovered) {
            target_color = _self.theme.colors.hover;
        } else if (_self.constraints.aspect_ratio != null and _self.constraints.preserve_aspect) {
            target_color = _self.theme.colors.fixed_aspect;
        } else if (_self.is_at_min_aspect) {
            target_color = _self.theme.colors.min_aspect;
        } else if (_self.is_at_max_aspect) {
            target_color = _self.theme.colors.max_aspect;
        }

        // Smoothly transition to target color
        const handle_color = ResizeHandleTheme.lerpColor(
            _self.theme.colors.normal,
            target_color,
            _self.theme.animations.color_transition_speed,
        );

        // Calculate scaled handle size
        const scaled_size = _self.theme.handle_size * _self.hover_scale;
        const scaled_rect = c.ImVec4{
            .x = handle_pos.x - (scaled_size - _self.theme.handle_size) / 2,
            .y = handle_pos.y - (scaled_size - _self.theme.handle_size) / 2,
            .z = handle_pos.x + scaled_size,
            .w = handle_pos.y + scaled_size,
        };

        // Draw handle background
        c.igGetWindowDrawList().addRectFilled(
            .{ .x = scaled_rect.x, .y = scaled_rect.y },
            .{ .x = scaled_rect.z, .y = scaled_rect.w },
            c.igColorConvertFloat4ToU32(handle_color),
            _self.theme.corner_radius,
            0,
        );

        // Draw handle border
        c.igGetWindowDrawList().addRect(
            .{ .x = scaled_rect.x, .y = scaled_rect.y },
            .{ .x = scaled_rect.z, .y = scaled_rect.w },
            c.igColorConvertFloat4ToU32(_self.theme.colors.border),
            _self.theme.corner_radius,
            0,
            _self.theme.border_width,
        );

        // Draw aspect ratio indicator if constraints are active
        if (_self.constraints.min_aspect_ratio != null or _self.constraints.max_aspect_ratio != null) {
            const current_ratio = _self.target.size[0] / _self.target.size[1];
            const ratio_text = try std.fmt.allocPrint(
                _self.allocator,
                "{d:.1f}:1",
                .{current_ratio},
            );
            defer _self.allocator.free(ratio_text);

            const text_pos = c.ImVec2{
                .x = handle_pos.x - 40,
                .y = handle_pos.y - 20,
            };

            // Draw background for ratio text
            const text_size = c.igCalcTextSize(ratio_text.ptr, null, false, 0);
            c.igGetWindowDrawList().addRectFilled(
                .{ .x = text_pos.x - 2, .y = text_pos.y - 2 },
                .{ .x = text_pos.x + text_size.x + 2, .y = text_pos.y + text_size.y + 2 },
                c.igColorConvertFloat4ToU32(_self.theme.colors.ratio_bg),
                _self.theme.corner_radius,
                0,
            );

            // Draw ratio text
            c.igGetWindowDrawList().addText(
                .{ .x = text_pos.x, .y = text_pos.y },
                c.igColorConvertFloat4ToU32(_self.theme.colors.ratio_text),
                ratio_text.ptr,
                null,
            );
        }

        if (is_hovered) {
            c.igSetMouseCursor(c.ImGuiMouseCursor_ResizeNWSE);
        }

        if (c.igIsMouseClicked(c.ImGuiMouseButton_Left, false) and is_hovered) {
            _self.is_dragging = true;
            _self.drag_start = .{ mouse_pos.x, mouse_pos.y };
            _self.start_size = _self.target.size;
        }

        if (_self.is_dragging) {
            if (c.igIsMouseDown(c.ImGuiMouseButton_Left)) {
                const delta_x = mouse_pos.x - _self.drag_start[0];
                const delta_y = mouse_pos.y - _self.drag_start[1];
                var new_size = .{
                    _self.start_size[0] + delta_x,
                    _self.start_size[1] + delta_y,
                };

                // Store previous aspect ratio state
                const prev_min_aspect = _self.is_at_min_aspect;
                const prev_max_aspect = _self.is_at_max_aspect;

                // Apply constraints and update aspect ratio state
                _self.constraints.apply(&new_size);
                const current_ratio = new_size[0] / new_size[1];
                _self.is_at_min_aspect = if (_self.constraints.min_aspect_ratio) |min_ratio|
                    @abs(current_ratio - min_ratio) < 0.01
                else
                    false;
                _self.is_at_max_aspect = if (_self.constraints.max_aspect_ratio) |max_ratio|
                    @abs(current_ratio - max_ratio) < 0.01
                else
                    false;

                // Update target size
                _self.target.size = new_size;

                // Show tooltip when aspect ratio state changes
                if (_self.is_at_min_aspect != prev_min_aspect or _self.is_at_max_aspect != prev_max_aspect) {
                    if (_self.is_at_min_aspect) {
                        c.igSetTooltip("Minimum aspect ratio reached");
                    } else if (_self.is_at_max_aspect) {
                        c.igSetTooltip("Maximum aspect ratio reached");
                    }
                }
            } else {
                _self.is_dragging = false;
            }
        }
    }
};

/// A layout container that automatically positions its child widgets
pub const Layout = struct {
    const Self = @This();

    widget: widgets.Widget,
    direction: Direction,
    alignment: Alignment,
    padding: Padding,
    spacing: f32,
    children: std.ArrayList(*widgets.Widget),
    size: [2]f32,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        direction: Direction,
        alignment: Alignment,
        padding: Padding,
        spacing: f32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, pos, size),
            .direction = direction,
            .alignment = alignment,
            .padding = padding,
            .spacing = spacing,
            .children = std.ArrayList(*widgets.Widget).init(std.heap.page_allocator),
            .size = size,
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *widgets.Widget) !void {
        try self.children.append(child);
    }

    pub fn render(self: *Self) void {
        const window_pos = c.igGetWindowPos();
        const current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate available space
        const available_width = self.size[0] - self.padding.left - self.padding.right;
        const available_height = self.size[1] - self.padding.top - self.padding.bottom;

        // Calculate total size of children
        var total_size: [2]f32 = .{ 0, 0 };
        for (self.children.items) |child| {
            if (self.direction == .Horizontal) {
                total_size[0] += child.size[0];
                total_size[1] = @max(total_size[1], child.size[1]);
            } else {
                total_size[0] = @max(total_size[0], child.size[0]);
                total_size[1] += child.size[1];
            }
        }

        // Add spacing between items
        if (self.children.items.len > 1) {
            if (self.direction == .Horizontal) {
                total_size[0] += self.spacing * @as(f32, @floatFromInt(self.children.items.len - 1));
            } else {
                total_size[1] += self.spacing * @as(f32, @floatFromInt(self.children.items.len - 1));
            }
        }

        // Calculate alignment offsets
        var alignment_offset: [2]f32 = .{ 0, 0 };
        switch (self.alignment) {
            .Start => {},
            .Center => {
                if (self.direction == .Horizontal) {
                    alignment_offset[1] = (available_height - total_size[1]) / 2;
                } else {
                    alignment_offset[0] = (available_width - total_size[0]) / 2;
                }
            },
            .End => {
                if (self.direction == .Horizontal) {
                    alignment_offset[1] = available_height - total_size[1];
                } else {
                    alignment_offset[0] = available_width - total_size[0];
                }
            },
            .SpaceBetween => {
                if (self.children.items.len > 1) {
                    const space = if (self.direction == .Horizontal)
                        (available_width - total_size[0]) / @as(f32, @floatFromInt(self.children.items.len - 1))
                    else
                        (available_height - total_size[1]) / @as(f32, @floatFromInt(self.children.items.len - 1));
                    self.spacing = space;
                }
            },
            .SpaceAround => {
                if (self.children.items.len > 0) {
                    const space = if (self.direction == .Horizontal)
                        (available_width - total_size[0]) / @as(f32, @floatFromInt(self.children.items.len + 1))
                    else
                        (available_height - total_size[1]) / @as(f32, @floatFromInt(self.children.items.len + 1));
                    self.spacing = space;
                    if (self.direction == .Horizontal) {
                        current_pos[0] += space;
                    } else {
                        current_pos[1] += space;
                    }
                }
            },
        }

        // Position and render children
        for (self.children.items) |child| {
            child.pos = .{
                current_pos[0] + alignment_offset[0],
                current_pos[1] + alignment_offset[1],
            };
            child.render();

            // Update position for next child
            if (self.direction == .Horizontal) {
                current_pos[0] += child.size[0] + self.spacing;
            } else {
                current_pos[1] += child.size[1] + self.spacing;
            }
        }
    }
};

/// A grid layout that arranges widgets in rows and columns
pub const GridLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    columns: usize,
    padding: Padding,
    spacing: [2]f32,
    children: std.ArrayList(*widgets.Widget),
    size: [2]f32,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        columns: usize,
        padding: Padding,
        spacing: [2]f32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, pos, size),
            .columns = columns,
            .padding = padding,
            .spacing = spacing,
            .children = std.ArrayList(*widgets.Widget).init(std.heap.page_allocator),
            .size = size,
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *widgets.Widget) !void {
        try self.children.append(child);
    }

    pub fn render(self: *Self) void {
        const window_pos = c.igGetWindowPos();
        const current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate cell size
        const available_width = self.size[0] - self.padding.left - self.padding.right;
        const cell_width = (available_width - (self.spacing[0] * @as(f32, @floatFromInt(self.columns - 1)))) / @as(f32, @floatFromInt(self.columns));

        var row: usize = 0;
        var col: usize = 0;

        // Position and render children
        for (self.children.items) |child| {
            child.pos = .{
                current_pos[0] + (cell_width + self.spacing[0]) * @as(f32, @floatFromInt(col)),
                current_pos[1] + (child.size[1] + self.spacing[1]) * @as(f32, @floatFromInt(row)),
            };
            child.size[0] = cell_width;
            child.render();

            col += 1;
            if (col >= self.columns) {
                col = 0;
                row += 1;
            }
        }
    }
};

/// A scrollable layout container
pub const ScrollLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    direction: Direction,
    padding: Padding,
    spacing: f32,
    children: std.ArrayList(*widgets.Widget),
    size: [2]f32,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        direction: Direction,
        padding: Padding,
        spacing: f32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, pos, size),
            .direction = direction,
            .padding = padding,
            .spacing = spacing,
            .children = std.ArrayList(*widgets.Widget).init(std.heap.page_allocator),
            .size = size,
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *widgets.Widget) !void {
        try self.children.append(child);
    }

    pub fn render(self: *Self) void {
        const window_pos = c.igGetWindowPos();
        const current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate content size
        var content_size: [2]f32 = .{ 0, 0 };
        for (self.children.items) |child| {
            if (self.direction == .Horizontal) {
                content_size[0] += child.size[0];
                content_size[1] = @max(content_size[1], child.size[1]);
            } else {
                content_size[0] = @max(content_size[0], child.size[0]);
                content_size[1] += child.size[1];
            }
        }

        // Add spacing
        if (self.children.items.len > 1) {
            if (self.direction == .Horizontal) {
                content_size[0] += self.spacing * @as(f32, @floatFromInt(self.children.items.len - 1));
            } else {
                content_size[1] += self.spacing * @as(f32, @floatFromInt(self.children.items.len - 1));
            }
        }

        // Begin scrolling region
        if (c.igBeginChild(
            self.widget.id,
            .{ self.size[0], self.size[1] },
            true,
            self.flags,
        )) {
            // Position and render children
            for (self.children.items) |child| {
                child.pos = current_pos;
                child.render();

                if (self.direction == .Horizontal) {
                    current_pos[0] += child.size[0] + self.spacing;
                } else {
                    current_pos[1] += child.size[1] + self.spacing;
                }
            }
        }
        c.igEndChild();
    }
};

/// A flexible layout that supports growing and shrinking of child widgets
pub const FlexLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    direction: Direction,
    alignment: Alignment,
    padding: Padding,
    spacing: f32,
    children: std.ArrayList(struct {
        widget: *widgets.Widget,
        flex: FlexProperties,
    }),
    size: [2]f32,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        direction: Direction,
        alignment: Alignment,
        padding: Padding,
        spacing: f32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, pos, size),
            .direction = direction,
            .alignment = alignment,
            .padding = padding,
            .spacing = spacing,
            .children = std.ArrayList(struct {
                widget: *widgets.Widget,
                flex: FlexProperties,
            }).init(std.heap.page_allocator),
            .size = size,
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *widgets.Widget, flex: FlexProperties) !void {
        try self.children.append(.{
            .widget = child,
            .flex = flex,
        });
    }

    pub fn render(self: *Self) void {
        const window_pos = c.igGetWindowPos();
        const current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate available space
        const available_width = self.size[0] - self.padding.left - self.padding.right;
        const available_height = self.size[1] - self.padding.top - self.padding.bottom;

        // Calculate total flex grow and fixed size
        var total_flex_grow: f32 = 0;
        var total_fixed_size: f32 = 0;
        for (self.children.items) |item| {
            total_flex_grow += item.flex.grow;
            if (self.direction == .Horizontal) {
                total_fixed_size += item.widget.size[0];
            } else {
                total_fixed_size += item.widget.size[1];
            }
        }

        // Add spacing
        if (self.children.items.len > 1) {
            total_fixed_size += self.spacing * @as(f32, @floatFromInt(self.children.items.len - 1));
        }

        // Calculate remaining space
        const remaining_space = if (self.direction == .Horizontal)
            available_width - total_fixed_size
        else
            available_height - total_fixed_size;

        // Position and render children
        for (self.children.items) |item| {
            // Calculate flex size
            const flex_size = if (total_flex_grow > 0)
                (remaining_space * item.flex.grow) / total_flex_grow
            else
                0;

            // Update widget size
            if (self.direction == .Horizontal) {
                item.widget.size[0] += flex_size;
            } else {
                item.widget.size[1] += flex_size;
            }

            // Position widget
            item.widget.pos = current_pos;
            item.widget.render();

            // Update position for next widget
            if (self.direction == .Horizontal) {
                current_pos[0] += item.widget.size[0] + self.spacing;
            } else {
                current_pos[1] += item.widget.size[1] + self.spacing;
            }
        }
    }
};

/// A stack layout that overlays widgets on top of each other
pub const StackLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    padding: Padding,
    children: std.ArrayList(*widgets.Widget),
    size: [2]f32,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        padding: Padding,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, pos, size),
            .padding = padding,
            .children = std.ArrayList(*widgets.Widget).init(std.heap.page_allocator),
            .size = size,
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *widgets.Widget) !void {
        try self.children.append(child);
    }

    pub fn render(self: *Self) void {
        const window_pos = c.igGetWindowPos();
        const current_pos = [2]f32{
            window_pos.x + self.padding.left + (self.size[0] - self.padding.left - self.padding.right) / 2,
            window_pos.y + self.padding.top + (self.size[1] - self.padding.top - self.padding.bottom) / 2,
        };

        // Position and render children
        for (self.children.items) |child| {
            // Center the child widget
            child.pos = .{
                current_pos[0] - child.size[0] / 2,
                current_pos[1] - child.size[1] / 2,
            };
            child.render();
        }
    }
};

/// A split layout that divides space between two widgets
pub const SplitLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    direction: Direction,
    ratio: f32,
    padding: Padding,
    spacing: f32,
    first: *widgets.Widget,
    second: *widgets.Widget,
    size: [2]f32,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        direction: Direction,
        ratio: f32,
        padding: Padding,
        spacing: f32,
        first: *widgets.Widget,
        second: *widgets.Widget,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, pos, size),
            .direction = direction,
            .ratio = ratio,
            .padding = padding,
            .spacing = spacing,
            .first = first,
            .second = second,
            .size = size,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        const window_pos = c.igGetWindowPos();
        const current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate available space
        const available_width = self.size[0] - self.padding.left - self.padding.right;
        const available_height = self.size[1] - self.padding.top - self.padding.bottom;

        // Calculate split sizes
        const first_size = if (self.direction == .Horizontal)
            (available_width - self.spacing) * self.ratio
        else
            (available_height - self.spacing) * self.ratio;

        const second_size = if (self.direction == .Horizontal)
            available_width - first_size - self.spacing
        else
            available_height - first_size - self.spacing;

        // Position and render first widget
        self.first.pos = current_pos;
        if (self.direction == .Horizontal) {
            self.first.size[0] = first_size;
            current_pos[0] += first_size + self.spacing;
        } else {
            self.first.size[1] = first_size;
            current_pos[1] += first_size + self.spacing;
        }
        self.first.render();

        // Position and render second widget
        self.second.pos = current_pos;
        if (self.direction == .Horizontal) {
            self.second.size[0] = second_size;
        } else {
            self.second.size[1] = second_size;
        }
        self.second.render();
    }
};

/// A layout that wraps widgets to the next line when they don't fit
pub const WrapLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    children: std.ArrayList(*widgets.Widget),
    padding: Padding,
    spacing: f32,
    flags: c.ImGuiWindowFlags,
    allocator: std.mem.Allocator,

    pub fn init(
        id: [*:0]const u8,
        padding: Padding,
        spacing: f32,
        position: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, position, size),
            .children = std.ArrayList(*widgets.Widget).init(std.heap.page_allocator),
            .padding = padding,
            .spacing = spacing,
            .flags = flags,
            .allocator = std.heap.page_allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *widgets.Widget) !void {
        try self.children.append(child);
    }

    pub fn render(self: *Self) void {
        if (c.igBeginChild(self.widget.id, .{ self.widget.size[0], self.widget.size[1] }, self.flags)) {
            var current_x: f32 = self.padding.left;
            var current_y: f32 = self.padding.top;
            var max_height: f32 = 0;

            for (self.children.items) |child| {
                if (current_x + child.size[0] > self.widget.size[0] - self.padding.right) {
                    current_x = self.padding.left;
                    current_y += max_height + self.spacing;
                    max_height = 0;
                }

                child.position = .{ current_x, current_y };
                child.render();

                current_x += child.size[0] + self.spacing;
                max_height = @max(max_height, child.size[1]);
            }
        }
        c.igEndChild();
    }
};

/// A layout that flows widgets in a natural reading order
pub const FlowLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    children: std.ArrayList(*widgets.Widget),
    padding: Padding,
    spacing: f32,
    flags: c.ImGuiWindowFlags,
    allocator: std.mem.Allocator,
    direction: enum { LeftToRight, RightToLeft, TopToBottom, BottomToTop },

    pub fn init(
        id: [*:0]const u8,
        direction: enum { LeftToRight, RightToLeft, TopToBottom, BottomToTop },
        padding: Padding,
        spacing: f32,
        position: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, position, size),
            .children = std.ArrayList(*widgets.Widget).init(std.heap.page_allocator),
            .padding = padding,
            .spacing = spacing,
            .flags = flags,
            .allocator = std.heap.page_allocator,
            .direction = direction,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *widgets.Widget) !void {
        try self.children.append(child);
    }

    pub fn render(self: *Self) void {
        if (c.igBeginChild(self.widget.id, .{ self.widget.size[0], self.widget.size[1] }, self.flags)) {
            var current_x: f32 = switch (self.direction) {
                .LeftToRight, .TopToBottom => self.padding.left,
                .RightToLeft => self.widget.size[0] - self.padding.right,
                .BottomToTop => self.padding.left,
            };
            var current_y: f32 = switch (self.direction) {
                .LeftToRight, .RightToLeft => self.padding.top,
                .TopToBottom => self.padding.top,
                .BottomToTop => self.widget.size[1] - self.padding.bottom,
            };

            for (self.children.items) |child| {
                switch (self.direction) {
                    .LeftToRight => {
                        if (current_x + child.size[0] > self.widget.size[0] - self.padding.right) {
                            current_x = self.padding.left;
                            current_y += child.size[1] + self.spacing;
                        }
                        child.position = .{ current_x, current_y };
                        current_x += child.size[0] + self.spacing;
                    },
                    .RightToLeft => {
                        if (current_x - child.size[0] < self.padding.left) {
                            current_x = self.widget.size[0] - self.padding.right;
                            current_y += child.size[1] + self.spacing;
                        }
                        child.position = .{ current_x - child.size[0], current_y };
                        current_x -= child.size[0] + self.spacing;
                    },
                    .TopToBottom => {
                        if (current_y + child.size[1] > self.widget.size[1] - self.padding.bottom) {
                            current_y = self.padding.top;
                            current_x += child.size[0] + self.spacing;
                        }
                        child.position = .{ current_x, current_y };
                        current_y += child.size[1] + self.spacing;
                    },
                    .BottomToTop => {
                        if (current_y - child.size[1] < self.padding.top) {
                            current_y = self.widget.size[1] - self.padding.bottom;
                            current_x += child.size[0] + self.spacing;
                        }
                        child.position = .{ current_x, current_y - child.size[1] };
                        current_y -= child.size[1] + self.spacing;
                    },
                }
                child.render();
            }
        }
        c.igEndChild();
    }
};

/// A layout that supports resizable widgets
pub const ResizableLayout = struct {
    const Self = @This();

    widget: widgets.Widget,
    children: std.ArrayList(*widgets.Widget),
    handles: std.ArrayList(ResizeHandle),
    padding: Padding,
    spacing: f32,
    flags: c.ImGuiWindowFlags,
    allocator: std.mem.Allocator,

    pub fn init(
        id: [*:0]const u8,
        padding: Padding,
        spacing: f32,
        position: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, position, size),
            .children = std.ArrayList(*widgets.Widget).init(std.heap.page_allocator),
            .handles = std.ArrayList(ResizeHandle).init(std.heap.page_allocator),
            .padding = padding,
            .spacing = spacing,
            .flags = flags,
            .allocator = std.heap.page_allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
        self.handles.deinit();
    }

    pub fn addChild(
        self: *Self,
        child: *widgets.Widget,
        constraints: ResizeConstraints,
    ) !void {
        try self.children.append(child);

        const handle_id = try std.fmt.allocPrint(
            self.allocator,
            "{s}_handle_{d}",
            .{ self.widget.id, self.children.items.len - 1 },
        );
        defer self.allocator.free(handle_id);

        const handle = ResizeHandle.init(
            handle_id.ptr,
            child,
            constraints,
            .{ 0, 0 },
            .{ 8, 8 },
        );
        try self.handles.append(handle);
    }

    pub fn render(self: *Self) void {
        if (c.igBeginChild(self.widget.id, .{ self.widget.size[0], self.widget.size[1] }, self.flags)) {
            var current_x: f32 = self.padding.left;
            var current_y: f32 = self.padding.top;
            var max_height: f32 = 0;

            // Render children
            for (self.children.items) |child| {
                if (current_x + child.size[0] > self.widget.size[0] - self.padding.right) {
                    current_x = self.padding.left;
                    current_y += max_height + self.spacing;
                    max_height = 0;
                }

                child.position = .{ current_x, current_y };
                child.render();

                current_x += child.size[0] + self.spacing;
                max_height = @max(max_height, child.size[1]);
            }

            // Render resize handles
            for (self.handles.items) |*handle| {
                handle.render();
            }
        }
        c.igEndChild();
    }
}; 