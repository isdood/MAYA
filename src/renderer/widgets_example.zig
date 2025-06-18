const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
});
const ImGuiRenderer = @import("imgui.zig").ImGuiRenderer;
const widgets = @import("widgets.zig");

pub const WidgetsExample = struct {
    const Self = @This();

    renderer: *ImGuiRenderer,
    window: widgets.Window,
    button: widgets.Button,
    slider: widgets.Slider,
    checkbox: widgets.Checkbox,
    text: widgets.Text,
    plot: widgets.Plot,
    dropdown: widgets.Dropdown,
    color_picker: widgets.ColorPicker,
    input_text: widgets.InputText,
    progress_bar: widgets.ProgressBar,
    collapsing_header: widgets.CollapsingHeader,
    separator: widgets.Separator,
    tooltip: widgets.Tooltip,
    table: widgets.Table,
    drag_drop_source: widgets.DragDrop,
    drag_drop_target: widgets.DragDrop,
    file_dialog: widgets.FileDialog,
    tab_bar: widgets.TabBar,
    tree_node: widgets.TreeNode,

    // State variables
    slider_value: f32,
    checkbox_value: bool,
    plot_values: [100]f32,
    frame_count: u32,
    selected_index: usize,
    color: [4]f32,
    input_buffer: [256]u8,
    progress: f32,
    table_data: [10][3]f32,
    selected_tab: usize,
    current_path: [1024]u8,
    selected_file: [1024]u8,

    pub fn init(renderer: *ImGuiRenderer) !Self {
        var self = Self{
            .renderer = renderer,
            .window = widgets.Window.init(
                "example_window",
                "Widgets Example",
                .{ 100, 100 },
                .{ 800, 1000 },
                c.ImGuiWindowFlags_None,
            ),
            .button = undefined,
            .slider = undefined,
            .checkbox = undefined,
            .text = undefined,
            .plot = undefined,
            .dropdown = undefined,
            .color_picker = undefined,
            .input_text = undefined,
            .progress_bar = undefined,
            .collapsing_header = undefined,
            .separator = undefined,
            .tooltip = undefined,
            .table = undefined,
            .drag_drop_source = undefined,
            .drag_drop_target = undefined,
            .file_dialog = undefined,
            .tab_bar = undefined,
            .tree_node = undefined,

            // Initialize state
            .slider_value = 0.5,
            .checkbox_value = false,
            .plot_values = undefined,
            .frame_count = 0,
            .selected_index = 0,
            .color = .{ 1.0, 0.0, 0.0, 1.0 },
            .input_buffer = undefined,
            .progress = 0.0,
            .table_data = undefined,
            .selected_tab = 0,
            .current_path = undefined,
            .selected_file = undefined,
        };

        // Initialize plot values with a sine wave
        for (self.plot_values, 0..) |*value, i| {
            value.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);
        }

        // Initialize input buffer
        @memset(&self.input_buffer, 0);
        @memcpy(self.input_buffer[0..], "Type something...");

        // Initialize table data
        for (self.table_data, 0..) |*row, i| {
            row[0] = @as(f32, @floatFromInt(i));
            row[1] = @sin(@as(f32, @floatFromInt(i)) * 0.1);
            row[2] = @cos(@as(f32, @floatFromInt(i)) * 0.1);
        }

        // Initialize paths
        @memset(&self.current_path, 0);
        @memcpy(self.current_path[0..], "/home/user");
        @memset(&self.selected_file, 0);

        // Initialize widgets
        self.button = widgets.Button.init(
            "example_button",
            "Click Me!",
            .{ 10, 30 },
            .{ 100, 30 },
            buttonCallback,
        );

        self.slider = widgets.Slider.init(
            "example_slider",
            "Value",
            &self.slider_value,
            0.0,
            1.0,
            "%.2f",
            .{ 10, 70 },
            .{ 200, 30 },
            sliderCallback,
        );

        self.checkbox = widgets.Checkbox.init(
            "example_checkbox",
            "Enable Feature",
            &self.checkbox_value,
            .{ 10, 110 },
            .{ 200, 30 },
            checkboxCallback,
        );

        self.text = widgets.Text.init(
            "example_text",
            "This is a sample text widget",
            .{ 10, 150 },
            .{ 200, 30 },
            .{ 1.0, 0.0, 0.0, 1.0 },
        );

        self.plot = widgets.Plot.init(
            "example_plot",
            "Sine Wave",
            &self.plot_values,
            .{ 10, 190 },
            .{ 300, 100 },
        );

        const dropdown_items = [_][]const u8{ "Option 1", "Option 2", "Option 3", "Option 4" };
        self.dropdown = widgets.Dropdown.init(
            "example_dropdown",
            "Select Option",
            &dropdown_items,
            &self.selected_index,
            .{ 10, 300 },
            .{ 200, 30 },
            dropdownCallback,
        );

        self.color_picker = widgets.ColorPicker.init(
            "example_color_picker",
            "Pick Color",
            &self.color,
            .{ 10, 340 },
            .{ 200, 30 },
            c.ImGuiColorEditFlags_None,
            colorPickerCallback,
        );

        self.input_text = widgets.InputText.init(
            "example_input",
            "Input Text",
            &self.input_buffer,
            .{ 10, 380 },
            .{ 200, 30 },
            c.ImGuiInputTextFlags_None,
            inputTextCallback,
        );

        self.progress_bar = widgets.ProgressBar.init(
            "example_progress",
            "Progress",
            &self.progress,
            .{ 10, 420 },
            .{ 200, 30 },
            "Loading...",
        );

        self.collapsing_header = widgets.CollapsingHeader.init(
            "example_collapsing",
            "Advanced Options",
            .{ 10, 460 },
            .{ 200, 30 },
            c.ImGuiTreeNodeFlags_None,
        );

        self.separator = widgets.Separator.init(
            "example_separator",
            .{ 10, 500 },
            .{ 200, 30 },
        );

        self.tooltip = widgets.Tooltip.init(
            "example_tooltip",
            "This is a tooltip!",
            .{ 10, 540 },
            .{ 200, 30 },
            0.5,
        );

        // New widgets
        const table_columns = [_][]const u8{ "Index", "Sine", "Cosine" };
        self.table = widgets.Table.init(
            "example_table",
            "Data Table",
            &table_columns,
            .{ 10, 580 },
            .{ 300, 200 },
            c.ImGuiTableFlags_Borders | c.ImGuiTableFlags_RowBg,
            tableRowCallback,
            tableCellCallback,
        );

        self.drag_drop_source = widgets.DragDrop.init(
            "example_drag_source",
            "Drag Me!",
            "EXAMPLE_PAYLOAD",
            "Drag and drop data",
            .{ 10, 790 },
            .{ 100, 30 },
            dragDropCallback,
        );

        self.drag_drop_target = widgets.DragDrop.init(
            "example_drag_target",
            "Drop Here",
            "EXAMPLE_PAYLOAD",
            "",
            .{ 120, 790 },
            .{ 100, 30 },
            dragDropCallback,
        );

        self.file_dialog = widgets.FileDialog.init(
            "example_file_dialog",
            "File Dialog",
            &self.current_path,
            &self.selected_file,
            "*.txt",
            .{ 10, 830 },
            .{ 400, 300 },
            fileDialogCallback,
        );

        const tabs = [_][]const u8{ "Tab 1", "Tab 2", "Tab 3" };
        self.tab_bar = widgets.TabBar.init(
            "example_tabbar",
            "Tabs",
            &tabs,
            &self.selected_tab,
            .{ 10, 870 },
            .{ 300, 30 },
            c.ImGuiTabBarFlags_None,
            tabBarCallback,
        );

        self.tree_node = widgets.TreeNode.init(
            "example_tree",
            "Tree View",
            .{ 10, 910 },
            .{ 200, 30 },
            c.ImGuiTreeNodeFlags_None,
        );

        // Add widgets to window
        try self.window.addChild(&self.button.widget);
        try self.window.addChild(&self.slider.widget);
        try self.window.addChild(&self.checkbox.widget);
        try self.window.addChild(&self.text.widget);
        try self.window.addChild(&self.plot.widget);
        try self.window.addChild(&self.dropdown.widget);
        try self.window.addChild(&self.color_picker.widget);
        try self.window.addChild(&self.input_text.widget);
        try self.window.addChild(&self.progress_bar.widget);
        try self.window.addChild(&self.collapsing_header.widget);
        try self.window.addChild(&self.separator.widget);
        try self.window.addChild(&self.tooltip.widget);
        try self.window.addChild(&self.table.widget);
        try self.window.addChild(&self.drag_drop_source.widget);
        try self.window.addChild(&self.drag_drop_target.widget);
        try self.window.addChild(&self.file_dialog.widget);
        try self.window.addChild(&self.tab_bar.widget);
        try self.window.addChild(&self.tree_node.widget);

        // Add window to renderer
        try renderer.addWidget(&self.window.widget);

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.window.deinit();
        self.collapsing_header.deinit();
        self.tree_node.deinit();
    }

    pub fn update(self: *Self) !void {
        self.frame_count += 1;

        // Update plot values with a moving sine wave
        for (self.plot_values, 0..) |*value, i| {
            value.* = @sin(@as(f32, @floatFromInt(i + self.frame_count)) * 0.1);
        }

        // Update progress bar
        self.progress = @mod(@as(f32, @floatFromInt(self.frame_count)) * 0.01, 1.0);

        // Update table data
        for (self.table_data, 0..) |*row, i| {
            row[1] = @sin(@as(f32, @floatFromInt(i + self.frame_count)) * 0.1);
            row[2] = @cos(@as(f32, @floatFromInt(i + self.frame_count)) * 0.1);
        }
    }
};

fn buttonCallback() void {
    std.log.info("Button clicked!", .{});
}

fn sliderCallback(value: f32) void {
    std.log.info("Slider value changed: {d}", .{value});
}

fn checkboxCallback(value: bool) void {
    std.log.info("Checkbox value changed: {}", .{value});
}

fn dropdownCallback(index: usize) void {
    std.log.info("Dropdown selection changed to index: {}", .{index});
}

fn colorPickerCallback(color: [4]f32) void {
    std.log.info("Color changed to: {d:.2}, {d:.2}, {d:.2}, {d:.2}", .{ color[0], color[1], color[2], color[3] });
}

fn inputTextCallback(text: []const u8) void {
    std.log.info("Input text changed to: {s}", .{text});
}

fn tableRowCallback(row: usize) void {
    std.log.info("Table row selected: {}", .{row});
}

fn tableCellCallback(row: usize, col: usize) void {
    std.log.info("Table cell clicked: row={}, col={}", .{ row, col });
}

fn dragDropCallback(data: []const u8) void {
    std.log.info("Drag and drop data received: {s}", .{data});
}

fn fileDialogCallback(file_path: []const u8) void {
    std.log.info("File selected: {s}", .{file_path});
}

fn tabBarCallback(tab_index: usize) void {
    std.log.info("Tab selected: {}", .{tab_index});
} 