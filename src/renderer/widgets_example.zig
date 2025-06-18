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
    slider_value: f32,
    checkbox_value: bool,
    plot_values: [100]f32,
    frame_count: u32,

    pub fn init(renderer: *ImGuiRenderer) !Self {
        var self = Self{
            .renderer = renderer,
            .window = widgets.Window.init(
                "example_window",
                "Widgets Example",
                .{ 100, 100 },
                .{ 400, 300 },
                c.ImGuiWindowFlags_None,
            ),
            .button = undefined,
            .slider = undefined,
            .checkbox = undefined,
            .text = undefined,
            .plot = undefined,
            .slider_value = 0.5,
            .checkbox_value = false,
            .plot_values = undefined,
            .frame_count = 0,
        };

        // Initialize plot values with a sine wave
        for (self.plot_values, 0..) |*value, i| {
            value.* = @sin(@as(f32, @floatFromInt(i)) * 0.1);
        }

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

        // Add widgets to window
        try self.window.addChild(&self.button.widget);
        try self.window.addChild(&self.slider.widget);
        try self.window.addChild(&self.checkbox.widget);
        try self.window.addChild(&self.text.widget);
        try self.window.addChild(&self.plot.widget);

        // Add window to renderer
        try renderer.addWidget(&self.window.widget);

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.window.deinit();
    }

    pub fn update(self: *Self) !void {
        self.frame_count += 1;

        // Update plot values with a moving sine wave
        for (self.plot_values, 0..) |*value, i| {
            value.* = @sin(@as(f32, @floatFromInt(i + self.frame_count)) * 0.1);
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