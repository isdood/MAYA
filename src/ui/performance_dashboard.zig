const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
});
const PerformanceOptimizer = @import("../renderer/performance_optimizer.zig").PerformanceOptimizer;

pub const PerformanceDashboard = struct {
    const Self = @This();
    const HISTORY_SIZE = 60;

    // Basic metrics
    fps_history: [HISTORY_SIZE]f32,
    frame_time_history: [HISTORY_SIZE]f32,
    gpu_usage_history: [HISTORY_SIZE]f32,
    vram_usage_history: [HISTORY_SIZE]f32,
    cpu_usage_history: [HISTORY_SIZE]f32,
    memory_usage_history: [HISTORY_SIZE]f32,
    
    // Shader metrics
    vertex_shader_history: [HISTORY_SIZE]u64,
    fragment_shader_history: [HISTORY_SIZE]u64,
    geometry_shader_history: [HISTORY_SIZE]u64,
    compute_shader_history: [HISTORY_SIZE]u64,
    
    // Primitive metrics
    primitive_history: [HISTORY_SIZE]u64,
    
    // Pipeline metrics
    pipeline_cache_hits_history: [HISTORY_SIZE]u32,
    pipeline_cache_misses_history: [HISTORY_SIZE]u32,
    
    // Command buffer metrics
    command_buffer_history: [HISTORY_SIZE]u32,
    
    history_index: usize,
    show_detailed_metrics: bool,
    show_shader_metrics: bool,
    show_primitive_metrics: bool,
    show_pipeline_metrics: bool,
    show_command_buffer_metrics: bool,
    show_recommendations: bool,
    
    // Performance optimizer
    optimizer: ?*PerformanceOptimizer,
    
    logger: std.log.Logger,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        self.* = Self{
            .fps_history = [_]f32{0} ** HISTORY_SIZE,
            .frame_time_history = [_]f32{0} ** HISTORY_SIZE,
            .gpu_usage_history = [_]f32{0} ** HISTORY_SIZE,
            .vram_usage_history = [_]f32{0} ** HISTORY_SIZE,
            .cpu_usage_history = [_]f32{0} ** HISTORY_SIZE,
            .memory_usage_history = [_]f32{0} ** HISTORY_SIZE,
            .vertex_shader_history = [_]u64{0} ** HISTORY_SIZE,
            .fragment_shader_history = [_]u64{0} ** HISTORY_SIZE,
            .geometry_shader_history = [_]u64{0} ** HISTORY_SIZE,
            .compute_shader_history = [_]u64{0} ** HISTORY_SIZE,
            .primitive_history = [_]u64{0} ** HISTORY_SIZE,
            .pipeline_cache_hits_history = [_]u32{0} ** HISTORY_SIZE,
            .pipeline_cache_misses_history = [_]u32{0} ** HISTORY_SIZE,
            .command_buffer_history = [_]u32{0} ** HISTORY_SIZE,
            .history_index = 0,
            .show_detailed_metrics = false,
            .show_shader_metrics = false,
            .show_primitive_metrics = false,
            .show_pipeline_metrics = false,
            .show_command_buffer_metrics = false,
            .show_recommendations = true,
            .optimizer = try PerformanceOptimizer.init(allocator),
            .logger = std.log.scoped(.performance_dashboard),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.optimizer) |*optimizer| {
            optimizer.deinit();
        }
        allocator.destroy(self);
    }

    pub fn updateMetrics(self: *Self, metrics: struct {
        fps: f32,
        frame_time: f32,
        gpu_usage: f32,
        vram_usage: f32,
        cpu_usage: f32,
        memory_usage: f32,
        shader_metrics: struct {
            vertex_shader_invocations: u64,
            fragment_shader_invocations: u64,
            geometry_shader_invocations: u64,
            tessellation_control_shader_patches: u64,
            tessellation_evaluation_shader_invocations: u64,
            compute_shader_invocations: u64,
        },
        primitive_metrics: struct {
            input_assembly_primitives: u64,
            vertex_shader_primitives: u64,
            geometry_shader_primitives: u64,
            clipping_primitives: u64,
            clipping_input_primitives: u64,
            clipping_output_primitives: u64,
        },
        pipeline_metrics: struct {
            active_pipelines: u32,
            pipeline_cache_size: u64,
            pipeline_cache_hits: u32,
            pipeline_cache_misses: u32,
        },
        command_buffer_metrics: struct {
            total_command_buffers: u32,
            active_command_buffers: u32,
            secondary_command_buffers: u32,
        },
    }) void {
        // Update basic metrics
        self.fps_history[self.history_index] = metrics.fps;
        self.frame_time_history[self.history_index] = metrics.frame_time;
        self.gpu_usage_history[self.history_index] = metrics.gpu_usage;
        self.vram_usage_history[self.history_index] = metrics.vram_usage;
        self.cpu_usage_history[self.history_index] = metrics.cpu_usage;
        self.memory_usage_history[self.history_index] = metrics.memory_usage;

        // Update shader metrics
        self.vertex_shader_history[self.history_index] = metrics.shader_metrics.vertex_shader_invocations;
        self.fragment_shader_history[self.history_index] = metrics.shader_metrics.fragment_shader_invocations;
        self.geometry_shader_history[self.history_index] = metrics.shader_metrics.geometry_shader_invocations;
        self.compute_shader_history[self.history_index] = metrics.shader_metrics.compute_shader_invocations;

        // Update primitive metrics
        self.primitive_history[self.history_index] = metrics.primitive_metrics.input_assembly_primitives;

        // Update pipeline metrics
        self.pipeline_cache_hits_history[self.history_index] = metrics.pipeline_metrics.pipeline_cache_hits;
        self.pipeline_cache_misses_history[self.history_index] = metrics.pipeline_metrics.pipeline_cache_misses;

        // Update command buffer metrics
        self.command_buffer_history[self.history_index] = metrics.command_buffer_metrics.active_command_buffers;

        // Update history index
        self.history_index = (self.history_index + 1) % HISTORY_SIZE;

        // Analyze performance and generate recommendations
        if (self.optimizer) |*optimizer| {
            optimizer.analyzePerformance(metrics) catch |err| {
                self.logger.err("Failed to analyze performance: {}", .{err});
            };
        }
    }

    pub fn render(self: *Self) void {
        if (c.igBegin("Performance Dashboard", null, c.ImGuiWindowFlags_None)) {
            // Display options
            _ = c.igCheckbox("Show Detailed Metrics", &self.show_detailed_metrics);
            if (self.show_detailed_metrics) {
                c.igSameLine(0, 20);
                _ = c.igCheckbox("Shader Metrics", &self.show_shader_metrics);
                c.igSameLine(0, 20);
                _ = c.igCheckbox("Primitive Metrics", &self.show_primitive_metrics);
                c.igSameLine(0, 20);
                _ = c.igCheckbox("Pipeline Metrics", &self.show_pipeline_metrics);
                c.igSameLine(0, 20);
                _ = c.igCheckbox("Command Buffer Metrics", &self.show_command_buffer_metrics);
            }
            c.igSameLine(0, 20);
            _ = c.igCheckbox("Show Recommendations", &self.show_recommendations);

            // Basic metrics
            self.renderBasicMetrics();

            // Detailed metrics
            if (self.show_detailed_metrics) {
                c.igSeparator();
                
                if (self.show_shader_metrics) {
                    self.renderShaderMetrics();
                }
                
                if (self.show_primitive_metrics) {
                    self.renderPrimitiveMetrics();
                }
                
                if (self.show_pipeline_metrics) {
                    self.renderPipelineMetrics();
                }
                
                if (self.show_command_buffer_metrics) {
                    self.renderCommandBufferMetrics();
                }
            }

            // Performance recommendations
            if (self.show_recommendations) {
                c.igSeparator();
                self.renderRecommendations();
            }
        }
        c.igEnd();
    }

    fn renderBasicMetrics(self: *Self) void {
        // FPS and Frame Time
        const current_fps = self.fps_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
        const current_frame_time = self.frame_time_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
        
        c.igText("FPS: %.1f", current_fps);
        c.igText("Frame Time: %.2f ms", current_frame_time);
        
        // Performance graphs
        const graph_size = .{ .x = c.igGetWindowWidth() - 40, .y = 80 };
        
        // FPS Graph
        c.igText("FPS History");
        c.igPlotLines("##fps", &self.fps_history, HISTORY_SIZE, @intCast(i32, self.history_index), null, 0.0, 240.0, graph_size);
        
        // Frame Time Graph
        c.igText("Frame Time History (ms)");
        c.igPlotLines("##frame_time", &self.frame_time_history, HISTORY_SIZE, @intCast(i32, self.history_index), null, 0.0, 33.33, graph_size);
        
        // Usage bars
        const current_gpu_usage = self.gpu_usage_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
        const current_vram_usage = self.vram_usage_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
        const current_cpu_usage = self.cpu_usage_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
        const current_memory_usage = self.memory_usage_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
        
        c.igText("GPU Usage: %.1f%%", current_gpu_usage);
        self.renderProgressBar(current_gpu_usage / 100.0);
        
        c.igText("VRAM Usage: %.1f%%", current_vram_usage);
        self.renderProgressBar(current_vram_usage / 100.0);
        
        c.igText("CPU Usage: %.1f%%", current_cpu_usage);
        self.renderProgressBar(current_cpu_usage / 100.0);
        
        c.igText("Memory Usage: %.1f%%", current_memory_usage);
        self.renderProgressBar(current_memory_usage / 100.0);
    }

    fn renderShaderMetrics(self: *Self) void {
        if (c.igCollapsingHeader("Shader Metrics", c.ImGuiTreeNodeFlags_None)) {
            const current_vertex = self.vertex_shader_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
            const current_fragment = self.fragment_shader_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
            const current_geometry = self.geometry_shader_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
            const current_compute = self.compute_shader_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];

            c.igText("Vertex Shader Invocations: %d", current_vertex);
            c.igText("Fragment Shader Invocations: %d", current_fragment);
            c.igText("Geometry Shader Invocations: %d", current_geometry);
            c.igText("Compute Shader Invocations: %d", current_compute);

            const graph_size = .{ .x = c.igGetWindowWidth() - 40, .y = 60 };
            
            c.igText("Shader Invocations History");
            c.igPlotHistogram("##shader_invocations", &self.vertex_shader_history, HISTORY_SIZE, @intCast(i32, self.history_index), null, 0.0, @intToFloat(f32, current_vertex) * 1.2, graph_size);
        }
    }

    fn renderPrimitiveMetrics(self: *Self) void {
        if (c.igCollapsingHeader("Primitive Metrics", c.ImGuiTreeNodeFlags_None)) {
            const current_primitives = self.primitive_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
            
            c.igText("Input Assembly Primitives: %d", current_primitives);
            
            const graph_size = .{ .x = c.igGetWindowWidth() - 40, .y = 60 };
            
            c.igText("Primitive Count History");
            c.igPlotHistogram("##primitive_count", &self.primitive_history, HISTORY_SIZE, @intCast(i32, self.history_index), null, 0.0, @intToFloat(f32, current_primitives) * 1.2, graph_size);
        }
    }

    fn renderPipelineMetrics(self: *Self) void {
        if (c.igCollapsingHeader("Pipeline Metrics", c.ImGuiTreeNodeFlags_None)) {
            const current_hits = self.pipeline_cache_hits_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
            const current_misses = self.pipeline_cache_misses_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
            
            c.igText("Pipeline Cache Hits: %d", current_hits);
            c.igText("Pipeline Cache Misses: %d", current_misses);
            
            const hit_rate = if (current_hits + current_misses > 0)
                @intToFloat(f32, current_hits) / @intToFloat(f32, current_hits + current_misses) * 100.0
            else
                0.0;
            
            c.igText("Cache Hit Rate: %.1f%%", hit_rate);
            self.renderProgressBar(hit_rate / 100.0);
        }
    }

    fn renderCommandBufferMetrics(self: *Self) void {
        if (c.igCollapsingHeader("Command Buffer Metrics", c.ImGuiTreeNodeFlags_None)) {
            const current_buffers = self.command_buffer_history[(self.history_index + HISTORY_SIZE - 1) % HISTORY_SIZE];
            
            c.igText("Active Command Buffers: %d", current_buffers);
            
            const graph_size = .{ .x = c.igGetWindowWidth() - 40, .y = 60 };
            
            c.igText("Command Buffer Count History");
            c.igPlotHistogram("##command_buffers", &self.command_buffer_history, HISTORY_SIZE, @intCast(i32, self.history_index), null, 0.0, @intToFloat(f32, current_buffers) * 1.2, graph_size);
        }
    }

    fn renderRecommendations(self: *Self) void {
        if (c.igCollapsingHeader("Performance Recommendations", c.ImGuiTreeNodeFlags_None)) {
            // Auto-optimization controls
            if (self.optimizer) |*optimizer| {
                var auto_optimize = optimizer.auto_optimize;
                _ = c.igCheckbox("Auto-Optimize", &auto_optimize);
                optimizer.setAutoOptimize(auto_optimize);

                if (auto_optimize) {
                    c.igSameLine(0, 20);
                    var level = optimizer.optimization_level;
                    if (c.igBeginCombo("Optimization Level", switch (level) {
                        .conservative => "Conservative",
                        .balanced => "Balanced",
                        .aggressive => "Aggressive",
                    })) {
                        if (c.igSelectable("Conservative", level == .conservative, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                            level = .conservative;
                        }
                        if (c.igSelectable("Balanced", level == .balanced, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                            level = .balanced;
                        }
                        if (c.igSelectable("Aggressive", level == .aggressive, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                            level = .aggressive;
                        }
                        c.igEndCombo();
                    }
                    optimizer.setOptimizationLevel(level);
                }
            }

            // Display recommendations
            if (self.optimizer) |*optimizer| {
                const recommendations = optimizer.getRecommendations();
                if (recommendations.len == 0) {
                    c.igText("No performance issues detected.");
                } else {
                    for (recommendations) |recommendation| {
                        const color = switch (recommendation.priority) {
                            .critical => .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 },
                            .high => .{ .x = 1.0, .y = 0.5, .z = 0.0, .w = 1.0 },
                            .medium => .{ .x = 1.0, .y = 1.0, .z = 0.0, .w = 1.0 },
                            .low => .{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 1.0 },
                        };

                        c.igPushStyleColor(c.ImGuiCol_Text, color);
                        c.igBulletText("%s", recommendation.message.ptr);
                        c.igPopStyleColor(1);

                        if (recommendation.action != null) {
                            c.igIndent(20);
                            c.igText("Action: %s", switch (recommendation.action.?) {
                                .reduce_shader_complexity => "Reduce shader complexity",
                                .optimize_pipeline => "Optimize pipeline",
                                .adjust_memory_usage => "Adjust memory usage",
                                .optimize_command_buffers => "Optimize command buffers",
                                .adjust_quality_settings => "Adjust quality settings",
                            });
                            c.igUnindent(20);
                        }
                    }
                }
            }
        }
    }

    fn renderProgressBar(self: *Self, fraction: f32) void {
        const color = if (fraction > 0.9)
            .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 }
        else if (fraction > 0.7)
            .{ .x = 1.0, .y = 0.5, .z = 0.0, .w = 1.0 }
        else
            .{ .x = 0.0, .y = 1.0, .z = 0.0, .w = 1.0 };

        c.igPushStyleColor(c.ImGuiCol_PlotHistogram, color);
        c.igProgressBar(fraction, .{ .x = -1, .y = 0 }, null);
        c.igPopStyleColor(1);
    }
}; 