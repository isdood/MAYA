const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
});

pub const PerformanceDashboard = struct {
    const Self = @This();

    // Performance data
    fps_history: [60]f32,
    frame_time_history: [60]f32,
    gpu_usage_history: [60]f32,
    vram_usage_history: [60]f32,
    cpu_usage_history: [60]f32,
    memory_usage_history: [60]f32,
    history_index: usize,
    
    // Alert thresholds
    fps_threshold: f32,
    gpu_usage_threshold: f32,
    vram_usage_threshold: f32,
    cpu_usage_threshold: f32,
    memory_usage_threshold: f32,

    // Alert states
    fps_alert: bool,
    gpu_alert: bool,
    vram_alert: bool,
    cpu_alert: bool,
    memory_alert: bool,

    // Window state
    show_detailed_metrics: bool,
    show_alerts: bool,
    show_history: bool,
    logger: std.log.Logger,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        self.* = Self{
            .fps_history = [_]f32{0} ** 60,
            .frame_time_history = [_]f32{0} ** 60,
            .gpu_usage_history = [_]f32{0} ** 60,
            .vram_usage_history = [_]f32{0} ** 60,
            .cpu_usage_history = [_]f32{0} ** 60,
            .memory_usage_history = [_]f32{0} ** 60,
            .history_index = 0,
            
            .fps_threshold = 30.0,
            .gpu_usage_threshold = 90.0,
            .vram_usage_threshold = 85.0,
            .cpu_usage_threshold = 90.0,
            .memory_usage_threshold = 85.0,

            .fps_alert = false,
            .gpu_alert = false,
            .vram_alert = false,
            .cpu_alert = false,
            .memory_alert = false,

            .show_detailed_metrics = true,
            .show_alerts = true,
            .show_history = true,
            .logger = std.log.scoped(.performance_dashboard),
        };
        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn updateMetrics(self: *Self, metrics: struct {
        fps: f32,
        frame_time: f32,
        gpu_usage: f32,
        vram_usage: f32,
        cpu_usage: f32,
        memory_usage: f32,
    }) void {
        // Update history
        self.fps_history[self.history_index] = metrics.fps;
        self.frame_time_history[self.history_index] = metrics.frame_time;
        self.gpu_usage_history[self.history_index] = metrics.gpu_usage;
        self.vram_usage_history[self.history_index] = metrics.vram_usage;
        self.cpu_usage_history[self.history_index] = metrics.cpu_usage;
        self.memory_usage_history[self.history_index] = metrics.memory_usage;

        self.history_index = (self.history_index + 1) % 60;

        // Update alerts
        self.fps_alert = metrics.fps < self.fps_threshold;
        self.gpu_alert = metrics.gpu_usage > self.gpu_usage_threshold;
        self.vram_alert = metrics.vram_usage > self.vram_usage_threshold;
        self.cpu_alert = metrics.cpu_usage > self.cpu_usage_threshold;
        self.memory_alert = metrics.memory_usage > self.memory_usage_threshold;
    }

    pub fn render(self: *Self) void {
        if (c.igBegin("Performance Dashboard", null, c.ImGuiWindowFlags_None)) {
            // Main metrics
            self.renderMainMetrics();
            c.igSeparator();

            // Detailed metrics
            if (self.show_detailed_metrics) {
                self.renderDetailedMetrics();
                c.igSeparator();
            }

            // Alerts
            if (self.show_alerts) {
                self.renderAlerts();
                c.igSeparator();
            }

            // History graphs
            if (self.show_history) {
                self.renderHistoryGraphs();
            }

            // Settings
            if (c.igCollapsingHeader("Settings", c.ImGuiTreeNodeFlags_None)) {
                self.renderSettings();
            }
        }
        c.igEnd();
    }

    fn renderMainMetrics(self: *Self) void {
        const io = c.igGetIO();
        const fps = 1.0 / io.*.DeltaTime;
        const frame_time = io.*.DeltaTime * 1000.0;

        c.igText("FPS: %.1f (%.2f ms)", fps, frame_time);
        
        // GPU metrics
        c.igText("GPU Usage: %.1f%%", self.gpu_usage_history[self.history_index]);
        c.igProgressBar(
            self.gpu_usage_history[self.history_index] / 100.0,
            .{ .x = -1.0, .y = 0.0 },
            "GPU Usage"
        );

        // VRAM metrics
        c.igText("VRAM Usage: %.1f%%", self.vram_usage_history[self.history_index]);
        c.igProgressBar(
            self.vram_usage_history[self.history_index] / 100.0,
            .{ .x = -1.0, .y = 0.0 },
            "VRAM Usage"
        );
    }

    fn renderDetailedMetrics(self: *Self) void {
        if (c.igCollapsingHeader("Detailed Metrics", c.ImGuiTreeNodeFlags_None)) {
            // CPU metrics
            c.igText("CPU Usage: %.1f%%", self.cpu_usage_history[self.history_index]);
            c.igProgressBar(
                self.cpu_usage_history[self.history_index] / 100.0,
                .{ .x = -1.0, .y = 0.0 },
                "CPU Usage"
            );

            // Memory metrics
            c.igText("Memory Usage: %.1f%%", self.memory_usage_history[self.history_index]);
            c.igProgressBar(
                self.memory_usage_history[self.history_index] / 100.0,
                .{ .x = -1.0, .y = 0.0 },
                "Memory Usage"
            );

            // Frame timing breakdown
            c.igText("Frame Timing:");
            c.igBulletText("CPU Frame Time: %.2f ms", self.frame_time_history[self.history_index]);
            c.igBulletText("GPU Frame Time: %.2f ms", self.frame_time_history[self.history_index] * 0.8); // Example
            c.igBulletText("Present Time: %.2f ms", self.frame_time_history[self.history_index] * 0.2); // Example
        }
    }

    fn renderAlerts(self: *Self) void {
        if (c.igCollapsingHeader("Performance Alerts", c.ImGuiTreeNodeFlags_None)) {
            const alert_color = c.ImVec4{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 };
            const normal_color = c.ImVec4{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 1.0 };

            // FPS Alert
            c.igPushStyleColor(c.ImGuiCol_Text, if (self.fps_alert) alert_color else normal_color);
            c.igText("FPS: %.1f (Threshold: %.1f)", 
                self.fps_history[self.history_index],
                self.fps_threshold
            );
            c.igPopStyleColor();

            // GPU Alert
            c.igPushStyleColor(c.ImGuiCol_Text, if (self.gpu_alert) alert_color else normal_color);
            c.igText("GPU Usage: %.1f%% (Threshold: %.1f%%)",
                self.gpu_usage_history[self.history_index],
                self.gpu_usage_threshold
            );
            c.igPopStyleColor();

            // VRAM Alert
            c.igPushStyleColor(c.ImGuiCol_Text, if (self.vram_alert) alert_color else normal_color);
            c.igText("VRAM Usage: %.1f%% (Threshold: %.1f%%)",
                self.vram_usage_history[self.history_index],
                self.vram_usage_threshold
            );
            c.igPopStyleColor();

            // CPU Alert
            c.igPushStyleColor(c.ImGuiCol_Text, if (self.cpu_alert) alert_color else normal_color);
            c.igText("CPU Usage: %.1f%% (Threshold: %.1f%%)",
                self.cpu_usage_history[self.history_index],
                self.cpu_usage_threshold
            );
            c.igPopStyleColor();

            // Memory Alert
            c.igPushStyleColor(c.ImGuiCol_Text, if (self.memory_alert) alert_color else normal_color);
            c.igText("Memory Usage: %.1f%% (Threshold: %.1f%%)",
                self.memory_usage_history[self.history_index],
                self.memory_usage_threshold
            );
            c.igPopStyleColor();
        }
    }

    fn renderHistoryGraphs(self: *Self) void {
        if (c.igCollapsingHeader("Performance History", c.ImGuiTreeNodeFlags_None)) {
            const graph_size = c.ImVec2{ .x = -1.0, .y = 100.0 };
            const overlay = "FPS History";

            // FPS History
            c.igPlotLines(
                "##fps_history",
                &self.fps_history,
                self.fps_history.len,
                @intCast(i32, self.history_index),
                overlay,
                0.0,
                240.0,
                graph_size
            );

            // GPU Usage History
            c.igPlotLines(
                "##gpu_history",
                &self.gpu_usage_history,
                self.gpu_usage_history.len,
                @intCast(i32, self.history_index),
                "GPU Usage History",
                0.0,
                100.0,
                graph_size
            );

            // VRAM Usage History
            c.igPlotLines(
                "##vram_history",
                &self.vram_usage_history,
                self.vram_usage_history.len,
                @intCast(i32, self.history_index),
                "VRAM Usage History",
                0.0,
                100.0,
                graph_size
            );

            // CPU Usage History
            c.igPlotLines(
                "##cpu_history",
                &self.cpu_usage_history,
                self.cpu_usage_history.len,
                @intCast(i32, self.history_index),
                "CPU Usage History",
                0.0,
                100.0,
                graph_size
            );
        }
    }

    fn renderSettings(self: *Self) void {
        // Display options
        _ = c.igCheckbox("Show Detailed Metrics", &self.show_detailed_metrics);
        _ = c.igCheckbox("Show Alerts", &self.show_alerts);
        _ = c.igCheckbox("Show History", &self.show_history);

        c.igSeparator();

        // Alert thresholds
        c.igText("Alert Thresholds");
        _ = c.igSliderFloat("FPS Threshold", &self.fps_threshold, 15.0, 60.0, "%.1f", c.ImGuiSliderFlags_None);
        _ = c.igSliderFloat("GPU Usage Threshold", &self.gpu_usage_threshold, 50.0, 100.0, "%.1f%%", c.ImGuiSliderFlags_None);
        _ = c.igSliderFloat("VRAM Usage Threshold", &self.vram_usage_threshold, 50.0, 100.0, "%.1f%%", c.ImGuiSliderFlags_None);
        _ = c.igSliderFloat("CPU Usage Threshold", &self.cpu_usage_threshold, 50.0, 100.0, "%.1f%%", c.ImGuiSliderFlags_None);
        _ = c.igSliderFloat("Memory Usage Threshold", &self.memory_usage_threshold, 50.0, 100.0, "%.1f%%", c.ImGuiSliderFlags_None);
    }
}; 