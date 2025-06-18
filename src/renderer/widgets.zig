const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
});
const Widget = @import("imgui.zig").Widget;

pub const Button = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    callback: ?*const fn () void,

    pub fn init(id: []const u8, label: []const u8, position: [2]f32, size: [2]f32, callback: ?*const fn () void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .callback = callback,
        };
    }

    fn render(widget: *Widget) !void {
        const self = @fieldParentPtr(Self, "widget", widget);
        if (c.igButton(self.label.ptr, c.ImVec2{ .x = self.widget.size[0], .y = self.widget.size[1] })) {
            if (self.callback) |cb| {
                cb();
            }
        }
    }
};

pub const Slider = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    value: *f32,
    min: f32,
    max: f32,
    format: []const u8,
    callback: ?*const fn (f32) void,

    pub fn init(id: []const u8, label: []const u8, value: *f32, min: f32, max: f32, format: []const u8, position: [2]f32, size: [2]f32, callback: ?*const fn (f32) void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .value = value,
            .min = min,
            .max = max,
            .format = format,
            .callback = callback,
        };
    }

    fn render(widget: *Widget) !void {
        const self = @fieldParentPtr(Self, "widget", widget);
        if (c.igSliderFloat(self.label.ptr, self.value, self.min, self.max, self.format.ptr)) {
            if (self.callback) |cb| {
                cb(self.value.*);
            }
        }
    }
};

pub const Checkbox = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    value: *bool,
    callback: ?*const fn (bool) void,

    pub fn init(id: []const u8, label: []const u8, value: *bool, position: [2]f32, size: [2]f32, callback: ?*const fn (bool) void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .value = value,
            .callback = callback,
        };
    }

    fn render(widget: *Widget) !void {
        const self = @fieldParentPtr(Self, "widget", widget);
        if (c.igCheckbox(self.label.ptr, self.value)) {
            if (self.callback) |cb| {
                cb(self.value.*);
            }
        }
    }
};

pub const Text = struct {
    const Self = @This();

    widget: Widget,
    text: []const u8,
    color: ?[4]f32,

    pub fn init(id: []const u8, text: []const u8, position: [2]f32, size: [2]f32, color: ?[4]f32) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .text = text,
            .color = color,
        };
    }

    fn render(widget: *Widget) !void {
        const self = @fieldParentPtr(Self, "widget", widget);
        if (self.color) |color| {
            c.igPushStyleColor(c.ImGuiCol_Text, c.ImVec4{ .x = color[0], .y = color[1], .z = color[2], .w = color[3] });
        }
        c.igText(self.text.ptr);
        if (self.color != null) {
            c.igPopStyleColor(1);
        }
    }
};

pub const Plot = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    values: []const f32,
    values_count: i32,
    values_offset: i32,
    overlay_text: ?[]const u8,
    scale_min: f32,
    scale_max: f32,
    graph_size: [2]f32,

    pub fn init(id: []const u8, label: []const u8, values: []const f32, position: [2]f32, size: [2]f32) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .values = values,
            .values_count = @intCast(values.len),
            .values_offset = 0,
            .overlay_text = null,
            .scale_min = std.math.floatMin(f32),
            .scale_max = std.math.floatMax(f32),
            .graph_size = size,
        };
    }

    fn render(widget: *Widget) !void {
        const self = @fieldParentPtr(Self, "widget", widget);
        c.igPlotLines(
            self.label.ptr,
            self.values.ptr,
            self.values_count,
            self.values_offset,
            if (self.overlay_text) |text| text.ptr else null,
            self.scale_min,
            self.scale_max,
            c.ImVec2{ .x = self.graph_size[0], .y = self.graph_size[1] },
        );
    }
};

pub const Window = struct {
    const Self = @This();

    widget: Widget,
    title: []const u8,
    flags: c.ImGuiWindowFlags,
    children: std.ArrayList(*Widget),

    pub fn init(id: []const u8, title: []const u8, position: [2]f32, size: [2]f32, flags: c.ImGuiWindowFlags) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .title = title,
            .flags = flags,
            .children = std.ArrayList(*Widget).init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.children.deinit();
    }

    pub fn addChild(self: *Self, child: *Widget) !void {
        try self.children.append(child);
    }

    fn render(widget: *Widget) !void {
        const self = @fieldParentPtr(Self, "widget", widget);
        c.igSetNextWindowPos(c.ImVec2{ .x = self.widget.position[0], .y = self.widget.position[1] }, c.ImGuiCond_FirstUseEver, c.ImVec2{ .x = 0, .y = 0 });
        c.igSetNextWindowSize(c.ImVec2{ .x = self.widget.size[0], .y = self.widget.size[1] }, c.ImGuiCond_FirstUseEver);

        if (c.igBegin(self.title.ptr, null, self.flags)) {
            for (self.children.items) |child| {
                try child.render();
            }
        }
        c.igEnd();
    }
}; 