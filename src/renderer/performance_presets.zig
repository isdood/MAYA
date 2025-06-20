
const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const PerformancePreset = struct {
    const Self = @This();

    name: []const u8,
    description: []const u8,
    settings: Settings,
    is_custom: bool,
    last_modified: i64,

    pub const Settings = struct {
        // Quality settings
        msaa_level: u32,
        texture_quality: TextureQuality,
        shadow_quality: ShadowQuality,
        anisotropic_filtering: u32,
        view_distance: f32,
        
        // Performance settings
        max_fps: u32,
        vsync: bool,
        triple_buffering: bool,
        
        // Shader settings
        shader_quality: ShaderQuality,
        compute_shader_quality: ComputeShaderQuality,
        
        // Memory settings
        texture_streaming: bool,
        texture_cache_size: u64,
        geometry_lod_levels: u32,
        
        // Pipeline settings
        pipeline_cache_size: u64,
        command_buffer_reuse: bool,
        secondary_command_buffers: bool,
        
        // Advanced settings
        async_compute: bool,
        geometry_shaders: bool,
        tessellation: bool,
        ray_tracing: bool,
    };

    pub const TextureQuality = enum {
        low,
        medium,
        high,
        ultra,
    };

    pub const ShadowQuality = enum {
        low,
        medium,
        high,
        ultra,
    };

    pub const ShaderQuality = enum {
        low,
        medium,
        high,
        ultra,
    };

    pub const ComputeShaderQuality = enum {
        disabled,
        basic,
        advanced,
        full,
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, description: []const u8, settings: Settings) !*Self {
        var self = try allocator.create(Self);
        self.* = Self{
            .name = try allocator.dupe(u8, name),
            .description = try allocator.dupe(u8, description),
            .settings = settings,
            .is_custom = false,
            .last_modified = std.time.timestamp(),
        };
        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.destroy(self);
    }

    pub fn createDefaultPresets(allocator: std.mem.Allocator) ![]*Self {
        var presets = std.ArrayList(*Self).init(allocator);

        // Performance preset
        try presets.append(try Self.init(allocator, "Performance", "Maximum performance, minimal quality", .{
            .msaa_level = 0,
            .texture_quality = .low,
            .shadow_quality = .low,
            .anisotropic_filtering = 0,
            .view_distance = 100.0,
            .max_fps = 0, // Unlimited
            .vsync = false,
            .triple_buffering = false,
            .shader_quality = .low,
            .compute_shader_quality = .basic,
            .texture_streaming = true,
            .texture_cache_size = 256 * 1024 * 1024, // 256 MB
            .geometry_lod_levels = 2,
            .pipeline_cache_size = 64 * 1024 * 1024, // 64 MB
            .command_buffer_reuse = true,
            .secondary_command_buffers = false,
            .async_compute = false,
            .geometry_shaders = false,
            .tessellation = false,
            .ray_tracing = false,
        }));

        // Balanced preset
        try presets.append(try Self.init(allocator, "Balanced", "Balanced performance and quality", .{
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
            .texture_cache_size = 512 * 1024 * 1024, // 512 MB
            .geometry_lod_levels = 3,
            .pipeline_cache_size = 128 * 1024 * 1024, // 128 MB
            .command_buffer_reuse = true,
            .secondary_command_buffers = true,
            .async_compute = true,
            .geometry_shaders = true,
            .tessellation = false,
            .ray_tracing = false,
        }));

        // Quality preset
        try presets.append(try Self.init(allocator, "Quality", "Maximum quality, balanced performance", .{
            .msaa_level = 4,
            .texture_quality = .high,
            .shadow_quality = .high,
            .anisotropic_filtering = 16,
            .view_distance = 1000.0,
            .max_fps = 30,
            .vsync = true,
            .triple_buffering = true,
            .shader_quality = .high,
            .compute_shader_quality = .full,
            .texture_streaming = false,
            .texture_cache_size = 1024 * 1024 * 1024, // 1 GB
            .geometry_lod_levels = 4,
            .pipeline_cache_size = 256 * 1024 * 1024, // 256 MB
            .command_buffer_reuse = true,
            .secondary_command_buffers = true,
            .async_compute = true,
            .geometry_shaders = true,
            .tessellation = true,
            .ray_tracing = true,
        }));

        return presets.toOwnedSlice();
    }

    pub fn saveToFile(self: *Self, file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        const writer = file.writer();
        try writer.print(
            \\{{
            \\  "name": "{s}",
            \\  "description": "{s}",
            \\  "is_custom": {},
            \\  "last_modified": {},
            \\  "settings": {{
            \\    "msaa_level": {},
            \\    "texture_quality": "{s}",
            \\    "shadow_quality": "{s}",
            \\    "anisotropic_filtering": {},
            \\    "view_distance": {d},
            \\    "max_fps": {},
            \\    "vsync": {},
            \\    "triple_buffering": {},
            \\    "shader_quality": "{s}",
            \\    "compute_shader_quality": "{s}",
            \\    "texture_streaming": {},
            \\    "texture_cache_size": {},
            \\    "geometry_lod_levels": {},
            \\    "pipeline_cache_size": {},
            \\    "command_buffer_reuse": {},
            \\    "secondary_command_buffers": {},
            \\    "async_compute": {},
            \\    "geometry_shaders": {},
            \\    "tessellation": {},
            \\    "ray_tracing": {}
            \\  }}
            \\}}
        , .{
            self.name,
            self.description,
            self.is_custom,
            self.last_modified,
            self.settings.msaa_level,
            @tagName(self.settings.texture_quality),
            @tagName(self.settings.shadow_quality),
            self.settings.anisotropic_filtering,
            self.settings.view_distance,
            self.settings.max_fps,
            self.settings.vsync,
            self.settings.triple_buffering,
            @tagName(self.settings.shader_quality),
            @tagName(self.settings.compute_shader_quality),
            self.settings.texture_streaming,
            self.settings.texture_cache_size,
            self.settings.geometry_lod_levels,
            self.settings.pipeline_cache_size,
            self.settings.command_buffer_reuse,
            self.settings.secondary_command_buffers,
            self.settings.async_compute,
            self.settings.geometry_shaders,
            self.settings.tessellation,
            self.settings.ray_tracing,
        });
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, file_path: []const u8) !*Self {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        var parser = std.json.Parser.init(allocator, false);
        defer parser.deinit();

        var tree = try parser.parse(content);
        defer tree.deinit();

        const root = tree.root.Object;
        const settings = root.get("settings").?.Object;

        return try Self.init(allocator,
            root.get("name").?.String,
            root.get("description").?.String,
            .{
                .msaa_level = @intCast(u32, settings.get("msaa_level").?.Integer),
                .texture_quality = std.meta.stringToEnum(TextureQuality, settings.get("texture_quality").?.String) orelse .medium,
                .shadow_quality = std.meta.stringToEnum(ShadowQuality, settings.get("shadow_quality").?.String) orelse .medium,
                .anisotropic_filtering = @intCast(u32, settings.get("anisotropic_filtering").?.Integer),
                .view_distance = @floatCast(f32, settings.get("view_distance").?.Float),
                .max_fps = @intCast(u32, settings.get("max_fps").?.Integer),
                .vsync = settings.get("vsync").?.Bool,
                .triple_buffering = settings.get("triple_buffering").?.Bool,
                .shader_quality = std.meta.stringToEnum(ShaderQuality, settings.get("shader_quality").?.String) orelse .medium,
                .compute_shader_quality = std.meta.stringToEnum(ComputeShaderQuality, settings.get("compute_shader_quality").?.String) orelse .basic,
                .texture_streaming = settings.get("texture_streaming").?.Bool,
                .texture_cache_size = @intCast(u64, settings.get("texture_cache_size").?.Integer),
                .geometry_lod_levels = @intCast(u32, settings.get("geometry_lod_levels").?.Integer),
                .pipeline_cache_size = @intCast(u64, settings.get("pipeline_cache_size").?.Integer),
                .command_buffer_reuse = settings.get("command_buffer_reuse").?.Bool,
                .secondary_command_buffers = settings.get("secondary_command_buffers").?.Bool,
                .async_compute = settings.get("async_compute").?.Bool,
                .geometry_shaders = settings.get("geometry_shaders").?.Bool,
                .tessellation = settings.get("tessellation").?.Bool,
                .ray_tracing = settings.get("ray_tracing").?.Bool,
            },
        );
    }
}; 
