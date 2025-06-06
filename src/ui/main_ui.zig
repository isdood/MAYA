const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
});
const PerformanceDashboard = @import("performance_dashboard.zig").PerformanceDashboard;

pub const MainUI = struct {
    const Self = @This();

    show_demo_window: bool,
    show_performance_window: bool,
    show_settings_window: bool,
    performance_dashboard: ?*PerformanceDashboard,
    logger: std.log.Logger,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        self.* = Self{
            .show_demo_window = true,
            .show_performance_window = true,
            .show_settings_window = false,
            .performance_dashboard = try PerformanceDashboard.init(allocator),
            .logger = std.log.scoped(.ui),
        };
        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.performance_dashboard) |*dashboard| {
            dashboard.deinit(allocator);
        }
        allocator.destroy(self);
    }

    pub fn render(self: *Self) void {
        // Main menu bar
        if (c.igBeginMainMenuBar()) {
            if (c.igBeginMenu("File", true)) {
                if (c.igMenuItem("Exit", "Alt+F4", false, true)) {
                    // TODO: Implement exit functionality
                }
                c.igEndMenu();
            }
            if (c.igBeginMenu("View", true)) {
                _ = c.igMenuItem("Demo Window", null, &self.show_demo_window, true);
                _ = c.igMenuItem("Performance", null, &self.show_performance_window, true);
                _ = c.igMenuItem("Settings", null, &self.show_settings_window, true);
                c.igEndMenu();
            }
            c.igEndMainMenuBar();
        }

        // Demo window
        if (self.show_demo_window) {
            var show_demo = self.show_demo_window;
            c.igShowDemoWindow(&show_demo);
            self.show_demo_window = show_demo;
        }

        // Performance dashboard
        if (self.show_performance_window) {
            if (self.performance_dashboard) |*dashboard| {
                // Update metrics
                const io = c.igGetIO();
                dashboard.updateMetrics(.{
                    .fps = 1.0 / io.*.DeltaTime,
                    .frame_time = io.*.DeltaTime * 1000.0,
                    .gpu_usage = 75.0, // TODO: Get from performance monitor
                    .vram_usage = 45.0, // TODO: Get from performance monitor
                    .cpu_usage = 60.0, // TODO: Get from performance monitor
                    .memory_usage = 30.0, // TODO: Get from performance monitor
                });

                // Render dashboard
                dashboard.render();
            }
        }

        // Settings window
        if (self.show_settings_window) {
            if (c.igBegin("Settings", &self.show_settings_window, c.ImGuiWindowFlags_None)) {
                if (c.igCollapsingHeader("Graphics", c.ImGuiTreeNodeFlags_None)) {
                    var vsync = true;
                    _ = c.igCheckbox("VSync", &vsync);
                    
                    var msaa = 4;
                    const msaa_values = [_]i32{ 1, 2, 4, 8 };
                    const msaa_labels = [_][*:0]const u8{ "1x", "2x", "4x", "8x" };
                    if (c.igBeginCombo("MSAA", msaa_labels[@intCast(usize, msaa)])) {
                        for (msaa_values) |value, i| {
                            if (c.igSelectable(msaa_labels[i], msaa == value, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                                msaa = value;
                            }
                        }
                        c.igEndCombo();
                    }
                }

                if (c.igCollapsingHeader("Performance", c.ImGuiTreeNodeFlags_None)) {
                    var target_fps: f32 = 60.0;
                    _ = c.igSliderFloat("Target FPS", &target_fps, 30.0, 240.0, "%.0f", c.ImGuiSliderFlags_None);
                    
                    var power_mode = 0;
                    const power_modes = [_][*:0]const u8{ "Balanced", "Performance", "Power Saving" };
                    if (c.igBeginCombo("Power Mode", power_modes[@intCast(usize, power_mode)])) {
                        for (power_modes) |mode, i| {
                            if (c.igSelectable(mode, power_mode == @intCast(i32, i), c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                                power_mode = @intCast(i32, i);
                            }
                        }
                        c.igEndCombo();
                    }
                }

                if (c.igCollapsingHeader("Debug", c.ImGuiTreeNodeFlags_None)) {
                    var show_fps = true;
                    _ = c.igCheckbox("Show FPS", &show_fps);
                    
                    var show_debug_info = false;
                    _ = c.igCheckbox("Show Debug Info", &show_debug_info);
                }
            }
            c.igEnd();
        }
    }
}; 