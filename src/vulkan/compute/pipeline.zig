// src/vulkan/compute/pipeline.zig
const std = @import("std");
const vk = @import("../vk.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const Context = @import("context").VulkanContext;

pub const ComputePipeline = struct {
    device: vk.VkDevice,
    pipeline: vk.VkPipeline,
    pipeline_layout: vk.VkPipelineLayout,
    descriptor_set_layout: vk.VkDescriptorSetLayout,

    pub fn init(
        device: vk.VkDevice,
        shader_code: []const u32,
        descriptor_set_layout_bindings: []const vk.VkDescriptorSetLayoutBinding,
    ) !ComputePipeline {
        // Create shader module
        const shader_module = try createShaderModule(device, shader_code);
        defer vk.vkDestroyShaderModule(device, shader_module, null);

        // Create descriptor set layout
        const layout_info = vk.VkDescriptorSetLayoutCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .bindingCount = @as(u32, @intCast(descriptor_set_layout_bindings.len)),
            .pBindings = descriptor_set_layout_bindings.ptr,
        };

        var descriptor_set_layout: vk.VkDescriptorSetLayout = undefined;
        var result = vk.vkCreateDescriptorSetLayout(device, &layout_info, null, &descriptor_set_layout);
        if (result != vk.VK_SUCCESS) {
            return error.DescriptorSetLayoutCreationFailed;
        }
        errdefer vk.vkDestroyDescriptorSetLayout(device, descriptor_set_layout, null);

        // Create pipeline layout
        const pipeline_layout_info = vk.VkPipelineLayoutCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .setLayoutCount = 1,
            .pSetLayouts = &descriptor_set_layout,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
        };

        var pipeline_layout: vk.VkPipelineLayout = undefined;
        result = vk.vkCreatePipelineLayout(device, &pipeline_layout_info, null, &pipeline_layout);
        if (result != vk.VK_SUCCESS) {
            return error.PipelineLayoutCreationFailed;
        }
        errdefer vk.vkDestroyPipelineLayout(device, pipeline_layout, null);

        // Create compute pipeline
        const stage_info = vk.VkPipelineShaderStageCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .module = shader_module,
            .pName = "main",
            .pSpecializationInfo = null,
        };

        const pipeline_info = vk.VkComputePipelineCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .stage = stage_info,
            .layout = pipeline_layout,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        var pipeline: vk.VkPipeline = undefined;
        result = vk.vkCreateComputePipelines(
            device,
            null, // pipeline cache
            1,
            @ptrCast(&pipeline_info),
            null,
            &pipeline,
        );
        if (result != vk.VK_SUCCESS) {
            return error.ComputePipelineCreationFailed;
        }

        return ComputePipeline{
            .device = device,
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .descriptor_set_layout = descriptor_set_layout,
        };
    }

    pub fn deinit(self: *ComputePipeline) void {
        vk.vkDestroyPipeline(self.device, self.pipeline, null);
        vk.vkDestroyPipelineLayout(self.device, self.pipeline_layout, null);
        vk.vkDestroyDescriptorSetLayout(self.device, self.descriptor_set_layout, null);
    }

    fn createShaderModule(device: vk.VkDevice, code: []const u32) !vk.VkShaderModule {
        const create_info = vk.VkShaderModuleCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .codeSize = code.len * @sizeOf(u32),
            .pCode = code.ptr,
        };

        var shader_module: vk.VkShaderModule = undefined;
        const result = vk.vkCreateShaderModule(device, &create_info, null, &shader_module);
        if (result != vk.VK_SUCCESS) {
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
    pipeline: vk.VkPipeline,
    pipeline_layout: vk.VkPipelineLayout,
    descriptor_set_layout: vk.VkDescriptorSetLayout,
    descriptor_pool: vk.VkDescriptorPool,
    descriptor_sets: []vk.VkDescriptorSet,
    shader_module: vk.VkShaderModule,
    
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
            vk.vkDestroyDescriptorPool(device, self.descriptor_pool, null);
        }
        
        if (self.pipeline != null) {
            vk.vkDestroyPipeline(device, self.pipeline, null);
        }
        
        if (self.pipeline_layout != null) {
            vk.vkDestroyPipelineLayout(device, self.pipeline_layout, null);
        }
        
        if (self.descriptor_set_layout != null) {
            vk.vkDestroyDescriptorSetLayout(device, self.descriptor_set_layout, null);
        }
        
        if (self.shader_module != null) {
            vk.vkDestroyShaderModule(device, self.shader_module, null);
        }
    }
    
    pub fn dispatch(
        self: *VulkanComputePipeline,
        command_buffer: vk.VkCommandBuffer,
        input_buffer: vk.VkBuffer,
        output_buffer: vk.VkBuffer,
        _: SpiralConvolutionParams,
        work_group_size: [3]u32,
    ) void {
        // Update descriptor sets
        const buffer_infos = [2]vk.VkDescriptorBufferInfo{
            .{
                .buffer = input_buffer,
                .offset = 0,
                .range = vk.VK_WHOLE_SIZE,
            },
            .{
                .buffer = output_buffer,
                .offset = 0,
                .range = vk.VK_WHOLE_SIZE,
            },
        };
        
        const write_descriptor_sets = [3]vk.VkWriteDescriptorSet{
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[0],
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .pImageInfo = null,
                .pBufferInfo = &buffer_infos[0],
                .pTexelBufferView = null,
            },
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[0],
                .dstBinding = 1,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .pImageInfo = null,
                .pBufferInfo = &buffer_infos[1],
                .pTexelBufferView = null,
            },
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[0],
                .dstBinding = 2,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .pImageInfo = null,
                .pBufferInfo = null,
                .pTexelBufferView = null,
            },
        };
        
        vk.vkUpdateDescriptorSets(
            self.context.device,
            write_descriptor_sets.len,
            &write_descriptor_sets,
            0,
            null,
        );
        
        // Bind pipeline and descriptor sets
        vk.vkCmdBindPipeline(command_buffer, vk.VK_PIPELINE_BIND_POINT_COMPUTE, self.pipeline);
        vk.vkCmdBindDescriptorSets(
            command_buffer,
            vk.VK_PIPELINE_BIND_POINT_COMPUTE,
            self.pipeline_layout,
            0,
            1,
            &self.descriptor_sets[0],
            0,
            null,
        );
        
        // Dispatch compute
        vk.vkCmdDispatch(
            command_buffer,
            work_group_size[0],
            work_group_size[1],
            work_group_size[2],
        );
    }
};

fn createShaderModule(context: *Context, code: []const u8) !vk.VkShaderModule {
    const create_info = vk.VkShaderModuleCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = code.len,
        .pCode = @ptrCast(code.ptr),
    };
    
    var shader_module: vk.VkShaderModule = undefined;
    const result = vk.vkCreateShaderModule(context.device, &create_info, null, &shader_module);
    if (result != vk.VK_SUCCESS) {
        return error.ShaderModuleCreationFailed;
    }
    
    return shader_module;
}

fn createDescriptorSetLayout(context: *Context) !vk.VkDescriptorSetLayout {
    const bindings = [_]vk.VkDescriptorSetLayoutBinding{
        .{
            .binding = 0,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 1,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 2,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
    };
    
    const create_info = vk.VkDescriptorSetLayoutCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = @as(u32, @intCast(bindings.len)),
        .pBindings = &bindings[0],
    };
    
    var descriptor_set_layout: vk.VkDescriptorSetLayout = undefined;
    const result = vk.vkCreateDescriptorSetLayout(context.device, &create_info, null, &descriptor_set_layout);
    if (result != vk.VK_SUCCESS) {
        return error.DescriptorSetLayoutCreationFailed;
    }
    
    return descriptor_set_layout;
}

fn createPipelineLayout(context: *Context, descriptor_set_layout: vk.VkDescriptorSetLayout) !vk.VkPipelineLayout {
    const push_constant_range = vk.VkPushConstantRange{
        .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0,
        .size = @sizeOf(SpiralConvolutionParams),
    };
    
    const create_info = vk.VkPipelineLayoutCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &push_constant_range,
    };
    
    var pipeline_layout: vk.VkPipelineLayout = undefined;
    const result = vk.vkCreatePipelineLayout(context.device, &create_info, null, &pipeline_layout);
    if (result != vk.VK_SUCCESS) {
        return error.PipelineLayoutCreationFailed;
    }
    
    return pipeline_layout;
}

fn createComputePipeline(context: *Context, shader_module: vk.VkShaderModule, pipeline_layout: vk.VkPipelineLayout) !vk.VkPipeline {
    const stage_create_info = vk.VkPipelineShaderStageCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = vk.VK_SHADER_STAGE_COMPUTE_BIT,
        .module = shader_module,
        .pName = "main",
        .pSpecializationInfo = null,
    };
    
    const create_info = vk.VkComputePipelineCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stage = stage_create_info,
        .layout = pipeline_layout,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };
    
    var pipeline: vk.VkPipeline = undefined;
    const result = vk.vkCreateComputePipelines(context.device, null, 1, &create_info, null, &pipeline);
    if (result != vk.VK_SUCCESS) {
        return error.PipelineCreationFailed;
    }
    
    return pipeline;
}

fn createDescriptorPool(context: *Context, max_sets: u32) !vk.VkDescriptorPool {
    const pool_sizes = [_]vk.VkDescriptorPoolSize{
        .{ .type = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = 2 * max_sets },
        .{ .type = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, .descriptorCount = max_sets },
    };
    
    const create_info = vk.VkDescriptorPoolCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .maxSets = max_sets,
        .poolSizeCount = @as(u32, @intCast(pool_sizes.len)),
        .pPoolSizes = &pool_sizes[0],
    };
    
    var descriptor_pool: vk.VkDescriptorPool = undefined;
    const result = vk.vkCreateDescriptorPool(context.device, &create_info, null, &descriptor_pool);
    if (result != vk.VK_SUCCESS) {
        return error.DescriptorPoolCreationFailed;
    }
    
    return descriptor_pool;
}

fn allocateDescriptorSets(context: *Context, descriptor_pool: vk.VkDescriptorPool, 
                         descriptor_set_layout: vk.VkDescriptorSetLayout, count: u32) ![]vk.VkDescriptorSet {
    const allocator = context.allocator;
    
    const layouts = try allocator.alloc(vk.VkDescriptorSetLayout, count);
    defer allocator.free(layouts);
    
    for (layouts) |*layout| {
        layout.* = descriptor_set_layout;
    }
    
    const allocate_info = vk.VkDescriptorSetAllocateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .pNext = null,
        .descriptorPool = descriptor_pool,
        .descriptorSetCount = count,
        .pSetLayouts = layouts.ptr,
    };
    
    const descriptor_sets = try allocator.alloc(vk.VkDescriptorSet, count);
    errdefer allocator.free(descriptor_sets);
    
    const result = vk.vkAllocateDescriptorSets(context.device, &allocate_info, descriptor_sets.ptr);
    if (result != vk.VK_SUCCESS) {
        allocator.free(descriptor_sets);
        return error.DescriptorSetAllocationFailed;
    }
    
    return descriptor_sets;
}
