@pattern_meta@
GLIMMER Pattern:
{
  "metadata": {
    "timestamp": "2025-06-07 00:20:33",
    "author": "isdood",
    "pattern_version": "1.0.0",
    "color": "#FF69B4"
  },
  "file_info": {
    "path": "./src/ui/settings_panel.zig",
    "type": "zig",
    "hash": "674aa9188da2aabb8588165b252bca864f93b182"
  }
}
@pattern_meta@

const std = @import("std");
const c = @import("c.zig");
const PerformancePreset = @import("performance_preset.zig").PerformancePreset;

pub const Self = struct {
    allocator: std.mem.Allocator,
    show_panel: bool = false,
    show_create_preset_dialog: bool = false,
    available_profiles: std.ArrayList(PerformancePreset),
    current_profile: PerformancePreset,
    new_preset_base: ?PerformancePreset = null,
    new_preset_name: [64]u8 = undefined,
    new_preset_name_len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var profiles = std.ArrayList(PerformancePreset).init(allocator);
        try profiles.append(PerformancePreset{
            .id = 0,
            .name = try allocator.dupe(u8, "Default"),
            .settings = PerformancePreset.Settings{
                .msaa_level = 2,
                .texture_quality = 2,
                .shadow_quality = 2,
                .anisotropic_filtering = 4,
                .view_distance = 2,
                .max_fps = 60,
                .vsync = true,
                .triple_buffering = true,
                .shader_quality = 2,
                .compute_shader_quality = 2,
                .texture_streaming = true,
                .texture_cache_size = 1024,
                .geometry_lod_levels = 3,
                .pipeline_cache_size = 64,
                .command_buffer_reuse = true,
                .secondary_command_buffers = true,
                .async_compute = true,
                .geometry_shaders = true,
                .tessellation = true,
                .ray_tracing = false,
            },
        });

        return Self{
            .allocator = allocator,
            .available_profiles = profiles,
            .current_profile = profiles.items[0],
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.available_profiles.items) |profile| {
            self.allocator.free(profile.name);
        }
        self.available_profiles.deinit();
    }

    pub fn render(self: *Self) void {
        if (!self.show_panel) return;

        if (c.igBegin("Performance Settings", &self.show_panel, c.ImGuiWindowFlags_None)) {
            // Profile Management Section
            if (c.igCollapsingHeader("Performance Profiles", c.ImGuiTreeNodeFlags_DefaultOpen)) {
                // Profile Selection
                if (c.igBeginCombo("##profile_select", self.current_profile.name.ptr)) {
                    for (self.available_profiles.items) |profile| {
                        const is_selected = profile.id == self.current_profile.id;
                        if (c.igSelectable(profile.name.ptr, is_selected, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                            self.current_profile = profile;
                        }
                        if (is_selected) {
                            c.igSetItemDefaultFocus();
                        }
                    }
                    c.igEndCombo();
                }

                // Profile Management Buttons
                c.igSameLine(0, 20);
                if (c.igButton("Create New", .{ .x = 100, .y = 0 })) {
                    self.show_create_preset_dialog = true;
                }
                c.igSameLine(0, 10);
                if (c.igButton("Delete", .{ .x = 100, .y = 0 })) {
                    // Delete current profile
                    if (self.current_profile.id != 0) { // Don't delete default profile
                        // TODO: Implement profile deletion
                    }
                }
            }

            // Current Profile Settings
            if (c.igCollapsingHeader("Current Profile Settings", c.ImGuiTreeNodeFlags_DefaultOpen)) {
                // Helper functions for color coding
                const getQualityColor = fn (quality: u32) c.ImVec4;
                const getQualityColorImpl = getQualityColor{
                    .quality = quality,
                    .return = switch (quality) {
                        0 => .{ .x = 0.4, .y = 0.4, .z = 0.4, .w = 1.0 }, // Disabled
                        1 => .{ .x = 0.8, .y = 0.2, .z = 0.2, .w = 1.0 }, // Low
                        2 => .{ .x = 0.8, .y = 0.8, .z = 0.2, .w = 1.0 }, // Medium
                        3 => .{ .x = 0.2, .y = 0.8, .z = 0.2, .w = 1.0 }, // High
                        4 => .{ .x = 0.2, .y = 0.2, .z = 0.8, .w = 1.0 }, // Ultra
                        else => .{ .x = 0.8, .y = 0.4, .z = 0.8, .w = 1.0 }, // Advanced
                    },
                };

                // Render settings in a table format
                if (c.igBeginTable("##settings_table", 2, c.ImGuiTableFlags_Borders | c.ImGuiTableFlags_RowBg, .{ .x = 0, .y = 0 }, 0)) {
                    // MSAA Level
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("MSAA Level");
                    c.igTableNextColumn();
                    const msaa_color = getQualityColorImpl(self.current_profile.settings.msaa_level);
                    c.igTextColored(msaa_color, "%d", self.current_profile.settings.msaa_level);

                    // Texture Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Texture Quality");
                    c.igTableNextColumn();
                    const texture_color = getQualityColorImpl(self.current_profile.settings.texture_quality);
                    c.igTextColored(texture_color, "%d", self.current_profile.settings.texture_quality);

                    // Shadow Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Shadow Quality");
                    c.igTableNextColumn();
                    const shadow_color = getQualityColorImpl(self.current_profile.settings.shadow_quality);
                    c.igTextColored(shadow_color, "%d", self.current_profile.settings.shadow_quality);

                    // Anisotropic Filtering
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Anisotropic Filtering");
                    c.igTableNextColumn();
                    const af_color = getQualityColorImpl(self.current_profile.settings.anisotropic_filtering);
                    c.igTextColored(af_color, "%d", self.current_profile.settings.anisotropic_filtering);

                    // View Distance
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("View Distance");
                    c.igTableNextColumn();
                    const view_color = getQualityColorImpl(self.current_profile.settings.view_distance);
                    c.igTextColored(view_color, "%d", self.current_profile.settings.view_distance);

                    // Max FPS
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Max FPS");
                    c.igTableNextColumn();
                    c.igText("%d", self.current_profile.settings.max_fps);

                    // V-Sync
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("V-Sync");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.vsync) "Enabled" else "Disabled");

                    // Triple Buffering
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Triple Buffering");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.triple_buffering) "Enabled" else "Disabled");

                    // Shader Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Shader Quality");
                    c.igTableNextColumn();
                    const shader_color = getQualityColorImpl(self.current_profile.settings.shader_quality);
                    c.igTextColored(shader_color, "%d", self.current_profile.settings.shader_quality);

                    // Compute Shader Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Compute Shader Quality");
                    c.igTableNextColumn();
                    const compute_color = getQualityColorImpl(self.current_profile.settings.compute_shader_quality);
                    c.igTextColored(compute_color, "%d", self.current_profile.settings.compute_shader_quality);

                    // Texture Streaming
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Texture Streaming");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.texture_streaming) "Enabled" else "Disabled");

                    // Texture Cache Size
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Texture Cache Size (MB)");
                    c.igTableNextColumn();
                    c.igText("%d", self.current_profile.settings.texture_cache_size);

                    // Geometry LOD Levels
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Geometry LOD Levels");
                    c.igTableNextColumn();
                    const lod_color = getQualityColorImpl(self.current_profile.settings.geometry_lod_levels);
                    c.igTextColored(lod_color, "%d", self.current_profile.settings.geometry_lod_levels);

                    // Pipeline Cache Size
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Pipeline Cache Size (MB)");
                    c.igTableNextColumn();
                    c.igText("%d", self.current_profile.settings.pipeline_cache_size);

                    // Feature Toggles
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Command Buffer Reuse");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.command_buffer_reuse) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Secondary Command Buffers");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.secondary_command_buffers) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Async Compute");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.async_compute) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Geometry Shaders");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.geometry_shaders) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Tessellation");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.tessellation) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Ray Tracing");
                    c.igTableNextColumn();
                    c.igText(if (self.current_profile.settings.ray_tracing) "Enabled" else "Disabled");
                }
                c.igEndTable();
            }

            // Performance Impact Legend
            if (c.igCollapsingHeader("Performance Impact Guide", c.ImGuiTreeNodeFlags_None)) {
                // Compact legend button
                c.igSameLine(c.igGetWindowWidth() - 30, 0);
                if (c.igButton("ℹ️", .{ .x = 25, .y = 25 })) {
                    // Button is just for show, actual info is in tooltip
                }
                if (c.igIsItemHovered(c.ImGuiHoveredFlags_None)) {
                    c.igBeginTooltip();
                    c.igPushTextWrapPos(c.igGetFontSize() * 35.0);
                    
                    // Quality Levels
                    c.igText("Quality Levels:");
                    c.igTextColored(.{ .x = 0.8, .y = 0.2, .z = 0.2, .w = 1.0 }, "● Low");
                    c.igTextColored(.{ .x = 0.8, .y = 0.8, .z = 0.2, .w = 1.0 }, "● Medium");
                    c.igTextColored(.{ .x = 0.2, .y = 0.8, .z = 0.2, .w = 1.0 }, "● High");
                    c.igTextColored(.{ .x = 0.2, .y = 0.2, .z = 0.8, .w = 1.0 }, "● Ultra");
                    c.igTextColored(.{ .x = 0.8, .y = 0.4, .z = 0.8, .w = 1.0 }, "● Advanced");
                    c.igTextColored(.{ .x = 0.4, .y = 0.4, .z = 0.4, .w = 1.0 }, "● Disabled");
                    
                    c.igSpacing();
                    c.igSeparator();
                    c.igSpacing();
                    
                    // Performance Impact
                    c.igText("Performance Impact:");
                    c.igTextColored(.{ .x = 0.2, .y = 0.6, .z = 0.8, .w = 1.0 }, "💻 CPU");
                    c.igTextColored(.{ .x = 0.8, .y = 0.4, .z = 0.2, .w = 1.0 }, "🎮 GPU");
                    c.igTextColored(.{ .x = 0.6, .y = 0.4, .z = 0.8, .w = 1.0 }, "💾 Memory");
                    c.igText("Impact levels: 1-5 (higher = more impact)");
                    c.igTextColored(.{ .x = 0.7, .y = 0.7, .z = 0.7, .w = 1.0 }, "● Normal impact");
                    c.igTextColored(.{ .x = 1.0, .y = 0.4, .z = 0.4, .w = 1.0 }, "● High impact");
                    
                    c.igSpacing();
                    c.igSeparator();
                    c.igSpacing();
                    
                    // Tips
                    c.igText("Tips:");
                    c.igBulletText("Hover over settings for detailed information");
                    c.igBulletText("Hover over impact icons for specific impact levels");
                    c.igBulletText("Red indicators show high performance impact");
                    
                    c.igPopTextWrapPos();
                    c.igEndTooltip();
                }
            }
        }
        c.igEnd();

        // Create Preset Dialog
        if (self.show_create_preset_dialog) {
            self.renderCreatePresetDialog();
        }
    }

    fn renderCreatePresetDialog(self: *Self) void {
        if (c.igBegin("Create New Profile", &self.show_create_preset_dialog, c.ImGuiWindowFlags_AlwaysAutoResize)) {
            // Profile Name Input
            c.igText("Profile Name:");
            c.igSameLine(0, 10);
            if (c.igInputText("##profile_name", &self.new_preset_name, self.new_preset_name.len, c.ImGuiInputTextFlags_None, null, null)) {
                self.new_preset_name_len = std.mem.len(&self.new_preset_name);
            }

            // Base Profile Selection
            c.igText("Base Profile:");
            c.igSameLine(0, 10);
            if (c.igBeginCombo("##base_profile", if (self.new_preset_base) |base| base.name.ptr else "None")) {
                for (self.available_profiles.items) |profile| {
                    const is_selected = if (self.new_preset_base) |base| base.id == profile.id else false;
                    if (c.igSelectable(profile.name.ptr, is_selected, c.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                        self.new_preset_base = profile;
                    }
                    if (is_selected) {
                        c.igSetItemDefaultFocus();
                    }
                }
                c.igEndCombo();
            }

            // Settings Preview Panel
            c.igSpacing();
            c.igSeparator();
            c.igSpacing();

            c.igText("Settings Preview");
            if (c.igBeginChild("##settings_preview", .{ .x = 400, .y = 300 }, c.ImGuiChildFlags_Border, c.ImGuiWindowFlags_None)) {
                const settings = if (self.new_preset_base) |base| base.settings else PerformancePreset.Settings{
                    .msaa_level = 2,
                    .texture_quality = 2,
                    .shadow_quality = 2,
                    .anisotropic_filtering = 4,
                    .view_distance = 2,
                    .max_fps = 60,
                    .vsync = true,
                    .triple_buffering = true,
                    .shader_quality = 2,
                    .compute_shader_quality = 2,
                    .texture_streaming = true,
                    .texture_cache_size = 1024,
                    .geometry_lod_levels = 3,
                    .pipeline_cache_size = 64,
                    .command_buffer_reuse = true,
                    .secondary_command_buffers = true,
                    .async_compute = true,
                    .geometry_shaders = true,
                    .tessellation = true,
                    .ray_tracing = false,
                };

                // Helper functions for color coding
                const getQualityColor = fn (quality: u32) c.ImVec4;
                const getQualityColorImpl = getQualityColor{
                    .quality = quality,
                    .return = switch (quality) {
                        0 => .{ .x = 0.4, .y = 0.4, .z = 0.4, .w = 1.0 }, // Disabled
                        1 => .{ .x = 0.8, .y = 0.2, .z = 0.2, .w = 1.0 }, // Low
                        2 => .{ .x = 0.8, .y = 0.8, .z = 0.2, .w = 1.0 }, // Medium
                        3 => .{ .x = 0.2, .y = 0.8, .z = 0.2, .w = 1.0 }, // High
                        4 => .{ .x = 0.2, .y = 0.2, .z = 0.8, .w = 1.0 }, // Ultra
                        else => .{ .x = 0.8, .y = 0.4, .z = 0.8, .w = 1.0 }, // Advanced
                    },
                };

                // Render settings in a table format
                if (c.igBeginTable("##settings_table", 2, c.ImGuiTableFlags_Borders | c.ImGuiTableFlags_RowBg, .{ .x = 0, .y = 0 }, 0)) {
                    // MSAA Level
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("MSAA Level");
                    c.igTableNextColumn();
                    const msaa_color = getQualityColorImpl(settings.msaa_level);
                    c.igTextColored(msaa_color, "%d", settings.msaa_level);

                    // Texture Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Texture Quality");
                    c.igTableNextColumn();
                    const texture_color = getQualityColorImpl(settings.texture_quality);
                    c.igTextColored(texture_color, "%d", settings.texture_quality);

                    // Shadow Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Shadow Quality");
                    c.igTableNextColumn();
                    const shadow_color = getQualityColorImpl(settings.shadow_quality);
                    c.igTextColored(shadow_color, "%d", settings.shadow_quality);

                    // Anisotropic Filtering
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Anisotropic Filtering");
                    c.igTableNextColumn();
                    const af_color = getQualityColorImpl(settings.anisotropic_filtering);
                    c.igTextColored(af_color, "%d", settings.anisotropic_filtering);

                    // View Distance
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("View Distance");
                    c.igTableNextColumn();
                    const view_color = getQualityColorImpl(settings.view_distance);
                    c.igTextColored(view_color, "%d", settings.view_distance);

                    // Max FPS
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Max FPS");
                    c.igTableNextColumn();
                    c.igText("%d", settings.max_fps);

                    // V-Sync
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("V-Sync");
                    c.igTableNextColumn();
                    c.igText(if (settings.vsync) "Enabled" else "Disabled");

                    // Triple Buffering
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Triple Buffering");
                    c.igTableNextColumn();
                    c.igText(if (settings.triple_buffering) "Enabled" else "Disabled");

                    // Shader Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Shader Quality");
                    c.igTableNextColumn();
                    const shader_color = getQualityColorImpl(settings.shader_quality);
                    c.igTextColored(shader_color, "%d", settings.shader_quality);

                    // Compute Shader Quality
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Compute Shader Quality");
                    c.igTableNextColumn();
                    const compute_color = getQualityColorImpl(settings.compute_shader_quality);
                    c.igTextColored(compute_color, "%d", settings.compute_shader_quality);

                    // Texture Streaming
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Texture Streaming");
                    c.igTableNextColumn();
                    c.igText(if (settings.texture_streaming) "Enabled" else "Disabled");

                    // Texture Cache Size
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Texture Cache Size (MB)");
                    c.igTableNextColumn();
                    c.igText("%d", settings.texture_cache_size);

                    // Geometry LOD Levels
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Geometry LOD Levels");
                    c.igTableNextColumn();
                    const lod_color = getQualityColorImpl(settings.geometry_lod_levels);
                    c.igTextColored(lod_color, "%d", settings.geometry_lod_levels);

                    // Pipeline Cache Size
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Pipeline Cache Size (MB)");
                    c.igTableNextColumn();
                    c.igText("%d", settings.pipeline_cache_size);

                    // Feature Toggles
                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Command Buffer Reuse");
                    c.igTableNextColumn();
                    c.igText(if (settings.command_buffer_reuse) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Secondary Command Buffers");
                    c.igTableNextColumn();
                    c.igText(if (settings.secondary_command_buffers) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Async Compute");
                    c.igTableNextColumn();
                    c.igText(if (settings.async_compute) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Geometry Shaders");
                    c.igTableNextColumn();
                    c.igText(if (settings.geometry_shaders) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Tessellation");
                    c.igTableNextColumn();
                    c.igText(if (settings.tessellation) "Enabled" else "Disabled");

                    c.igTableNextRow(c.ImGuiTableRowFlags_None, 0);
                    c.igTableNextColumn();
                    c.igText("Ray Tracing");
                    c.igTableNextColumn();
                    c.igText(if (settings.ray_tracing) "Enabled" else "Disabled");
                }
                c.igEndChild();
            }

            // Action Buttons
            c.igSpacing();
            c.igSeparator();
            c.igSpacing();

            if (c.igButton("Create", .{ .x = 120, .y = 0 })) {
                // TODO: Implement profile creation
                self.show_create_preset_dialog = false;
            }
            c.igSameLine(0, 10);
            if (c.igButton("Cancel", .{ .x = 120, .y = 0 })) {
                self.show_create_preset_dialog = false;
            }
        }
        c.igEnd();
    }
}; 