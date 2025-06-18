const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
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

    pub fn horizontal(horizontal: f32) Padding {
        return .{
            .left = horizontal,
            .right = horizontal,
        };
    }

    pub fn vertical(vertical: f32) Padding {
        return .{
            .top = vertical,
            .bottom = vertical,
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

/// Resize handle for widgets
pub const ResizeHandle = struct {
    const Self = @This();

    widget: widgets.Widget,
    target: *widgets.Widget,
    constraints: ResizeConstraints,
    is_dragging: bool,
    drag_start: [2]f32,
    start_size: [2]f32,

    pub fn init(
        id: [*:0]const u8,
        target: *widgets.Widget,
        constraints: ResizeConstraints,
        position: [2]f32,
        size: [2]f32,
    ) Self {
        return Self{
            .widget = widgets.Widget.init(id, position, size),
            .target = target,
            .constraints = constraints,
            .is_dragging = false,
            .drag_start = .{ 0, 0 },
            .start_size = .{ 0, 0 },
        };
    }

    pub fn render(self: *Self) void {
        const handle_size: f32 = 8;
        const handle_color = c.ImVec4{ .x = 0.5, .y = 0.5, .z = 0.5, .w = 0.5 };

        // Draw resize handle
        const handle_pos = c.ImVec2{
            .x = self.target.position[0] + self.target.size[0] - handle_size,
            .y = self.target.position[1] + self.target.size[1] - handle_size,
        };
        const handle_rect = c.ImVec4{
            .x = handle_pos.x,
            .y = handle_pos.y,
            .z = handle_pos.x + handle_size,
            .w = handle_pos.y + handle_size,
        };

        c.igGetWindowDrawList().addRectFilled(
            .{ .x = handle_rect.x, .y = handle_rect.y },
            .{ .x = handle_rect.z, .y = handle_rect.w },
            c.igColorConvertFloat4ToU32(handle_color),
            0,
            0,
        );

        // Handle mouse interaction
        const mouse_pos = c.igGetMousePos();
        const is_hovered = mouse_pos.x >= handle_rect.x and
            mouse_pos.x <= handle_rect.z and
            mouse_pos.y >= handle_rect.y and
            mouse_pos.y <= handle_rect.w;

        if (is_hovered) {
            c.igSetMouseCursor(c.ImGuiMouseCursor_ResizeNWSE);
        }

        if (c.igIsMouseClicked(c.ImGuiMouseButton_Left, false) and is_hovered) {
            self.is_dragging = true;
            self.drag_start = .{ mouse_pos.x, mouse_pos.y };
            self.start_size = self.target.size;
        }

        if (self.is_dragging) {
            if (c.igIsMouseDown(c.ImGuiMouseButton_Left)) {
                const delta_x = mouse_pos.x - self.drag_start[0];
                const delta_y = mouse_pos.y - self.drag_start[1];
                var new_size = .{
                    self.start_size[0] + delta_x,
                    self.start_size[1] + delta_y,
                };
                self.constraints.apply(&new_size);
                self.target.size = new_size;
            } else {
                self.is_dragging = false;
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
        const style = c.igGetStyle();
        const window_pos = c.igGetWindowPos();
        const window_size = c.igGetWindowSize();
        var current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate available space
        const available_width = window_size.x - self.padding.left - self.padding.right;
        const available_height = window_size.y - self.padding.top - self.padding.bottom;

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
        const window_size = c.igGetWindowSize();
        var current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate cell size
        const available_width = window_size.x - self.padding.left - self.padding.right;
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
        const window_size = c.igGetWindowSize();
        var current_pos = [2]f32{
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
            .{ .x = self.size[0], .y = self.size[1] },
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
        const window_size = c.igGetWindowSize();
        var current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate available space
        const available_width = window_size.x - self.padding.left - self.padding.right;
        const available_height = window_size.y - self.padding.top - self.padding.bottom;

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
        const window_size = c.igGetWindowSize();
        const center_pos = [2]f32{
            window_pos.x + self.padding.left + (window_size.x - self.padding.left - self.padding.right) / 2,
            window_pos.y + self.padding.top + (window_size.y - self.padding.top - self.padding.bottom) / 2,
        };

        // Position and render children
        for (self.children.items) |child| {
            // Center the child widget
            child.pos = .{
                center_pos[0] - child.size[0] / 2,
                center_pos[1] - child.size[1] / 2,
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
        const window_size = c.igGetWindowSize();
        var current_pos = [2]f32{
            window_pos.x + self.padding.left,
            window_pos.y + self.padding.top,
        };

        // Calculate available space
        const available_width = window_size.x - self.padding.left - self.padding.right;
        const available_height = window_size.y - self.padding.top - self.padding.bottom;

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