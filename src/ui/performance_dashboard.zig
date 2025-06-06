const std = @import("std");
const c = @cImport({
    @cInclude("imgui.h");
});
const PerformanceOptimizer = @import("../renderer/performance_optimizer.zig").PerformanceOptimizer;
const PerformancePreset = @import("../renderer/performance_presets.zig").PerformancePreset;

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
    show_preset_editor: bool,
    
    // Performance optimizer
    optimizer: ?*PerformanceOptimizer,
    
    // Performance presets
    presets: std.ArrayList(*PerformancePreset),
    current_preset: ?*PerformancePreset,
    custom_presets_dir: []const u8,
    
    logger: std.log.Logger,
    allocator: std.mem.Allocator,

    // Add new fields for preset creation dialog
    show_create_preset_dialog: bool,
    new_preset_name: [256]u8,
    new_preset_description: [512]u8,
    new_preset_base: ?*PerformancePreset,
    new_preset_name_len: usize,
    new_preset_description_len: usize,

    // Add validation state fields
    preset_name_error: ?[]const u8,
    preset_name_warning: ?[]const u8,

    // Add sanitization state field
    sanitized_name: ?[]const u8,

    // Add language detection state
    detected_language: enum { english, chinese, arabic, russian, unknown },

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
            .show_preset_editor = false,
            .optimizer = try PerformanceOptimizer.init(allocator),
            .presets = std.ArrayList(*PerformancePreset).init(allocator),
            .current_preset = null,
            .custom_presets_dir = "presets",
            .logger = std.log.scoped(.performance_dashboard),
            .allocator = allocator,
            .show_create_preset_dialog = false,
            .new_preset_name = [_]u8{0} ** 256,
            .new_preset_description = [_]u8{0} ** 512,
            .new_preset_base = null,
            .new_preset_name_len = 0,
            .new_preset_description_len = 0,
            .preset_name_error = null,
            .preset_name_warning = null,
            .sanitized_name = null,
            .detected_language = .unknown,
        };

        // Create presets directory if it doesn't exist
        std.fs.cwd().makeDir(self.custom_presets_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        // Load default presets
        const default_presets = try PerformancePreset.createDefaultPresets(allocator);
        for (default_presets) |preset| {
            try self.presets.append(preset);
        }

        // Load custom presets
        try self.loadCustomPresets();

        // Set default preset
        if (self.presets.items.len > 0) {
            self.current_preset = self.presets.items[0];
        }

        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.optimizer) |*optimizer| {
            optimizer.deinit();
        }

        // Free presets
        for (self.presets.items) |preset| {
            preset.deinit(allocator);
        }
        self.presets.deinit();

        if (self.preset_name_error) |err| {
            allocator.free(err);
        }
        if (self.preset_name_warning) |warn| {
            allocator.free(warn);
        }
        if (self.sanitized_name) |name| {
            allocator.free(name);
        }
        allocator.destroy(self);
    }

    fn loadCustomPresets(self: *Self) !void {
        var dir = try std.fs.cwd().openDir(self.custom_presets_dir, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (std.mem.endsWith(u8, entry.name, ".json")) {
                const file_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.custom_presets_dir, entry.name });
                defer self.allocator.free(file_path);

                const preset = try PerformancePreset.loadFromFile(self.allocator, file_path);
                try self.presets.append(preset);
            }
        }
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
            c.igSameLine(0, 20);
            _ = c.igCheckbox("Show Preset Editor", &self.show_preset_editor);

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

            // Preset management
            if (self.show_preset_editor) {
                c.igSeparator();
                self.renderPresetEditor();
            }
        }
        c.igEnd();
    }

    fn renderPresetEditor(self: *Self) void {
        if (c.igCollapsingHeader("Performance Presets", c.ImGuiTreeNodeFlags_None)) {
            // Preset selector
            if (c.igBeginCombo("Current Preset", if (self.current_preset) |preset| preset.name.ptr else "None")) {
                for (self.presets.items) |preset| {
                    const is_selected = self.current_preset == preset;
                    if (c.igSelectable(preset.name.ptr, is_selected, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                        self.current_preset = preset;
                    }
                }
                c.igEndCombo();
            }

            // Preset description
            if (self.current_preset) |preset| {
                c.igText("Description: %s", preset.description.ptr);
                c.igText("Last Modified: %d", preset.last_modified);

                // Quality settings
                if (c.igCollapsingHeader("Quality Settings", c.ImGuiTreeNodeFlags_None)) {
                    var msaa = @intCast(i32, preset.settings.msaa_level);
                    if (c.igSliderInt("MSAA Level", &msaa, 0, 8)) {
                        preset.settings.msaa_level = @intCast(u32, msaa);
                    }

                    var texture_quality = @enumToInt(preset.settings.texture_quality);
                    if (c.igCombo("Texture Quality", &texture_quality, "Low\0Medium\0High\0Ultra\0", 4)) {
                        preset.settings.texture_quality = @intToEnum(PerformancePreset.TextureQuality, texture_quality);
                    }

                    var shadow_quality = @enumToInt(preset.settings.shadow_quality);
                    if (c.igCombo("Shadow Quality", &shadow_quality, "Low\0Medium\0High\0Ultra\0", 4)) {
                        preset.settings.shadow_quality = @intToEnum(PerformancePreset.ShadowQuality, shadow_quality);
                    }

                    var aniso = @intCast(i32, preset.settings.anisotropic_filtering);
                    if (c.igSliderInt("Anisotropic Filtering", &aniso, 0, 16)) {
                        preset.settings.anisotropic_filtering = @intCast(u32, aniso);
                    }

                    var view_dist = preset.settings.view_distance;
                    if (c.igSliderFloat("View Distance", &view_dist, 100.0, 2000.0, "%.0f")) {
                        preset.settings.view_distance = view_dist;
                    }
                }

                // Performance settings
                if (c.igCollapsingHeader("Performance Settings", c.ImGuiTreeNodeFlags_None)) {
                    var max_fps = @intCast(i32, preset.settings.max_fps);
                    if (c.igSliderInt("Max FPS", &max_fps, 0, 240)) {
                        preset.settings.max_fps = @intCast(u32, max_fps);
                    }

                    _ = c.igCheckbox("VSync", &preset.settings.vsync);
                    _ = c.igCheckbox("Triple Buffering", &preset.settings.triple_buffering);
                }

                // Shader settings
                if (c.igCollapsingHeader("Shader Settings", c.ImGuiTreeNodeFlags_None)) {
                    var shader_quality = @enumToInt(preset.settings.shader_quality);
                    if (c.igCombo("Shader Quality", &shader_quality, "Low\0Medium\0High\0Ultra\0", 4)) {
                        preset.settings.shader_quality = @intToEnum(PerformancePreset.ShaderQuality, shader_quality);
                    }

                    var compute_quality = @enumToInt(preset.settings.compute_shader_quality);
                    if (c.igCombo("Compute Shader Quality", &compute_quality, "Disabled\0Basic\0Advanced\0Full\0", 4)) {
                        preset.settings.compute_shader_quality = @intToEnum(PerformancePreset.ComputeShaderQuality, compute_quality);
                    }
                }

                // Memory settings
                if (c.igCollapsingHeader("Memory Settings", c.ImGuiTreeNodeFlags_None)) {
                    _ = c.igCheckbox("Texture Streaming", &preset.settings.texture_streaming);

                    var cache_size = @intCast(i32, preset.settings.texture_cache_size / (1024 * 1024));
                    if (c.igSliderInt("Texture Cache Size (MB)", &cache_size, 64, 4096)) {
                        preset.settings.texture_cache_size = @intCast(u64, cache_size) * 1024 * 1024;
                    }

                    var lod_levels = @intCast(i32, preset.settings.geometry_lod_levels);
                    if (c.igSliderInt("Geometry LOD Levels", &lod_levels, 1, 5)) {
                        preset.settings.geometry_lod_levels = @intCast(u32, lod_levels);
                    }
                }

                // Pipeline settings
                if (c.igCollapsingHeader("Pipeline Settings", c.ImGuiTreeNodeFlags_None)) {
                    var cache_size = @intCast(i32, preset.settings.pipeline_cache_size / (1024 * 1024));
                    if (c.igSliderInt("Pipeline Cache Size (MB)", &cache_size, 32, 1024)) {
                        preset.settings.pipeline_cache_size = @intCast(u64, cache_size) * 1024 * 1024;
                    }

                    _ = c.igCheckbox("Command Buffer Reuse", &preset.settings.command_buffer_reuse);
                    _ = c.igCheckbox("Secondary Command Buffers", &preset.settings.secondary_command_buffers);
                }

                // Advanced settings
                if (c.igCollapsingHeader("Advanced Settings", c.ImGuiTreeNodeFlags_None)) {
                    _ = c.igCheckbox("Async Compute", &preset.settings.async_compute);
                    _ = c.igCheckbox("Geometry Shaders", &preset.settings.geometry_shaders);
                    _ = c.igCheckbox("Tessellation", &preset.settings.tessellation);
                    _ = c.igCheckbox("Ray Tracing", &preset.settings.ray_tracing);
                }

                // Save/Load buttons
                if (c.igButton("Save Preset", .{ .x = 120, .y = 0 })) {
                    const file_path = std.fmt.allocPrint(self.allocator, "{s}/{s}.json", .{ self.custom_presets_dir, preset.name }) catch continue;
                    defer self.allocator.free(file_path);

                    preset.saveToFile(file_path) catch |err| {
                        self.logger.err("Failed to save preset: {}", .{err});
                    };
                }

                c.igSameLine(0, 20);
                if (c.igButton("Create New Preset", .{ .x = 120, .y = 0 })) {
                    self.show_create_preset_dialog = true;
                    self.new_preset_name = [_]u8{0} ** 256;
                    self.new_preset_description = [_]u8{0} ** 512;
                    self.new_preset_base = self.current_preset;
                    self.new_preset_name_len = 0;
                    self.new_preset_description_len = 0;
                }
            }
        }

        // Render create preset dialog
        if (self.show_create_preset_dialog) {
            self.renderCreatePresetDialog();
        }
    }

    fn renderCreatePresetDialog(self: *Self) void {
        const window_flags = c.ImGuiWindowFlags_AlwaysAutoResize | 
                           c.ImGuiWindowFlags_NoSavedSettings |
                           c.ImGuiWindowFlags_NoCollapse;

        if (c.igBegin("Create New Preset", &self.show_create_preset_dialog, window_flags)) {
            // Preset name input with validation
            c.igText("Preset Name:");
            const input_flags = if (self.preset_name_error != null)
                c.ImGuiInputTextFlags_None
            else
                c.ImGuiInputTextFlags_None;

            if (c.igInputText("##preset_name", &self.new_preset_name, 256, input_flags, null, null)) {
                self.new_preset_name_len = std.mem.len(&self.new_preset_name);
                self.validatePresetName(self.new_preset_name[0..self.new_preset_name_len]) catch |err| {
                    self.logger.err("Failed to validate preset name: {}", .{err});
                };
            }

            // Show validation messages
            if (self.preset_name_error) |err| {
                c.igPushStyleColor(c.ImGuiCol_Text, .{ .x = 1.0, .y = 0.0, .z = 0.0, .w = 1.0 });
                c.igText("%s", err.ptr);
                c.igPopStyleColor(1);

                // Show sanitized name suggestion
                if (self.sanitized_name == null) {
                    self.sanitizePresetName(self.new_preset_name[0..self.new_preset_name_len]) catch |err| {
                        self.logger.err("Failed to sanitize preset name: {}", .{err});
                    };
                }

                if (self.sanitized_name) |sanitized| {
                    c.igText("Suggested name: %s", sanitized.ptr);
                    if (c.igButton("Use Suggested Name", .{ .x = 200, .y = 0 })) {
                        @memcpy(self.new_preset_name[0..sanitized.len], sanitized);
                        self.new_preset_name[sanitized.len] = 0;
                        self.new_preset_name_len = sanitized.len;
                        self.validatePresetName(sanitized) catch |err| {
                            self.logger.err("Failed to validate sanitized name: {}", .{err});
                        };
                    }
                }
            } else if (self.preset_name_warning) |warn| {
                c.igPushStyleColor(c.ImGuiCol_Text, .{ .x = 1.0, .y = 0.7, .z = 0.0, .w = 1.0 });
                c.igText("%s", warn.ptr);
                c.igPopStyleColor(1);
            }

            // Preset description input
            c.igText("Description:");
            if (c.igInputTextMultiline("##preset_description", &self.new_preset_description, 512, .{ .x = 400, .y = 100 }, c.ImGuiInputTextFlags_None, null, null)) {
                self.new_preset_description_len = std.mem.len(&self.new_preset_description);
            }

            // Base preset selection
            c.igText("Base Preset:");
            if (c.igBeginCombo("##base_preset", if (self.new_preset_base) |preset| preset.name.ptr else "None")) {
                if (c.igSelectable("None", self.new_preset_base == null, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                    self.new_preset_base = null;
                }
                for (self.presets.items) |preset| {
                    const is_selected = self.new_preset_base == preset;
                    if (c.igSelectable(preset.name.ptr, is_selected, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                        self.new_preset_base = preset;
                    }
                }
                c.igEndCombo();
            }

            c.igSpacing();
            c.igSeparator();
            c.igSpacing();

            // Buttons
            const button_size = .{ .x = 120, .y = 0 };
            
            // Disable Create button if there are validation errors
            if (self.preset_name_error != null) {
                c.igBeginDisabled(true);
            }
            
            if (c.igButton("Create", button_size)) {
                if (self.new_preset_name_len > 0 and self.preset_name_error == null) {
                    // Create new preset
                    const settings = if (self.new_preset_base) |base| base.settings else PerformancePreset.Settings{
                        .msaa_level = 2,
                        .texture_quality = .medium,
                        .shadow_quality = .medium,
                        .anisotropic_filtering = 4,
                        .view_distance = 500.0,
                        .max_fps = 60,
                        .vsync = true,
                        .triple_buffering = true,
                        .shader_quality = .medium,
                        .compute_shader_quality = .advanced,
                        .texture_streaming = true,
                        .texture_cache_size = 512 * 1024 * 1024,
                        .geometry_lod_levels = 3,
                        .pipeline_cache_size = 128 * 1024 * 1024,
                        .command_buffer_reuse = true,
                        .secondary_command_buffers = true,
                        .async_compute = true,
                        .geometry_shaders = true,
                        .tessellation = false,
                        .ray_tracing = false,
                    };

                    const new_preset = PerformancePreset.init(
                        self.allocator,
                        self.new_preset_name[0..self.new_preset_name_len],
                        self.new_preset_description[0..self.new_preset_description_len],
                        settings,
                    ) catch |err| {
                        self.logger.err("Failed to create new preset: {}", .{err});
                        return;
                    };

                    // Add to presets list
                    self.presets.append(new_preset) catch |err| {
                        self.logger.err("Failed to add new preset: {}", .{err});
                        new_preset.deinit(self.allocator);
                        return;
                    };

                    // Set as current preset
                    self.current_preset = new_preset;

                    // Save to file
                    const file_path = std.fmt.allocPrint(self.allocator, "{s}/{s}.json", .{ 
                        self.custom_presets_dir, 
                        self.new_preset_name[0..self.new_preset_name_len] 
                    }) catch continue;
                    defer self.allocator.free(file_path);

                    new_preset.saveToFile(file_path) catch |err| {
                        self.logger.err("Failed to save new preset: {}", .{err});
                    };

                    self.show_create_preset_dialog = false;
                }
            }

            if (self.preset_name_error != null) {
                c.igEndDisabled();
            }

            c.igSameLine(0, 20);
            if (c.igButton("Cancel", button_size)) {
                self.show_create_preset_dialog = false;
            }

            // Add language detection display
            if (self.detected_language != .unknown) {
                const language_name = switch (self.detected_language) {
                    .english => "English",
                    .chinese => "Traditional Chinese",
                    .arabic => "Arabic",
                    .russian => "Russian",
                    .unknown => "Unknown",
                };
                c.igText("Detected language: %s", language_name.ptr);
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

    fn validatePresetName(self: *Self, name: []const u8) !void {
        // Clear previous validation messages
        if (self.preset_name_error) |err| {
            self.allocator.free(err);
            self.preset_name_error = null;
        }
        if (self.preset_name_warning) |warn| {
            self.allocator.free(warn);
            self.preset_name_warning = null;
        }

        // Check for empty name
        if (name.len == 0) {
            self.preset_name_error = try self.allocator.dupe(u8, "Preset name cannot be empty");
            return;
        }

        // Check for minimum length (at least 3 characters)
        if (name.len < 3) {
            self.preset_name_error = try self.allocator.dupe(u8, "Preset name must be at least 3 characters long");
            return;
        }

        // Check for maximum length
        if (name.len > 64) {
            self.preset_name_error = try self.allocator.dupe(u8, "Preset name must be 64 characters or less");
            return;
        }

        // Check for invalid characters
        const invalid_chars = "<>:\"/\\|?*";
        for (name) |c| {
            if (std.mem.indexOfScalar(u8, invalid_chars, c) != null) {
                self.preset_name_error = try self.allocator.dupe(u8, "Preset name contains invalid characters");
                return;
            }
        }

        // Check for allowed characters (alphanumeric, spaces, hyphens, underscores)
        const allowed_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ ";
        var has_allowed_char = false;
        for (name) |c| {
            if (std.mem.indexOfScalar(u8, allowed_chars, c) != null) {
                has_allowed_char = true;
                break;
            }
        }
        if (!has_allowed_char) {
            self.preset_name_error = try self.allocator.dupe(u8, "Preset name must contain at least one letter, number, or allowed special character (-_)");
            return;
        }

        // Check for consecutive spaces
        var prev_char: ?u8 = null;
        for (name) |c| {
            if (c == ' ' and prev_char == ' ') {
                self.preset_name_warning = try self.allocator.dupe(u8, "Preset name contains consecutive spaces");
                break;
            }
            prev_char = c;
        }

        // Check for leading/trailing spaces
        if (name[0] == ' ' or name[name.len - 1] == ' ') {
            self.preset_name_warning = try self.allocator.dupe(u8, "Preset name has leading/trailing spaces");
        }

        // Check for consecutive special characters
        prev_char = null;
        for (name) |c| {
            if ((c == '-' or c == '_') and prev_char != null and (prev_char.? == '-' or prev_char.? == '_')) {
                self.preset_name_warning = try self.allocator.dupe(u8, "Preset name contains consecutive special characters");
                break;
            }
            prev_char = c;
        }

        // Check for case-insensitive duplicates
        for (self.presets.items) |preset| {
            if (std.ascii.eqlIgnoreCase(preset.name, name)) {
                self.preset_name_error = try self.allocator.dupe(u8, "A preset with this name already exists (case-insensitive)");
                return;
            }
        }

        // Check for reserved names (case-insensitive)
        const reserved_names = [_][]const u8{ "Performance", "Balanced", "Quality" };
        for (reserved_names) |reserved| {
            if (std.ascii.eqlIgnoreCase(reserved, name)) {
                self.preset_name_error = try self.allocator.dupe(u8, "This name is reserved for default presets");
                return;
            }
        }

        // Check for common prefixes/suffixes that might cause confusion
        const confusing_prefixes = [_][]const u8{ "new", "copy", "backup", "old", "temp" };
        const confusing_suffixes = [_][]const u8{ "copy", "backup", "old", "temp" };

        for (confusing_prefixes) |prefix| {
            if (name.len > prefix.len + 1 and std.ascii.eqlIgnoreCase(name[0..prefix.len], prefix) and name[prefix.len] == ' ') {
                self.preset_name_warning = try self.allocator.dupe(u8, "Preset name starts with a potentially confusing prefix");
                break;
            }
        }

        for (confusing_suffixes) |suffix| {
            if (name.len > suffix.len + 1 and std.ascii.eqlIgnoreCase(name[name.len - suffix.len..], suffix) and name[name.len - suffix.len - 1] == ' ') {
                self.preset_name_warning = try self.allocator.dupe(u8, "Preset name ends with a potentially confusing suffix");
                break;
            }
        }

        // Check for numbers-only names
        var is_numbers_only = true;
        for (name) |c| {
            if (c < '0' or c > '9') {
                is_numbers_only = false;
                break;
            }
        }
        if (is_numbers_only) {
            self.preset_name_warning = try self.allocator.dupe(u8, "Preset name contains only numbers");
        }

        // Check for very long words (more than 20 characters)
        var current_word_len: usize = 0;
        for (name) |c| {
            if (c == ' ') {
                current_word_len = 0;
            } else {
                current_word_len += 1;
                if (current_word_len > 20) {
                    self.preset_name_warning = try self.allocator.dupe(u8, "Preset name contains very long words");
                    break;
                }
            }
        }
    }

    fn detectLanguage(self: *Self, text: []const u8) void {
        var chinese_chars: usize = 0;
        var arabic_chars: usize = 0;
        var russian_chars: usize = 0;
        var total_chars: usize = 0;

        for (text) |c| {
            // Skip spaces and special characters
            if (c == ' ' or c == '-' or c == '_') continue;
            total_chars += 1;

            // Traditional Chinese characters (CJK Unified Ideographs)
            if ((c >= 0x4E00 and c <= 0x9FFF) or
                (c >= 0x3400 and c <= 0x4DBF) or
                (c >= 0x20000 and c <= 0x2A6DF) or
                (c >= 0x2A700 and c <= 0x2B73F) or
                (c >= 0x2B740 and c <= 0x2B81F) or
                (c >= 0x2B820 and c <= 0x2CEAF) or
                (c >= 0xF900 and c <= 0xFAFF) or
                (c >= 0x2F800 and c <= 0x2FA1F)) {
                chinese_chars += 1;
            }
            // Arabic characters
            else if ((c >= 0x0600 and c <= 0x06FF) or
                     (c >= 0x0750 and c <= 0x077F) or
                     (c >= 0x08A0 and c <= 0x08FF) or
                     (c >= 0xFB50 and c <= 0xFDFF) or
                     (c >= 0xFE70 and c <= 0xFEFF)) {
                arabic_chars += 1;
            }
            // Russian characters
            else if ((c >= 0x0400 and c <= 0x04FF) or
                     (c >= 0x0500 and c <= 0x052F)) {
                russian_chars += 1;
            }
        }

        if (total_chars == 0) {
            self.detected_language = .unknown;
            return;
        }

        const chinese_ratio = @intToFloat(f32, chinese_chars) / @intToFloat(f32, total_chars);
        const arabic_ratio = @intToFloat(f32, arabic_chars) / @intToFloat(f32, total_chars);
        const russian_ratio = @intToFloat(f32, russian_chars) / @intToFloat(f32, total_chars);

        if (chinese_ratio > 0.5) {
            self.detected_language = .chinese;
        } else if (arabic_ratio > 0.5) {
            self.detected_language = .arabic;
        } else if (russian_ratio > 0.5) {
            self.detected_language = .russian;
        } else {
            self.detected_language = .english;
        }
    }

    fn sanitizePresetName(self: *Self, name: []const u8) ![]const u8 {
        // Free previous sanitized name if it exists
        if (self.sanitized_name) |prev| {
            self.allocator.free(prev);
            self.sanitized_name = null;
        }

        // Detect language
        self.detectLanguage(name);

        // Create a buffer for the sanitized name
        var sanitized = try self.allocator.alloc(u8, name.len * 2); // Double size for potential transliteration
        var sanitized_len: usize = 0;

        // Track previous character to handle consecutive special chars
        var prev_char: ?u8 = null;
        var in_word = false;
        var word_start = true;

        // Language-specific sanitization
        switch (self.detected_language) {
            .chinese => {
                // For Chinese, we'll transliterate to Pinyin and keep some Chinese characters
                for (name) |c| {
                    // Keep valid Chinese characters
                    if ((c >= 0x4E00 and c <= 0x9FFF) or
                        (c >= 0x3400 and c <= 0x4DBF) or
                        (c >= 0x20000 and c <= 0x2A6DF) or
                        (c >= 0x2A700 and c <= 0x2B73F) or
                        (c >= 0x2B740 and c <= 0x2B81F) or
                        (c >= 0x2B820 and c <= 0x2CEAF) or
                        (c >= 0xF900 and c <= 0xFAFF) or
                        (c >= 0x2F800 and c <= 0x2FA1F)) {
                        sanitized[sanitized_len] = c;
                        sanitized_len += 1;
                        in_word = true;
                        word_start = false;
                        continue;
                    }

                    // Handle spaces and special characters
                    if (c == ' ' or c == '-' or c == '_') {
                        if (in_word) {
                            sanitized[sanitized_len] = ' ';
                            sanitized_len += 1;
                            in_word = false;
                            word_start = true;
                        }
                        continue;
                    }

                    // Convert to lowercase for non-Chinese characters
                    if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9')) {
                        var char_to_add = if (word_start and c >= 'A' and c <= 'Z') c + 32 else c;
                        if (word_start and char_to_add >= '0' and char_to_add <= '9') continue;
                        sanitized[sanitized_len] = char_to_add;
                        sanitized_len += 1;
                        in_word = true;
                        word_start = false;
                    }
                }
            },
            .arabic => {
                // For Arabic, we'll transliterate to Latin characters
                for (name) |c| {
                    // Handle Arabic characters (simplified transliteration)
                    if ((c >= 0x0600 and c <= 0x06FF) or
                        (c >= 0x0750 and c <= 0x077F) or
                        (c >= 0x08A0 and c <= 0x08FF) or
                        (c >= 0xFB50 and c <= 0xFDFF) or
                        (c >= 0xFE70 and c <= 0xFEFF)) {
                        // Basic transliteration (simplified)
                        const latin = switch (c) {
                            0x0627...0x0628 => 'b',
                            0x062A...0x062B => 't',
                            0x062C...0x062D => 'h',
                            0x062E...0x062F => 'd',
                            0x0630...0x0631 => 'r',
                            0x0632...0x0633 => 's',
                            0x0634...0x0635 => 's',
                            0x0636...0x0637 => 't',
                            0x0638...0x0639 => 'a',
                            0x063A...0x0641 => 'f',
                            0x0642...0x0643 => 'k',
                            0x0644...0x0645 => 'm',
                            0x0646...0x0647 => 'h',
                            0x0648...0x0649 => 'y',
                            0x064A...0x064B => 'a',
                            else => ' ',
                        };
                        if (latin != ' ') {
                            sanitized[sanitized_len] = latin;
                            sanitized_len += 1;
                            in_word = true;
                            word_start = false;
                        }
                        continue;
                    }

                    // Handle spaces and special characters
                    if (c == ' ' or c == '-' or c == '_') {
                        if (in_word) {
                            sanitized[sanitized_len] = ' ';
                            sanitized_len += 1;
                            in_word = false;
                            word_start = true;
                        }
                        continue;
                    }

                    // Convert to lowercase for non-Arabic characters
                    if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9')) {
                        var char_to_add = if (word_start and c >= 'A' and c <= 'Z') c + 32 else c;
                        if (word_start and char_to_add >= '0' and char_to_add <= '9') continue;
                        sanitized[sanitized_len] = char_to_add;
                        sanitized_len += 1;
                        in_word = true;
                        word_start = false;
                    }
                }
            },
            .russian => {
                // For Russian, we'll transliterate to Latin characters
                for (name) |c| {
                    // Handle Russian characters (transliteration)
                    if ((c >= 0x0400 and c <= 0x04FF) or
                        (c >= 0x0500 and c <= 0x052F)) {
                        // Basic transliteration (simplified)
                        const latin = switch (c) {
                            0x0410...0x0411 => 'a',
                            0x0412...0x0413 => 'v',
                            0x0414...0x0415 => 'd',
                            0x0416...0x0417 => 'zh',
                            0x0418...0x0419 => 'i',
                            0x041A...0x041B => 'k',
                            0x041C...0x041D => 'm',
                            0x041E...0x041F => 'o',
                            0x0420...0x0421 => 'p',
                            0x0422...0x0423 => 't',
                            0x0424...0x0425 => 'f',
                            0x0426...0x0427 => 'ts',
                            0x0428...0x0429 => 'sh',
                            0x042A...0x042B => 'y',
                            0x042C...0x042D => 'e',
                            0x042E...0x042F => 'yu',
                            0x0430...0x0431 => 'a',
                            0x0432...0x0433 => 'v',
                            0x0434...0x0435 => 'd',
                            0x0436...0x0437 => 'zh',
                            0x0438...0x0439 => 'i',
                            0x043A...0x043B => 'k',
                            0x043C...0x043D => 'm',
                            0x043E...0x043F => 'o',
                            0x0440...0x0441 => 'p',
                            0x0442...0x0443 => 't',
                            0x0444...0x0445 => 'f',
                            0x0446...0x0447 => 'ts',
                            0x0448...0x0449 => 'sh',
                            0x044A...0x044B => 'y',
                            0x044C...0x044D => 'e',
                            0x044E...0x044F => 'yu',
                            else => ' ',
                        };
                        if (latin != ' ') {
                            for (latin) |l| {
                                sanitized[sanitized_len] = l;
                                sanitized_len += 1;
                            }
                            in_word = true;
                            word_start = false;
                        }
                        continue;
                    }

                    // Handle spaces and special characters
                    if (c == ' ' or c == '-' or c == '_') {
                        if (in_word) {
                            sanitized[sanitized_len] = ' ';
                            sanitized_len += 1;
                            in_word = false;
                            word_start = true;
                        }
                        continue;
                    }

                    // Convert to lowercase for non-Russian characters
                    if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9')) {
                        var char_to_add = if (word_start and c >= 'A' and c <= 'Z') c + 32 else c;
                        if (word_start and char_to_add >= '0' and char_to_add <= '9') continue;
                        sanitized[sanitized_len] = char_to_add;
                        sanitized_len += 1;
                        in_word = true;
                        word_start = false;
                    }
                }
            },
            .english, .unknown => {
                // Original English sanitization logic
                for (name) |c| {
                    // Skip invalid characters
                    if (std.mem.indexOfScalar(u8, "<>:\"/\\|?*", c) != null) continue;

                    // Handle spaces and special characters
                    if (c == ' ' or c == '-' or c == '_') {
                        // Skip consecutive spaces/special chars
                        if (prev_char != null and (prev_char.? == ' ' or prev_char.? == '-' or prev_char.? == '_')) continue;
                        
                        // Only add space if we're in a word
                        if (in_word) {
                            sanitized[sanitized_len] = ' ';
                            sanitized_len += 1;
                            in_word = false;
                            word_start = true;
                        }
                        prev_char = c;
                        continue;
                    }

                    // Handle alphanumeric characters
                    if ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')) {
                        // Convert to lowercase if it's the start of a word
                        var char_to_add = if (word_start and c >= 'A' and c <= 'Z') c + 32 else c;
                        
                        // Skip leading numbers
                        if (word_start and char_to_add >= '0' and char_to_add <= '9') continue;
                        
                        sanitized[sanitized_len] = char_to_add;
                        sanitized_len += 1;
                        in_word = true;
                        word_start = false;
                        prev_char = c;
                    }
                }
            },
        }

        // Trim trailing spaces
        while (sanitized_len > 0 and sanitized[sanitized_len - 1] == ' ') {
            sanitized_len -= 1;
        }

        // Ensure minimum length by adding a suffix if needed
        if (sanitized_len < 3) {
            const suffix = "preset";
            const needed = 3 - sanitized_len;
            for (suffix[0..needed]) |c| {
                sanitized[sanitized_len] = c;
                sanitized_len += 1;
            }
        }

        // Ensure maximum length
        if (sanitized_len > 64) {
            sanitized_len = 64;
        }

        // Create final sanitized name
        const final_name = try self.allocator.dupe(u8, sanitized[0..sanitized_len]);
        self.allocator.free(sanitized);
        self.sanitized_name = final_name;
        return final_name;
    }
}; 