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