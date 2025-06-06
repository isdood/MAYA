const std = @import("std");
const vk = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const PerformanceMetrics = struct {
    const Self = @This();

    // Vulkan query pools
    timestamp_query_pool: vk.VkQueryPool,
    pipeline_stats_query_pool: vk.VkQueryPool,
    
    // Query results
    frame_timestamps: [2]u64,
    pipeline_stats: vk.VkPipelineStatistics,
    
    // Performance data
    gpu_time: f32,
    cpu_time: f32,
    
    // Pipeline statistics
    vertex_shader_invocations: u64,
    fragment_shader_invocations: u64,
    geometry_shader_invocations: u64,
    tessellation_control_shader_patches: u64,
    tessellation_evaluation_shader_invocations: u64,
    compute_shader_invocations: u64,
    input_assembly_primitives: u64,
    vertex_shader_primitives: u64,
    geometry_shader_primitives: u64,
    clipping_primitives: u64,
    clipping_input_primitives: u64,
    clipping_output_primitives: u64,
    
    // Shader timing
    vertex_shader_time: f32,
    fragment_shader_time: f32,
    geometry_shader_time: f32,
    compute_shader_time: f32,
    
    // Pipeline state
    active_pipelines: u32,
    pipeline_cache_size: u64,
    pipeline_cache_hits: u32,
    pipeline_cache_misses: u32,
    
    // Command buffer stats
    command_buffer_count: u32,
    active_command_buffers: u32,
    secondary_command_buffers: u32,
    
    // Device properties
    device_properties: vk.VkPhysicalDeviceProperties,
    device_memory_properties: vk.VkPhysicalDeviceMemoryProperties,
    
    // Memory tracking
    total_device_memory: u64,
    used_device_memory: u64,
    total_host_memory: u64,
    used_host_memory: u64,
    
    logger: std.log.Logger,
    allocator: std.mem.Allocator,

    pub fn init(device: vk.VkDevice, physical_device: vk.VkPhysicalDevice, allocator: std.mem.Allocator) !*Self {
        var self = try allocator.create(Self);
        self.* = Self{
            .timestamp_query_pool = undefined,
            .pipeline_stats_query_pool = undefined,
            .frame_timestamps = [_]u64{0} ** 2,
            .pipeline_stats = undefined,
            .gpu_time = 0,
            .cpu_time = 0,
            .vertex_shader_invocations = 0,
            .fragment_shader_invocations = 0,
            .geometry_shader_invocations = 0,
            .tessellation_control_shader_patches = 0,
            .tessellation_evaluation_shader_invocations = 0,
            .compute_shader_invocations = 0,
            .input_assembly_primitives = 0,
            .vertex_shader_primitives = 0,
            .geometry_shader_primitives = 0,
            .clipping_primitives = 0,
            .clipping_input_primitives = 0,
            .clipping_output_primitives = 0,
            .vertex_shader_time = 0,
            .fragment_shader_time = 0,
            .geometry_shader_time = 0,
            .compute_shader_time = 0,
            .active_pipelines = 0,
            .pipeline_cache_size = 0,
            .pipeline_cache_hits = 0,
            .pipeline_cache_misses = 0,
            .command_buffer_count = 0,
            .active_command_buffers = 0,
            .secondary_command_buffers = 0,
            .device_properties = undefined,
            .device_memory_properties = undefined,
            .total_device_memory = 0,
            .used_device_memory = 0,
            .total_host_memory = 0,
            .used_host_memory = 0,
            .logger = std.log.scoped(.performance_metrics),
            .allocator = allocator,
        };

        // Get device properties
        vk.vkGetPhysicalDeviceProperties(physical_device, &self.device_properties);
        vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &self.device_memory_properties);

        // Create timestamp query pool
        const timestamp_query_pool_info = vk.VkQueryPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO,
            .queryType = vk.VK_QUERY_TYPE_TIMESTAMP,
            .queryCount = 2,
            .pNext = null,
            .flags = 0,
            .pipelineStatistics = 0,
        };

        if (vk.vkCreateQueryPool(device, &timestamp_query_pool_info, null, &self.timestamp_query_pool) != vk.VK_SUCCESS) {
            return error.QueryPoolCreationFailed;
        }

        // Create pipeline statistics query pool with all available statistics
        const pipeline_stats_query_pool_info = vk.VkQueryPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO,
            .queryType = vk.VK_QUERY_TYPE_PIPELINE_STATISTICS,
            .queryCount = 1,
            .pNext = null,
            .flags = 0,
            .pipelineStatistics = vk.VK_QUERY_PIPELINE_STATISTIC_VERTEX_SHADER_INVOCATIONS_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_FRAGMENT_SHADER_INVOCATIONS_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_INVOCATIONS_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_CONTROL_SHADER_PATCHES_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_TESSELLATION_EVALUATION_SHADER_INVOCATIONS_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_COMPUTE_SHADER_INVOCATIONS_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_INPUT_ASSEMBLY_PRIMITIVES_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_VERTEX_SHADER_PRIMITIVES_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_GEOMETRY_SHADER_PRIMITIVES_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_CLIPPING_PRIMITIVES_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_CLIPPING_INPUT_PRIMITIVES_BIT |
                vk.VK_QUERY_PIPELINE_STATISTIC_CLIPPING_OUTPUT_PRIMITIVES_BIT,
        };

        if (vk.vkCreateQueryPool(device, &pipeline_stats_query_pool_info, null, &self.pipeline_stats_query_pool) != vk.VK_SUCCESS) {
            return error.QueryPoolCreationFailed;
        }

        // Calculate total device memory
        for (0..self.device_memory_properties.memoryHeapCount) |i| {
            const heap = self.device_memory_properties.memoryHeaps[i];
            if (heap.flags & vk.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT != 0) {
                self.total_device_memory += heap.size;
            } else {
                self.total_host_memory += heap.size;
            }
        }

        self.logger.info("Performance metrics initialized", .{});
        return self;
    }

    pub fn deinit(self: *Self, device: vk.VkDevice) void {
        vk.vkDestroyQueryPool(device, self.timestamp_query_pool, null);
        vk.vkDestroyQueryPool(device, self.pipeline_stats_query_pool, null);
        self.allocator.destroy(self);
    }

    pub fn beginFrame(self: *Self, device: vk.VkDevice, command_buffer: vk.VkCommandBuffer) void {
        // Reset query pools
        vk.vkCmdResetQueryPool(command_buffer, self.timestamp_query_pool, 0, 2);
        vk.vkCmdResetQueryPool(command_buffer, self.pipeline_stats_query_pool, 0, 1);

        // Write timestamp at start of frame
        vk.vkCmdWriteTimestamp(
            command_buffer,
            vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
            self.timestamp_query_pool,
            0
        );

        // Begin pipeline statistics query
        vk.vkCmdBeginQuery(command_buffer, self.pipeline_stats_query_pool, 0, 0);
    }

    pub fn endFrame(self: *Self, device: vk.VkDevice, command_buffer: vk.VkCommandBuffer) void {
        // Write timestamp at end of frame
        vk.vkCmdWriteTimestamp(
            command_buffer,
            vk.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
            self.timestamp_query_pool,
            1
        );

        // End pipeline statistics query
        vk.vkCmdEndQuery(command_buffer, self.pipeline_stats_query_pool, 0);
    }

    pub fn updateMetrics(self: *Self, device: vk.VkDevice) !void {
        // Get timestamp results
        var timestamps: [2]u64 = undefined;
        if (vk.vkGetQueryPoolResults(
            device,
            self.timestamp_query_pool,
            0,
            2,
            @sizeOf(u64) * 2,
            &timestamps,
            @sizeOf(u64),
            vk.VK_QUERY_RESULT_64_BIT
        ) != vk.VK_SUCCESS) {
            return error.QueryResultsFailed;
        }

        // Calculate GPU time
        const timestamp_period = self.device_properties.limits.timestampPeriod;
        self.gpu_time = @intToFloat(f32, timestamps[1] - timestamps[0]) * timestamp_period / 1_000_000.0;

        // Get pipeline statistics
        var pipeline_stats: vk.VkPipelineStatistics = undefined;
        if (vk.vkGetQueryPoolResults(
            device,
            self.pipeline_stats_query_pool,
            0,
            1,
            @sizeOf(vk.VkPipelineStatistics),
            &pipeline_stats,
            @sizeOf(vk.VkPipelineStatistics),
            vk.VK_QUERY_RESULT_64_BIT
        ) != vk.VK_SUCCESS) {
            return error.QueryResultsFailed;
        }

        // Update pipeline statistics
        self.vertex_shader_invocations = pipeline_stats.vertexShaderInvocations;
        self.fragment_shader_invocations = pipeline_stats.fragmentShaderInvocations;
        self.geometry_shader_invocations = pipeline_stats.geometryShaderInvocations;
        self.tessellation_control_shader_patches = pipeline_stats.tessellationControlShaderPatches;
        self.tessellation_evaluation_shader_invocations = pipeline_stats.tessellationEvaluationShaderInvocations;
        self.compute_shader_invocations = pipeline_stats.computeShaderInvocations;
        self.input_assembly_primitives = pipeline_stats.inputAssemblyPrimitives;
        self.vertex_shader_primitives = pipeline_stats.vertexShaderPrimitives;
        self.geometry_shader_primitives = pipeline_stats.geometryShaderPrimitives;
        self.clipping_primitives = pipeline_stats.clippingPrimitives;
        self.clipping_input_primitives = pipeline_stats.clippingInputPrimitives;
        self.clipping_output_primitives = pipeline_stats.clippingOutputPrimitives;

        // Update memory usage
        self.updateMemoryUsage(device);
    }

    fn updateMemoryUsage(self: *Self, device: vk.VkDevice) void {
        var memory_count: u32 = undefined;
        _ = vk.vkGetPhysicalDeviceMemoryProperties(self.device_properties.physicalDevice, &self.device_memory_properties);

        // Calculate used memory
        self.used_device_memory = 0;
        self.used_host_memory = 0;

        for (0..self.device_memory_properties.memoryHeapCount) |i| {
            const heap = self.device_memory_properties.memoryHeaps[i];
            var heap_info = vk.VkMemoryHeapInfoEXT{
                .sType = vk.VK_STRUCTURE_TYPE_MEMORY_HEAP_INFO_EXT,
                .pNext = null,
                .heapIndex = @intCast(u32, i),
            };

            var heap_usage: vk.VkMemoryHeapUsageEXT = undefined;
            if (vk.vkGetMemoryHeapUsageEXT(device, &heap_info, &heap_usage) == vk.VK_SUCCESS) {
                if (heap.flags & vk.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT != 0) {
                    self.used_device_memory += heap_usage.used;
                } else {
                    self.used_host_memory += heap_usage.used;
                }
            }
        }
    }

    pub fn getMetrics(self: *Self) struct {
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
    } {
        return .{
            .fps = 1000.0 / self.gpu_time,
            .frame_time = self.gpu_time,
            .gpu_usage = (self.gpu_time / 16.67) * 100.0, // Assuming 60 FPS target
            .vram_usage = @intToFloat(f32, self.used_device_memory) / @intToFloat(f32, self.total_device_memory) * 100.0,
            .cpu_usage = self.cpu_time / 16.67 * 100.0, // Assuming 60 FPS target
            .memory_usage = @intToFloat(f32, self.used_host_memory) / @intToFloat(f32, self.total_host_memory) * 100.0,
            .shader_metrics = .{
                .vertex_shader_invocations = self.vertex_shader_invocations,
                .fragment_shader_invocations = self.fragment_shader_invocations,
                .geometry_shader_invocations = self.geometry_shader_invocations,
                .tessellation_control_shader_patches = self.tessellation_control_shader_patches,
                .tessellation_evaluation_shader_invocations = self.tessellation_evaluation_shader_invocations,
                .compute_shader_invocations = self.compute_shader_invocations,
            },
            .primitive_metrics = .{
                .input_assembly_primitives = self.input_assembly_primitives,
                .vertex_shader_primitives = self.vertex_shader_primitives,
                .geometry_shader_primitives = self.geometry_shader_primitives,
                .clipping_primitives = self.clipping_primitives,
                .clipping_input_primitives = self.clipping_input_primitives,
                .clipping_output_primitives = self.clipping_output_primitives,
            },
            .pipeline_metrics = .{
                .active_pipelines = self.active_pipelines,
                .pipeline_cache_size = self.pipeline_cache_size,
                .pipeline_cache_hits = self.pipeline_cache_hits,
                .pipeline_cache_misses = self.pipeline_cache_misses,
            },
            .command_buffer_metrics = .{
                .total_command_buffers = self.command_buffer_count,
                .active_command_buffers = self.active_command_buffers,
                .secondary_command_buffers = self.secondary_command_buffers,
            },
        };
    }
}; 