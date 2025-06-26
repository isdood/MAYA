// src/vulkan/compute/pipeline.zig
const std = @import("std");
const c = @import("../../vk.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const vk = @import("vk");
const c = vk; // For backward compatibility

const Context = @import("context.zig").VulkanContext;

pub const ComputePipeline = struct {
    device: c.VkDevice,
    pipeline: c.VkPipeline,
    pipeline_layout: c.VkPipelineLayout,
    descriptor_set_layout: c.VkDescriptorSetLayout,

    pub fn init(
        device: c.VkDevice,
        shader_code: []const u32,
        descriptor_set_layout_bindings: []const c.VkDescriptorSetLayoutBinding,
    ) !ComputePipeline {
        // Create shader module
        const shader_module = try createShaderModule(device, shader_code);

        // Create descriptor set layout
        const layout_info = c.VkDescriptorSetLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .bindingCount = @intCast(u32, descriptor_set_layout_bindings.len),
            .pBindings = descriptor_set_layout_bindings.ptr,
        };

        var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;
        var result = c.vkCreateDescriptorSetLayout(device, &layout_info, null, &descriptor_set_layout);
        if (result != c.VK_SUCCESS) {
            return error.DescriptorSetLayoutCreationFailed;
        }

        // Create pipeline layout
        const pipeline_layout_info = c.VkPipelineLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .setLayoutCount = 1,
            .pSetLayouts = &descriptor_set_layout,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
        };

        var pipeline_layout: c.VkPipelineLayout = undefined;
        result = c.vkCreatePipelineLayout(device, &pipeline_layout_info, null, &pipeline_layout);
        if (result != c.VK_SUCCESS) {
            c.vkDestroyDescriptorSetLayout(device, descriptor_set_layout, null);
            return error.PipelineLayoutCreationFailed;
        }

        // Create compute pipeline
        const stage_info = c.VkPipelineShaderStageCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .module = shader_module,
            .pName = "main",
            .pSpecializationInfo = null,
        };

        const pipeline_info = c.VkComputePipelineCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = stage_info,
            .layout = pipeline_layout,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        var pipeline: c.VkPipeline = undefined;
        result = c.vkCreateComputePipelines(
            device,
            null,
            1,
            &pipeline_info,
            null,
            &pipeline,
        );

        // Clean up shader module
        c.vkDestroyShaderModule(device, shader_module, null);

        if (result != c.VK_SUCCESS) {
            c.vkDestroyPipelineLayout(device, pipeline_layout, null);
            c.vkDestroyDescriptorSetLayout(device, descriptor_set_layout, null);
            return error.PipelineCreationFailed;
        }

        return ComputePipeline{
            .device = device,
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .descriptor_set_layout = descriptor_set_layout,
        };
    }

    pub fn deinit(self: *ComputePipeline) void {
        c.vkDestroyPipeline(self.device, self.pipeline, null);
        c.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);
        c.vkDestroyDescriptorSetLayout(self.device, self.descriptor_set_layout, null);
    }

    fn createShaderModule(device: c.VkDevice, code: []const u32) !c.VkShaderModule {
        const create_info = c.VkShaderModuleCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .codeSize = code.len * @sizeOf(u32),
            .pCode = code.ptr,
        };

        var shader_module: c.VkShaderModule = undefined;
        const result = c.vkCreateShaderModule(device, &create_info, null, &shader_module);
        if (result != c.VK_SUCCESS) {
            return error.ShaderModuleCreationFailed;
        }

        return shader_module;
    }
};

pub const SpiralConvolutionParams = extern struct {
    input_dims: [4]i32,
    output_dims: [4]i32,
    kernel_size: i32,
    golden_ratio: f32,
    time_scale: f32,
};

pub const VulkanComputePipeline = struct {
    context: *Context,
    pipeline: c.VkPipeline,
    pipeline_layout: c.VkPipelineLayout,
    descriptor_set_layout: c.VkDescriptorSetLayout,
    descriptor_pool: c.VkDescriptorPool,
    descriptor_sets: []c.VkDescriptorSet,
    shader_module: c.VkShaderModule,
    
    pub fn init(context: *Context, shader_code: []const u8) !VulkanComputePipeline {
        var self: VulkanComputePipeline = undefined;
        self.context = context;
        
        // Create shader module
        self.shader_module = try createShaderModule(context, shader_code);
        
        // Create descriptor set layout
        self.descriptor_set_layout = try createDescriptorSetLayout(context);
        
        // Create pipeline layout
        self.pipeline_layout = try createPipelineLayout(context, self.descriptor_set_layout);
        
        // Create compute pipeline
        self.pipeline = try createComputePipeline(context, self.shader_module, self.pipeline_layout);
        
        // Create descriptor pool
        self.descriptor_pool = try createDescriptorPool(context, 1);
        
        // Allocate descriptor sets
        self.descriptor_sets = try allocateDescriptorSets(context, self.descriptor_pool, self.descriptor_set_layout, 1);
        
        return self;
    }
    
    pub fn deinit(self: *VulkanComputePipeline) void {
        const device = self.context.device;
        
        if (self.descriptor_pool != null) {
            c.vkDestroyDescriptorPool(device, self.descriptor_pool, null);
        }
        
        if (self.pipeline != null) {
            c.vkDestroyPipeline(device, self.pipeline, null);
        }
        
        if (self.pipeline_layout != null) {
            c.vkDestroyPipelineLayout(device, self.pipeline_layout, null);
        }
        
        if (self.descriptor_set_layout != null) {
            c.vkDestroyDescriptorSetLayout(device, self.descriptor_set_layout, null);
        }
        
        if (self.shader_module != null) {
            c.vkDestroyShaderModule(device, self.shader_module, null);
        }
    }
    
    pub fn dispatch(
        self: *VulkanComputePipeline,
        command_buffer: c.VkCommandBuffer,
        input_buffer: c.VkBuffer,
        output_buffer: c.VkBuffer,
        _: SpiralConvolutionParams,
        work_group_size: [3]u32,
    ) void {
        // Update descriptor sets
        const buffer_infos = [2]c.VkDescriptorBufferInfo{
            .{
                .buffer = input_buffer,
                .offset = 0,
                .range = c.VK_WHOLE_SIZE,
            },
            .{
                .buffer = output_buffer,
                .offset = 0,
                .range = c.VK_WHOLE_SIZE,
            },
        };
        
        const write_descriptor_sets = [3]c.VkWriteDescriptorSet{
            .{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[0],
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .pImageInfo = null,
                .pBufferInfo = &buffer_infos[0],
                .pTexelBufferView = null,
            },
            .{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[0],
                .dstBinding = 1,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .pImageInfo = null,
                .pBufferInfo = &buffer_infos[1],
                .pTexelBufferView = null,
            },
            .{
                .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[0],
                .dstBinding = 2,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .pImageInfo = null,
                .pBufferInfo = null,
                .pTexelBufferView = null,
            },
        };
        
        c.vkUpdateDescriptorSets(
            self.context.device,
            @as(u32, @intCast(write_descriptor_sets.len)),
            &write_descriptor_sets,
            0,
            null,
        );
        
        // Bind pipeline and descriptor sets
        c.vkCmdBindPipeline(command_buffer, c.VK_PIPELINE_BIND_POINT_COMPUTE, self.pipeline);
        c.vkCmdBindDescriptorSets(
            command_buffer,
            c.VK_PIPELINE_BIND_POINT_COMPUTE,
            self.pipeline_layout,
            0,
            1,
            &self.descriptor_sets[0],
            0,
            null,
        );
        
        // Dispatch compute
        c.vkCmdDispatch(
            command_buffer,
            work_group_size[0],
            work_group_size[1],
            work_group_size[2],
        );
    }
};

fn createShaderModule(context: *Context, code: []const u8) !c.VkShaderModule {
    const create_info = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = code.len,
        .pCode = @ptrCast(@alignCast(code.ptr)),
    };
    
    var shader_module: c.VkShaderModule = undefined;
    if (c.vkCreateShaderModule(context.device, &create_info, null, &shader_module) != c.VK_SUCCESS) {
        return error.ShaderModuleCreationFailed;
    }
    
    return shader_module;
}

fn createDescriptorSetLayout(context: *Context) !c.VkDescriptorSetLayout {
    const bindings = [_]c.VkDescriptorSetLayoutBinding{
        .{
            .binding = 0,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 1,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 2,
            .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
    };
    
    const create_info = c.VkDescriptorSetLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = @as(u32, @intCast(bindings.len)),
        .pBindings = &bindings[0],
    };
    
    var descriptor_set_layout: c.VkDescriptorSetLayout = undefined;
    if (c.vkCreateDescriptorSetLayout(context.device, &create_info, null, &descriptor_set_layout) != c.VK_SUCCESS) {
        return error.DescriptorSetLayoutCreationFailed;
    }
    
    return descriptor_set_layout;
}

fn createPipelineLayout(context: *Context, descriptor_set_layout: c.VkDescriptorSetLayout) !c.VkPipelineLayout {
    const push_constant_range = c.VkPushConstantRange{
        .stageFlags = c.VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0,
        .size = @sizeOf(SpiralConvolutionParams),
    };
    
    const create_info = c.VkPipelineLayoutCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &push_constant_range,
    };
    
    var pipeline_layout: c.VkPipelineLayout = undefined;
    if (c.vkCreatePipelineLayout(context.device, &create_info, null, &pipeline_layout) != c.VK_SUCCESS) {
        return error.PipelineLayoutCreationFailed;
    }
    
    return pipeline_layout;
}

fn createComputePipeline(context: *Context, shader_module: c.VkShaderModule, pipeline_layout: c.VkPipelineLayout) !c.VkPipeline {
    const stage_create_info = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = c.VK_SHADER_STAGE_COMPUTE_BIT,
        .module = shader_module,
        .pName = "main",
        .pSpecializationInfo = null,
    };
    
    const create_info = c.VkComputePipelineCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = stage_create_info,
        .layout = pipeline_layout,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };
    
    var pipeline: c.VkPipeline = undefined;
    if (c.vkCreateComputePipelines(context.device, null, 1, &create_info, null, &pipeline) != c.VK_SUCCESS) {
        return error.PipelineCreationFailed;
    }
    
    return pipeline;
}

fn createDescriptorPool(context: *Context, max_sets: u32) !c.VkDescriptorPool {
    const pool_sizes = [_]c.VkDescriptorPoolSize{
        .{ .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 2 * max_sets },
        .{ .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .descriptorCount = max_sets },
    };
    
    const create_info = c.VkDescriptorPoolCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .maxSets = max_sets,
        .poolSizeCount = @as(u32, @intCast(pool_sizes.len)),
        .pPoolSizes = &pool_sizes[0],
    };
    
    var descriptor_pool: c.VkDescriptorPool = undefined;
    if (c.vkCreateDescriptorPool(context.device, &create_info, null, &descriptor_pool) != c.VK_SUCCESS) {
        return error.DescriptorPoolCreationFailed;
    }
    
    return descriptor_pool;
}

fn allocateDescriptorSets(context: *Context, descriptor_pool: c.VkDescriptorPool, 
                         descriptor_set_layout: c.VkDescriptorSetLayout, count: u32) ![]c.VkDescriptorSet {
    const allocator = context.allocator;
    
    const layouts = try allocator.alloc(c.VkDescriptorSetLayout, count);
    defer allocator.free(layouts);
    
    for (layouts) |*layout| {
        layout.* = descriptor_set_layout;
    }
    
    const allocate_info = c.VkDescriptorSetAllocateInfo{
        .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .pNext = null,
        .descriptorPool = descriptor_pool,
        .descriptorSetCount = count,
        .pSetLayouts = layouts.ptr,
    };
    
    const descriptor_sets = try allocator.alloc(c.VkDescriptorSet, count);
    errdefer allocator.free(descriptor_sets);
    
    if (c.vkAllocateDescriptorSets(context.device, &allocate_info, descriptor_sets.ptr) != c.VK_SUCCESS) {
        allocator.free(descriptor_sets);
        return error.DescriptorSetAllocationFailed;
    }
    
    return descriptor_sets;
}
