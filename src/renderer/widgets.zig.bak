const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
});
pub const Widget = @import("imgui.zig").Widget;

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
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        if (c.igButton(self.label.ptr, c.ImVec2{ .x = self.widget.size[0], .y = self.widget.size[1] })) {
            if (self.callback) |cb| {
                cb();
            }
        }
    }
};

/// A slider widget for selecting a value within a range
pub const Slider = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *f32,
    min: f32,
    max: f32,
    format: [*:0]const u8,
    flags: c.ImGuiSliderFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *f32,
        min: f32,
        max: f32,
        format: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSliderFlags,
    ) Self {
        return Self{
            .widget = Widget.init(id, pos, size),
            .label = label,
            .value = value,
            .min = min,
            .max = max,
            .format = format,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        _ = c.igSliderFloat(
            widget.label,
            widget.value,
            widget.min,
            widget.max,
            widget.format,
            widget.flags,
        );
    }
};

/// A knob widget for circular value selection
pub const Knob = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *f32,
    min: f32,
    max: f32,
    size: f32,
    flags: c.ImGuiSliderFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *f32,
        min: f32,
        max: f32,
        size: f32,
        pos: [2]f32,
        flags: c.ImGuiSliderFlags,
    ) Self {
        return Self{
            .widget = Widget.init(id, pos, .{ size, size }),
            .label = label,
            .value = value,
            .min = min,
            .max = max,
            .size = size,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        _ = c.igVSliderFloat(
            widget.label,
            .{ widget.size, widget.size },
            widget.value,
            widget.min,
            widget.max,
            "%.2f",
            widget.flags,
        );
    }
};

/// A checkbox widget for boolean values
pub const Checkbox = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *bool,
    flags: c.ImGuiSelectableFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *bool,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSelectableFlags,
    ) Self {
        return Self{
            .widget = Widget.init(id, pos, size),
            .label = label,
            .value = value,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        _ = c.igCheckbox(widget.label, widget.value);
    }
};

/// A radio button widget for selecting from multiple options
pub const RadioButton = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *i32,
    button_value: i32,
    flags: c.ImGuiSelectableFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *i32,
        button_value: i32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSelectableFlags,
    ) Self {
        return Self{
            .widget = Widget.init(id, pos, size),
            .label = label,
            .value = value,
            .button_value = button_value,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        if (c.igRadioButton(widget.label, widget.value, widget.button_value)) {
            widget.value.* = widget.button_value;
        }
    }
};

/// A progress bar widget for displaying progress
pub const ProgressBar = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: f32,
    overlay: ?[*:0]const u8,
    size: [2]f32,
    flags: c.ImGuiProgressBarFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: f32,
        overlay: ?[*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiProgressBarFlags,
    ) Self {
        return Self{
            .widget = Widget.init(id, pos, size),
            .label = label,
            .value = value,
            .overlay = overlay,
            .size = size,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        c.igProgressBar(
            widget.value,
            &widget.size,
            widget.overlay,
        );
    }
};

/// A tooltip widget for displaying additional information
pub const Tooltip = struct {
    const Self = @This();

    widget: Widget,
    text: [*:0]const u8,
    flags: c.ImGuiTooltipFlags,

    pub fn init(
        id: [*:0]const u8,
        text: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiTooltipFlags,
    ) Self {
        return Self{
            .widget = Widget.init(id, pos, size),
            .text = text,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        if (c.igBeginTooltip()) {
            c.igText(widget.text);
            c.igEndTooltip();
        }
    }
};

/// A collapsible header widget
pub const CollapsingHeader = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    flags: c.ImGuiTreeNodeFlags,
    is_open: *bool,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        is_open: *bool,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiTreeNodeFlags,
    ) Self {
        return Self{
            .widget = Widget.init(id, pos, size),
            .label = label,
            .is_open = is_open,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        widget.is_open.* = c.igCollapsingHeader(
            widget.label,
            widget.flags,
        );
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
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
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
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
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
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
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

pub const Dropdown = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    items: []const []const u8,
    selected_index: *usize,
    callback: ?*const fn (usize) void,

    pub fn init(id: []const u8, label: []const u8, items: []const []const u8, selected_index: *usize, position: [2]f32, size: [2]f32, callback: ?*const fn (usize) void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .items = items,
            .selected_index = selected_index,
            .callback = callback,
        };
    }

    fn render(widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        if (c.igBeginCombo(self.label.ptr, self.items[self.selected_index.*].ptr)) {
            for (self.items, 0..) |item, i| {
                const is_selected = i == self.selected_index.*;
                if (c.igSelectable(item.ptr, is_selected)) {
                    self.selected_index.* = i;
                    if (self.callback) |cb| {
                        cb(i);
                    }
                }
                if (is_selected) {
                    c.igSetItemDefaultFocus();
                }
            }
            c.igEndCombo();
        }
    }
};

pub const ColorPicker = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    color: *[4]f32,
    flags: c.ImGuiColorEditFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        color: *[4]f32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiColorEditFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .color = color,
            .flags = flags,
        };
    }

    pub fn render(widget: *Widget) void {
        _ = c.igColorEdit4(widget.label, &widget.color[0], widget.flags);
    }
};

pub const InputText = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    buffer: [*:0]u8,
    buffer_size: usize,
    flags: c.ImGuiInputTextFlags,
    callback: ?*const fn([*:0]const u8) void,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        buffer: [*:0]u8,
        buffer_size: usize,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiInputTextFlags,
        callback: ?*const fn([*:0]const u8) void,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .buffer = buffer,
            .buffer_size = buffer_size,
            .flags = flags,
            .callback = callback,
        };
    }

    pub fn render(widget: *Widget) void {
        _ = c.igInputText(widget.label, widget.buffer, widget.buffer_size, widget.flags, null, null);
    }
};

pub const Separator = struct {
    const Self = @This();

    widget: Widget,

    pub fn init(id: []const u8, position: [2]f32, size: [2]f32) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
        };
    }

    fn render(_widget: *Widget) !void {
        _ = _widget;
        c.igSeparator();
    }
};

pub const Table = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    columns: []const []const u8,
    flags: c.ImGuiTableFlags,
    row_callback: ?*const fn (usize) void,
    cell_callback: ?*const fn (usize, usize) void,

    pub fn init(id: []const u8, label: []const u8, columns: []const []const u8, position: [2]f32, size: [2]f32, flags: c.ImGuiTableFlags, row_callback: ?*const fn (usize) void, cell_callback: ?*const fn (usize, usize) void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .columns = columns,
            .flags = flags,
            .row_callback = row_callback,
            .cell_callback = cell_callback,
        };
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        if (c.igBeginTable(self.label.ptr, @intCast(self.columns.len), self.flags)) {
            // Setup columns
            for (self.columns) |column| {
                c.igTableSetupColumn(column.ptr, c.ImGuiTableColumnFlags_None, 0.0);
            }
            c.igTableHeadersRow();

            // Render rows
            var row: usize = 0;
            while (row < 10) : (row += 1) { // Example: 10 rows
                c.igTableNextRow(c.ImGuiTableRowFlags_None, 0.0);
                
                if (self.row_callback) |cb| {
                    cb(row);
                }

                // Render cells
                for (self.columns, 0..) |_, col| {
                    c.igTableNextColumn();
                    if (self.cell_callback) |cb| {
                        cb(row, col);
                    }
                }
            }
            c.igEndTable();
        }
    }
};

pub const DragDrop = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    payload_type: []const u8,
    data: []const u8,
    callback: ?*const fn ([]const u8) void,

    pub fn init(id: []const u8, label: []const u8, payload_type: []const u8, data: []const u8, position: [2]f32, size: [2]f32, callback: ?*const fn ([]const u8) void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .payload_type = payload_type,
            .data = data,
            .callback = callback,
        };
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        // Source
        if (c.igBeginDragDropSource(c.ImGuiDragDropFlags_None)) {
            c.igSetDragDropPayload(self.payload_type.ptr, self.data.ptr, self.data.len, c.ImGuiCond_Once);
            c.igText(self.label.ptr);
            c.igEndDragDropSource();
        }

        // Target
        if (c.igBeginDragDropTarget()) {
            if (c.igAcceptDragDropPayload(self.payload_type.ptr, c.ImGuiDragDropFlags_None)) |payload| {
                if (self.callback) |cb| {
                    const data = payload.data[0..payload.data_size];
                    cb(data);
                }
            }
            c.igEndDragDropTarget();
        }
    }
};

pub const FileDialog = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    current_path: [*:0]u8,
    selected_file: [*:0]u8,
    file_filter: [*:0]const u8,
    callback: ?*const fn([*:0]const u8) void,
    flags: c.ImGuiWindowFlags,
    is_open: bool,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        current_path: [*:0]u8,
        selected_file: [*:0]u8,
        file_filter: [*:0]const u8,
        callback: ?*const fn([*:0]const u8) void,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .current_path = current_path,
            .selected_file = selected_file,
            .file_filter = file_filter,
            .callback = callback,
            .flags = flags,
            .is_open = false,
        };
    }

    pub fn open(self: *Self) void {
        self.is_open = true;
    }

    pub fn close(self: *Self) void {
        self.is_open = false;
    }

    pub fn render(_self: *Self) void {
        if (_self.is_open) {
            if (c.igBegin(_self.label, &_self.is_open, _self.flags)) {
                // TODO: Implement file dialog UI
                // This would require additional file system functionality
                if (c.igButton("Select File", .{ 100, 30 })) {
                    if (_self.callback) |cb| {
                        cb(_self.selected_file);
                    }
                    _self.close();
                }
            }
            c.igEnd();
        }
    }
};

pub const TabBar = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    tabs: []const []const u8,
    selected_tab: *usize,
    flags: c.ImGuiTabBarFlags,
    callback: ?*const fn (usize) void,

    pub fn init(id: []const u8, label: []const u8, tabs: []const []const u8, selected_tab: *usize, position: [2]f32, size: [2]f32, flags: c.ImGuiTabBarFlags, callback: ?*const fn (usize) void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .tabs = tabs,
            .selected_tab = selected_tab,
            .flags = flags,
            .callback = callback,
        };
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        if (c.igBeginTabBar(self.label.ptr, self.flags)) {
            for (self.tabs, 0..) |tab, i| {
                if (c.igBeginTabItem(tab.ptr)) {
                    self.selected_tab.* = i;
                    if (self.callback) |cb| {
                        cb(i);
                    }
                    c.igEndTabItem();
                }
            }
            c.igEndTabBar();
        }
    }
};

pub const TreeNode = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    flags: c.ImGuiTreeNodeFlags,
    children: std.ArrayList(*Widget),

    pub fn init(id: []const u8, label: []const u8, position: [2]f32, size: [2]f32, flags: c.ImGuiTreeNodeFlags) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
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

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        if (c.igTreeNodeEx(self.label.ptr, self.flags)) {
            for (self.children.items) |child| {
                try child.render();
            }
            c.igTreePop();
        }
    }
};

pub const MenuBar = struct {
    const Self = @This();

    widget: Widget,
    menus: std.ArrayList(*Menu),
    flags: c.ImGuiWindowFlags,

    pub fn init(id: []const u8, position: [2]f32, size: [2]f32, flags: c.ImGuiWindowFlags) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .menus = std.ArrayList(*Menu).init(std.heap.page_allocator),
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.menus.items) |menu| {
            menu.deinit();
        }
        self.menus.deinit();
    }

    pub fn addMenu(self: *Self, menu: *Menu) !void {
        try self.menus.append(menu);
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        if (c.igBeginMainMenuBar()) {
            for (self.menus.items) |menu| {
                try menu.render();
            }
            c.igEndMainMenuBar();
        }
    }
};

pub const Menu = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    items: std.ArrayList(*MenuItem),
    enabled: bool,

    pub fn init(id: []const u8, label: []const u8, position: [2]f32, size: [2]f32) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .items = std.ArrayList(*MenuItem).init(std.heap.page_allocator),
            .enabled = true,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.items.items) |item| {
            item.deinit();
        }
        self.items.deinit();
    }

    pub fn addItem(self: *Self, item: *MenuItem) !void {
        try self.items.append(item);
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        if (c.igBeginMenu(self.label.ptr, self.enabled)) {
            for (self.items.items) |item| {
                try item.render();
            }
            c.igEndMenu();
        }
    }
};

pub const MenuItem = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    shortcut: ?[]const u8,
    selected: *bool,
    enabled: bool,
    callback: ?*const fn () void,

    pub fn init(id: []const u8, label: []const u8, shortcut: ?[]const u8, selected: *bool, position: [2]f32, size: [2]f32, enabled: bool, callback: ?*const fn () void) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .shortcut = shortcut,
            .selected = selected,
            .enabled = enabled,
            .callback = callback,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        if (c.igMenuItem(self.label.ptr, if (self.shortcut) |s| s.ptr else null, self.selected, self.enabled)) {
            if (self.callback) |cb| {
                cb();
            }
        }
    }
};

pub const ContextMenu = struct {
    const Self = @This();

    widget: Widget,
    items: std.ArrayList(*MenuItem),
    mouse_pos: [2]f32,

    pub fn init(id: []const u8, position: [2]f32, size: [2]f32) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .items = std.ArrayList(*MenuItem).init(std.heap.page_allocator),
            .mouse_pos = position,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.items.items) |item| {
            item.deinit();
        }
        self.items.deinit();
    }

    pub fn addItem(self: *Self, item: *MenuItem) !void {
        try self.items.append(item);
    }

    pub fn setMousePosition(self: *Self, pos: [2]f32) void {
        self.mouse_pos = pos;
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        c.igSetNextWindowPos(c.ImVec2{ .x = self.mouse_pos[0], .y = self.mouse_pos[1] }, c.ImGuiCond_FirstUseEver, c.ImVec2{ .x = 0, .y = 0 });
        
        if (c.igBeginPopupContextWindow(null, c.ImGuiPopupFlags_MouseButtonRight)) {
            for (self.items.items) |item| {
                try item.render();
            }
            c.igEndPopup();
        }
    }
};

pub const Popup = struct {
    const Self = @This();

    widget: Widget,
    label: []const u8,
    content: std.ArrayList(*Widget),
    is_open: bool,
    flags: c.ImGuiWindowFlags,

    pub fn init(id: []const u8, label: []const u8, position: [2]f32, size: [2]f32, flags: c.ImGuiWindowFlags) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .label = label,
            .content = std.ArrayList(*Widget).init(std.heap.page_allocator),
            .is_open = false,
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.content.deinit();
    }

    pub fn addContent(self: *Self, widget: *Widget) !void {
        try self.content.append(widget);
    }

    pub fn open(self: *Self) void {
        self.is_open = true;
    }

    pub fn close(self: *Self) void {
        self.is_open = false;
    }

    fn render(_widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        if (self.is_open) {
            c.igSetNextWindowPos(c.ImVec2{ .x = self.widget.position[0], .y = self.widget.position[1] }, c.ImGuiCond_FirstUseEver, c.ImVec2{ .x = 0, .y = 0 });
            c.igSetNextWindowSize(c.ImVec2{ .x = self.widget.size[0], .y = self.widget.size[1] }, c.ImGuiCond_FirstUseEver);
            
            if (c.igBeginPopupModal(self.label.ptr, &self.is_open, self.flags)) {
                for (self.content.items) |content| {
                    try content.render();
                }
                c.igEndPopup();
            }
        }
    }
};

pub const Toast = struct {
    const Self = @This();

    widget: Widget,
    message: []const u8,
    duration: f32,
    toast_type: ToastType,
    is_visible: bool,
    start_time: f32,

    pub const ToastType = enum {
        Info,
        Success,
        Warning,
        Error,
    };

    pub fn init(id: []const u8, message: []const u8, position: [2]f32, size: [2]f32, duration: f32, toast_type: ToastType) Self {
        return Self{
            .widget = Widget.init(id, position, size, render),
            .message = message,
            .duration = duration,
            .toast_type = toast_type,
            .is_visible = false,
            .start_time = 0.0,
        };
    }

    pub fn show(self: *Self, current_time: f32) void {
        self.is_visible = true;
        self.start_time = current_time;
    }

    fn render(widget: *Widget) !void {
        const self = @as(*Self, @fieldParentPtr(Self, "widget"));
        
        if (self.is_visible) {
            const current_time = c.igGetTime();
            const elapsed = current_time - self.start_time;
            
            if (elapsed < self.duration) {
                const alpha = 1.0 - (elapsed / self.duration);
                const color = switch (self.toast_type) {
                    .Info => .{ 0.0, 0.5, 1.0, alpha },
                    .Success => .{ 0.0, 0.8, 0.0, alpha },
                    .Warning => .{ 1.0, 0.8, 0.0, alpha },
                    .Error => .{ 1.0, 0.0, 0.0, alpha },
                };

                c.igPushStyleColor(c.ImGuiCol_WindowBg, c.ImVec4{ .x = color[0], .y = color[1], .z = color[2], .w = color[3] });
                c.igSetNextWindowPos(c.ImVec2{ .x = self.widget.position[0], .y = self.widget.position[1] }, c.ImGuiCond_Always, c.ImVec2{ .x = 0, .y = 0 });
                
                if (c.igBegin("##toast", null, c.ImGuiWindowFlags_NoDecoration | c.ImGuiWindowFlags_AlwaysAutoResize | c.ImGuiWindowFlags_NoSavedSettings | c.ImGuiWindowFlags_NoFocusOnAppearing | c.ImGuiWindowFlags_NoNav)) {
                    c.igText(self.message.ptr);
                }
                c.igEnd();
                c.igPopStyleColor(1);
            } else {
                self.is_visible = false;
            }
        }
    }
};

pub const Toolbar = struct {
    const Self = @This();

    widget: Widget,
    items: std.ArrayList(*Widget),
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .items = std.ArrayList(*Widget).init(std.heap.page_allocator),
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit();
    }

    pub fn addItem(self: *Self, item: *Widget) !void {
        try self.items.append(item);
    }

    pub fn render(self: *Self) void {
        if (c.igBeginChild(self.widget.id, .{ self.widget.size[0], self.widget.size[1] }, true, self.flags)) {
            for (self.items.items) |item| {
                item.render();
                c.igSameLine(0, 4);
            }
        }
        c.igEndChild();
    }
};

pub const StatusBar = struct {
    const Self = @This();

    widget: Widget,
    items: std.ArrayList(*Widget),
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .items = std.ArrayList(*Widget).init(std.heap.page_allocator),
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.items.deinit();
    }

    pub fn addItem(self: *Self, item: *Widget) !void {
        try self.items.append(item);
    }

    pub fn render(self: *Self) void {
        if (c.igBeginChild(self.widget.id, .{ self.widget.size[0], self.widget.size[1] }, true, self.flags)) {
            for (self.items.items) |item| {
                item.render();
                c.igSameLine(0, 4);
            }
        }
        c.igEndChild();
    }
};

pub const Spacing = struct {
    const Self = @This();

    widget: Widget,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        c.igSpacing();
    }
};

pub const Dummy = struct {
    const Self = @This();

    widget: Widget,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        c.igDummy(.{ self.widget.size[0], self.widget.size[1] });
    }
};

pub const ProgressIndicator = struct {
    const Self = @This();

    widget: Widget,
    progress: f32,
    overlay_text: ?[*:0]const u8,
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        progress: f32,
        overlay_text: ?[*:0]const u8,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .progress = progress,
            .overlay_text = overlay_text,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        c.igProgressBar(self.progress, .{ self.widget.size[0], self.widget.size[1] }, self.overlay_text);
    }
};

pub const ScrollableArea = struct {
    const Self = @This();

    widget: Widget,
    content: std.ArrayList(*Widget),
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .content = std.ArrayList(*Widget).init(std.heap.page_allocator),
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.content.deinit();
    }

    pub fn addContent(self: *Self, widget: *Widget) !void {
        try self.content.append(widget);
    }

    pub fn render(self: *Self) void {
        if (c.igBeginChild(self.widget.id, .{ self.widget.size[0], self.widget.size[1] }, true, self.flags)) {
            for (self.content.items) |item| {
                item.render();
            }
        }
        c.igEndChild();
    }
};

pub const Group = struct {
    const Self = @This();

    widget: Widget,
    content: std.ArrayList(*Widget),
    flags: c.ImGuiWindowFlags,

    pub fn init(
        id: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiWindowFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .content = std.ArrayList(*Widget).init(std.heap.page_allocator),
            .flags = flags,
        };
    }

    pub fn deinit(self: *Self) void {
        self.content.deinit();
    }

    pub fn addContent(self: *Self, widget: *Widget) !void {
        try self.content.append(widget);
    }

    pub fn render(self: *Self) void {
        c.igBeginGroup();
        for (self.content.items) |item| {
            item.render();
        }
        c.igEndGroup();
    }
};

pub const CollapsingGroup = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    content: std.ArrayList(*Widget),
    flags: c.ImGuiTreeNodeFlags,
    is_open: bool,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiTreeNodeFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .content = std.ArrayList(*Widget).init(std.heap.page_allocator),
            .flags = flags,
            .is_open = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.content.deinit();
    }

    pub fn addContent(self: *Self, widget: *Widget) !void {
        try self.content.append(widget);
    }

    pub fn render(self: *Self) void {
        if (c.igCollapsingHeader(self.label, self.flags)) {
            for (self.content.items) |item| {
                item.render();
            }
        }
    }
};

pub const DragFloat = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *f32,
    speed: f32,
    min: f32,
    max: f32,
    format: [*:0]const u8,
    flags: c.ImGuiSliderFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *f32,
        speed: f32,
        min: f32,
        max: f32,
        format: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSliderFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .value = value,
            .speed = speed,
            .min = min,
            .max = max,
            .format = format,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igDragFloat(self.label, self.value, self.speed, self.min, self.max, self.format, self.flags);
    }
};

pub const DragInt = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *i32,
    speed: f32,
    min: i32,
    max: i32,
    format: [*:0]const u8,
    flags: c.ImGuiSliderFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *i32,
        speed: f32,
        min: i32,
        max: i32,
        format: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSliderFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .value = value,
            .speed = speed,
            .min = min,
            .max = max,
            .format = format,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igDragInt(self.label, self.value, self.speed, self.min, self.max, self.format, self.flags);
    }
};

pub const DragVec2 = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *[2]f32,
    speed: f32,
    min: f32,
    max: f32,
    format: [*:0]const u8,
    flags: c.ImGuiSliderFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *[2]f32,
        speed: f32,
        min: f32,
        max: f32,
        format: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSliderFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .value = value,
            .speed = speed,
            .min = min,
            .max = max,
            .format = format,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igDragFloat2(self.label, &self.value[0], self.speed, self.min, self.max, self.format, self.flags);
    }
};

pub const DragVec3 = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *[3]f32,
    speed: f32,
    min: f32,
    max: f32,
    format: [*:0]const u8,
    flags: c.ImGuiSliderFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *[3]f32,
        speed: f32,
        min: f32,
        max: f32,
        format: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSliderFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .value = value,
            .speed = speed,
            .min = min,
            .max = max,
            .format = format,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igDragFloat3(self.label, &self.value[0], self.speed, self.min, self.max, self.format, self.flags);
    }
};

pub const DragVec4 = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *[4]f32,
    speed: f32,
    min: f32,
    max: f32,
    format: [*:0]const u8,
    flags: c.ImGuiSliderFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *[4]f32,
        speed: f32,
        min: f32,
        max: f32,
        format: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSliderFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .value = value,
            .speed = speed,
            .min = min,
            .max = max,
            .format = format,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igDragFloat4(self.label, &self.value[0], self.speed, self.min, self.max, self.format, self.flags);
    }
};

pub const ComboBox = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    items: []const [*:0]const u8,
    selected_index: *usize,
    flags: c.ImGuiComboFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        items: []const [*:0]const u8,
        selected_index: *usize,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiComboFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .items = items,
            .selected_index = selected_index,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        if (c.igBeginCombo(self.label, self.items[self.selected_index.*], self.flags)) {
            for (self.items, 0..) |item, i| {
                if (c.igSelectable(item, i == self.selected_index.*, c.ImGuiSelectableFlags_None, .{ 0, 0 })) {
                    self.selected_index.* = i;
                }
            }
            c.igEndCombo();
        }
    }
};

pub const ListBox = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    items: []const [*:0]const u8,
    selected_index: *usize,
    height_in_items: i32,
    flags: c.ImGuiSelectableFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        items: []const [*:0]const u8,
        selected_index: *usize,
        height_in_items: i32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiSelectableFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .items = items,
            .selected_index = selected_index,
            .height_in_items = height_in_items,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        if (c.igBeginListBox(self.label, .{ self.widget.size[0], self.widget.size[1] })) {
            for (self.items, 0..) |item, i| {
                if (c.igSelectable(item, i == self.selected_index.*, self.flags, .{ 0, 0 })) {
                    self.selected_index.* = i;
                }
            }
            c.igEndListBox();
        }
    }
};

pub const InputTextMultiline = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    buffer: [*:0]u8,
    buffer_size: usize,
    size: [2]f32,
    flags: c.ImGuiInputTextFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        buffer: [*:0]u8,
        buffer_size: usize,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiInputTextFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .buffer = buffer,
            .buffer_size = buffer_size,
            .size = size,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igInputTextMultiline(
            self.label,
            self.buffer,
            self.buffer_size,
            .{ self.size[0], self.size[1] },
            self.flags,
            null,
            null,
        );
    }
};

pub const InputFloat = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *f32,
    step: f32,
    step_fast: f32,
    format: [*:0]const u8,
    flags: c.ImGuiInputTextFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *f32,
        step: f32,
        step_fast: f32,
        format: [*:0]const u8,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiInputTextFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .value = value,
            .step = step,
            .step_fast = step_fast,
            .format = format,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igInputFloat(self.label, self.value, self.step, self.step_fast, self.format, self.flags);
    }
};

pub const InputInt = struct {
    const Self = @This();

    widget: Widget,
    label: [*:0]const u8,
    value: *i32,
    step: i32,
    step_fast: i32,
    flags: c.ImGuiInputTextFlags,

    pub fn init(
        id: [*:0]const u8,
        label: [*:0]const u8,
        value: *i32,
        step: i32,
        step_fast: i32,
        pos: [2]f32,
        size: [2]f32,
        flags: c.ImGuiInputTextFlags,
    ) Self {
        return Self{
            .widget = Widget.init(
                id,
                pos,
                size,
                flags,
            ),
            .label = label,
            .value = value,
            .step = step,
            .step_fast = step_fast,
            .flags = flags,
        };
    }

    pub fn render(self: *Self) void {
        _ = c.igInputInt(self.label, self.value, self.step, self.step_fast, self.flags);
    }
}; 