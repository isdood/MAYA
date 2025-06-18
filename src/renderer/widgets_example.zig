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
    toolbar: widgets.Toolbar,
    status_bar: widgets.StatusBar,
    menu_bar: widgets.MenuBar,
    file_menu: widgets.Menu,
    edit_menu: widgets.Menu,
    view_menu: widgets.Menu,
    context_menu: widgets.ContextMenu,
    popup: widgets.Popup,
    toast: widgets.Toast,
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
    scrollable_area: widgets.ScrollableArea,
    progress_indicator: widgets.ProgressIndicator,
    drag_float: widgets.DragFloat,
    drag_int: widgets.DragInt,
    drag_vec2: widgets.DragVec2,
    drag_vec3: widgets.DragVec3,
    drag_vec4: widgets.DragVec4,

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
    file_menu_selected: bool,
    edit_menu_selected: bool,
    view_menu_selected: bool,
    toolbar_selected: bool,
    status_text: [256]u8,
    float_value: f32,
    int_value: i32,
    vec2_value: [2]f32,
    vec3_value: [3]f32,
    vec4_value: [4]f32,

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
            .toolbar = undefined,
            .status_bar = undefined,
            .menu_bar = undefined,
            .file_menu = undefined,
            .edit_menu = undefined,
            .view_menu = undefined,
            .context_menu = undefined,
            .popup = undefined,
            .toast = undefined,
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
            .scrollable_area = undefined,
            .progress_indicator = undefined,
            .drag_float = undefined,
            .drag_int = undefined,
            .drag_vec2 = undefined,
            .drag_vec3 = undefined,
            .drag_vec4 = undefined,

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
            .file_menu_selected = false,
            .edit_menu_selected = false,
            .view_menu_selected = false,
            .toolbar_selected = false,
            .status_text = undefined,
            .float_value = 0.0,
            .int_value = 0,
            .vec2_value = .{ 0.0, 0.0 },
            .vec3_value = .{ 0.0, 0.0, 0.0 },
            .vec4_value = .{ 0.0, 0.0, 0.0, 0.0 },
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

        // Initialize menu bar
        self.menu_bar = widgets.MenuBar.init(
            "example_menu_bar",
            .{ 0, 0 },
            .{ 800, 30 },
            c.ImGuiWindowFlags_None,
        );

        // Initialize menus
        self.file_menu = widgets.Menu.init(
            "example_file_menu",
            "File",
            .{ 0, 0 },
            .{ 100, 30 },
        );

        self.edit_menu = widgets.Menu.init(
            "example_edit_menu",
            "Edit",
            .{ 0, 0 },
            .{ 100, 30 },
        );

        self.view_menu = widgets.Menu.init(
            "example_view_menu",
            "View",
            .{ 0, 0 },
            .{ 100, 30 },
        );

        // Add menu items
        const new_file_item = widgets.MenuItem.init(
            "new_file",
            "New",
            "Ctrl+N",
            &self.file_menu_selected,
            .{ 0, 0 },
            .{ 100, 30 },
            true,
            newFileCallback,
        );

        const open_file_item = widgets.MenuItem.init(
            "open_file",
            "Open",
            "Ctrl+O",
            &self.file_menu_selected,
            .{ 0, 0 },
            .{ 100, 30 },
            true,
            openFileCallback,
        );

        const save_file_item = widgets.MenuItem.init(
            "save_file",
            "Save",
            "Ctrl+S",
            &self.file_menu_selected,
            .{ 0, 0 },
            .{ 100, 30 },
            true,
            saveFileCallback,
        );

        try self.file_menu.addItem(&new_file_item);
        try self.file_menu.addItem(&open_file_item);
        try self.file_menu.addItem(&save_file_item);

        // Add menus to menu bar
        try self.menu_bar.addMenu(&self.file_menu);
        try self.menu_bar.addMenu(&self.edit_menu);
        try self.menu_bar.addMenu(&self.view_menu);

        // Initialize context menu
        self.context_menu = widgets.ContextMenu.init(
            "example_context_menu",
            .{ 0, 0 },
            .{ 200, 30 },
        );

        const context_item = widgets.MenuItem.init(
            "context_item",
            "Context Action",
            null,
            &self.file_menu_selected,
            .{ 0, 0 },
            .{ 200, 30 },
            true,
            contextMenuCallback,
        );

        try self.context_menu.addItem(&context_item);

        // Initialize popup
        self.popup = widgets.Popup.init(
            "example_popup",
            "Example Popup",
            .{ 400, 300 },
            .{ 300, 200 },
            c.ImGuiWindowFlags_None,
        );

        const popup_text = widgets.Text.init(
            "popup_text",
            "This is a popup window!",
            .{ 10, 10 },
            .{ 280, 30 },
            .{ 1.0, 1.0, 1.0, 1.0 },
        );

        try self.popup.addContent(&popup_text.widget);

        // Initialize toast
        self.toast = widgets.Toast.init(
            "example_toast",
            "Operation completed successfully!",
            .{ 10, 50 },
            .{ 300, 50 },
            3.0,
            .Success,
        );

        // Initialize toolbar
        self.toolbar = widgets.Toolbar.init(
            "example_toolbar",
            .{ 0, 0 },
            .{ 800, 40 },
            c.ImGuiWindowFlags_None,
        );

        // Add toolbar items
        const new_button = widgets.Button.init(
            "toolbar_new",
            "New",
            .{ 0, 0 },
            .{ 60, 30 },
            true,
            newFileCallback,
        );

        const open_button = widgets.Button.init(
            "toolbar_open",
            "Open",
            .{ 0, 0 },
            .{ 60, 30 },
            true,
            openFileCallback,
        );

        const save_button = widgets.Button.init(
            "toolbar_save",
            "Save",
            .{ 0, 0 },
            .{ 60, 30 },
            true,
            saveFileCallback,
        );

        try self.toolbar.addItem(&new_button.widget);
        try self.toolbar.addItem(&open_button.widget);
        try self.toolbar.addItem(&save_button.widget);

        // Initialize status bar
        self.status_bar = widgets.StatusBar.init(
            "example_status_bar",
            .{ 0, 960 },
            .{ 800, 40 },
            c.ImGuiWindowFlags_None,
        );

        // Add status bar items
        const status_text = widgets.Text.init(
            "status_text",
            "Ready",
            .{ 10, 10 },
            .{ 200, 20 },
            .{ 1.0, 1.0, 1.0, 1.0 },
        );

        try self.status_bar.addItem(&status_text.widget);

        // Initialize scrollable area
        self.scrollable_area = widgets.ScrollableArea.init(
            "example_scrollable",
            .{ 10, 50 },
            .{ 780, 900 },
            c.ImGuiWindowFlags_None,
        );

        // Initialize progress indicator
        self.progress_indicator = widgets.ProgressIndicator.init(
            "example_progress",
            .{ 10, 10 },
            .{ 200, 30 },
            0.0,
            "Loading...",
            c.ImGuiWindowFlags_None,
        );

        // Initialize drag widgets
        self.drag_float = widgets.DragFloat.init(
            "example_drag_float",
            "Float Value",
            &self.float_value,
            0.1,
            0.0,
            100.0,
            "%.2f",
            .{ 10, 50 },
            .{ 200, 30 },
            c.ImGuiSliderFlags_None,
        );

        self.drag_int = widgets.DragInt.init(
            "example_drag_int",
            "Int Value",
            &self.int_value,
            1,
            0,
            100,
            "%d",
            .{ 10, 90 },
            .{ 200, 30 },
            c.ImGuiSliderFlags_None,
        );

        self.drag_vec2 = widgets.DragVec2.init(
            "example_drag_vec2",
            "Vec2 Value",
            &self.vec2_value,
            0.1,
            0.0,
            100.0,
            "%.2f",
            .{ 10, 130 },
            .{ 200, 30 },
            c.ImGuiSliderFlags_None,
        );

        self.drag_vec3 = widgets.DragVec3.init(
            "example_drag_vec3",
            "Vec3 Value",
            &self.vec3_value,
            0.1,
            0.0,
            100.0,
            "%.2f",
            .{ 10, 170 },
            .{ 200, 30 },
            c.ImGuiSliderFlags_None,
        );

        self.drag_vec4 = widgets.DragVec4.init(
            "example_drag_vec4",
            "Vec4 Value",
            &self.vec4_value,
            0.1,
            0.0,
            100.0,
            "%.2f",
            .{ 10, 210 },
            .{ 200, 30 },
            c.ImGuiSliderFlags_None,
        );

        // Add widgets to scrollable area
        try self.scrollable_area.addContent(&self.drag_float.widget);
        try self.scrollable_area.addContent(&self.drag_int.widget);
        try self.scrollable_area.addContent(&self.drag_vec2.widget);
        try self.scrollable_area.addContent(&self.drag_vec3.widget);
        try self.scrollable_area.addContent(&self.drag_vec4.widget);

        // Add widgets to window
        try self.window.addChild(&self.menu_bar.widget);
        try self.window.addChild(&self.context_menu.widget);
        try self.window.addChild(&self.popup.widget);
        try self.window.addChild(&self.toast.widget);
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
        try self.window.addChild(&self.toolbar.widget);
        try self.window.addChild(&self.status_bar.widget);
        try self.window.addChild(&self.scrollable_area.widget);
        try self.window.addChild(&self.progress_indicator.widget);

        // Add window to renderer
        try renderer.addWidget(&self.window.widget);

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.window.deinit();
        self.menu_bar.deinit();
        self.file_menu.deinit();
        self.edit_menu.deinit();
        self.view_menu.deinit();
        self.context_menu.deinit();
        self.popup.deinit();
        self.toast.deinit();
        self.collapsing_header.deinit();
        self.tree_node.deinit();
        self.toolbar.deinit();
        self.status_bar.deinit();
        self.scrollable_area.deinit();
        self.progress_indicator.deinit();
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

        // Update toast visibility based on some condition
        if (self.frame_count % 300 == 0) { // Show toast every 5 seconds
            self.toast.show(c.igGetTime());
        }

        // Update status text
        const status = try std.fmt.bufPrint(
            &self.status_text,
            "Frame: {d}, Time: {d:.2}s",
            .{ self.frame_count, c.igGetTime() },
        );
        _ = status;
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

fn newFileCallback() void {
    std.log.info("New file action triggered", .{});
}

fn openFileCallback() void {
    std.log.info("Open file action triggered", .{});
}

fn saveFileCallback() void {
    std.log.info("Save file action triggered", .{});
}

fn contextMenuCallback() void {
    std.log.info("Context menu action triggered", .{});
} 