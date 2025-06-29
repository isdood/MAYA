const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("vk");

const Context = @import("vulkan/context").VulkanContext;

/// Configuration for pattern matching
extern fn pattern_matching_comp_spv() [*]const u32;

extern fn advanced_pattern_matching_comp_spv() [*]const u32;

pub const PatternMatchingMethod = enum(u32) {
    ncc = 0,
    sad = 1,
    ssd = 2,
    orb = 3,
};

pub const PatternMatchingConfig = struct {
    scale: f32 = 1.0,
    rotation: f32 = 0.0,  // in radians
    threshold: f32 = 0.5, // similarity threshold [0, 1]
    method: PatternMatchingMethod = .ncc,
};

pub const PatternMatchingPipeline = struct {
    const Self = @This();
    
    context: *Context,
    pipeline: vk.VkPipeline,
    pipeline_layout: vk.VkPipelineLayout,
    descriptor_set_layout: vk.VkDescriptorSetLayout,
    descriptor_pool: vk.VkDescriptorPool,
    descriptor_sets: []vk.VkDescriptorSet,
    push_constants: vk.VkPushConstantRange,
    
    pub fn init(context: *Context, _: Allocator, max_descriptor_sets: u32) !Self {
        // Create descriptor set layout
        const device = @as(vk.VkDevice, @ptrCast(context.device.?));
        const descriptor_set_layout = try createDescriptorSetLayout(device, context.allocator);
        
        // Create pipeline layout with push constants
        const push_constants = vk.VkPushConstantRange{
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .offset = 0,
            .size = @sizeOf(struct {
                width: i32,
                height: i32,
                pattern_width: i32,
                pattern_height: i32,
                scale: f32,
                rotation: f32,
                threshold: f32,
                method: u32,
            })
        };
        
        const pipeline_layout = try createPipelineLayout(device, descriptor_set_layout, &push_constants);
        
        // Create compute pipeline
        const pipeline = try createComputePipeline(device, pipeline_layout, context.allocator);
        
        // Create descriptor pool and sets
        const descriptor_pool = try createDescriptorPool(device, max_descriptor_sets);
        const descriptor_sets = try allocateDescriptorSets(
            device, 
            descriptor_pool, 
            descriptor_set_layout, 
            max_descriptor_sets,
            context.allocator
        );
        
        return Self{
            .context = context,
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .descriptor_set_layout = descriptor_set_layout,
            .descriptor_pool = descriptor_pool,
            .descriptor_sets = descriptor_sets,
            .push_constants = push_constants,
        };
    }
    
    pub fn deinit(self: *Self) void {
        const device = @as(vk.VkDevice, @ptrCast(self.context.device.?));
        vk.vkDestroyPipeline(device, self.pipeline, null);
        vk.vkDestroyPipelineLayout(device, self.pipeline_layout, null);
        vk.vkDestroyDescriptorSetLayout(device, self.descriptor_set_layout, null);
        vk.vkDestroyDescriptorPool(device, self.descriptor_pool, null);
    }
    
    pub fn updateDescriptorSets(
        self: *Self,
        set_index: u32,
        input_image: vk.VkImageView,
        pattern_image: vk.VkImageView,
        output_image: vk.VkImageView,
        intermediate_buffer: vk.VkBuffer,
        intermediate_buffer_size: vk.VkDeviceSize
    ) !void {
        const device = @as(vk.VkDevice, @ptrCast(self.context.device.?));
        
        // Update descriptor sets with actual resources
        const input_image_info = vk.VkDescriptorImageInfo{
            .sampler = null,
            .imageView = input_image,
            .imageLayout = vk.VK_IMAGE_LAYOUT_GENERAL,
        };
        
        const pattern_image_info = vk.VkDescriptorImageInfo{
            .sampler = null,
            .imageView = pattern_image,
            .imageLayout = vk.VK_IMAGE_LAYOUT_GENERAL,
        };
        
        const output_image_info = vk.VkDescriptorImageInfo{
            .sampler = null,
            .imageView = output_image,
            .imageLayout = vk.VK_IMAGE_LAYOUT_GENERAL,
        };
        
        const buffer_info = vk.VkDescriptorBufferInfo{
            .buffer = intermediate_buffer,
            .offset = 0,
            .range = intermediate_buffer_size,
        };
        
        const descriptor_writes = [_]vk.VkWriteDescriptorSet{
            // Input image
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[set_index],
                .dstBinding = 0,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                .pImageInfo = &[_]vk.VkDescriptorImageInfo{input_image_info},
                .pBufferInfo = undefined,
                .pTexelBufferView = null,
            },
            // Pattern image
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[set_index],
                .dstBinding = 1,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                .pImageInfo = &[_]vk.VkDescriptorImageInfo{pattern_image_info},
                .pBufferInfo = undefined,
                .pTexelBufferView = null,
            },
            // Output image
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[set_index],
                .dstBinding = 2,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
                .pImageInfo = &[_]vk.VkDescriptorImageInfo{output_image_info},
                .pBufferInfo = undefined,
                .pTexelBufferView = null,
            },
            // Intermediate buffer
            .{
                .sType = vk.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                .pNext = null,
                .dstSet = self.descriptor_sets[set_index],
                .dstBinding = 3,
                .dstArrayElement = 0,
                .descriptorCount = 1,
                .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                .pImageInfo = undefined,
                .pBufferInfo = &[_]vk.VkDescriptorBufferInfo{buffer_info},
                .pTexelBufferView = null,
            },
        };
        
        vk.vkUpdateDescriptorSets(
            device,
            @intCast(descriptor_writes.len),
            &descriptor_writes,
            0,
            null
        );
    }
    
    pub fn dispatch(
        self: *Self,
        command_buffer: vk.VkCommandBuffer,
        set_index: u32,
        width: u32,
        height: u32,
        pattern_width: u32,
        pattern_height: u32,
        config: PatternMatchingConfig
    ) void {
        // Bind pipeline and descriptor sets
        vk.vkCmdBindPipeline(command_buffer, vk.VK_PIPELINE_BIND_POINT_COMPUTE, self.pipeline);
        vk.vkCmdBindDescriptorSets(
            command_buffer,
            vk.VK_PIPELINE_BIND_POINT_COMPUTE,
            self.pipeline_layout,
            0, // first set
            1, // descriptor set count
            &self.descriptor_sets[set_index],
            0, // dynamic offset count
            null // dynamic offsets
        );
        
        // Push constants
        const push_constants = struct {
            width: i32,
            height: i32,
            pattern_width: i32,
            pattern_height: i32,
            scale: f32,
            rotation: f32,
            threshold: f32,
            method: u32,
        } {
            .width = @intCast(width),
            .height = @intCast(height),
            .pattern_width = @intCast(pattern_width),
            .pattern_height = @intCast(pattern_height),
            .scale = config.scale,
            .rotation = config.rotation,
            .threshold = config.threshold,
            .method = @intFromEnum(config.method),
        };
        
        vk.vkCmdPushConstants(
            command_buffer,
            self.pipeline_layout,
            vk.VK_SHADER_STAGE_COMPUTE_BIT,
            0, // offset
            @sizeOf(@TypeOf(push_constants)),
            &push_constants
        );
        
        // Dispatch compute shader
        const group_count_x = (width + 15) / 16;
        const group_count_y = (height + 15) / 16;
        
        vk.vkCmdDispatch(command_buffer, group_count_x, group_count_y, 1);
    }
};

fn createDescriptorSetLayout(device: vk.VkDevice, _: Allocator) !vk.VkDescriptorSetLayout {
    const bindings = [_]vk.VkDescriptorSetLayoutBinding{
        // Input image
        .{
            .binding = 0,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        // Pattern image
        .{
            .binding = 1,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        // Output image
        .{
            .binding = 2,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        // Intermediate buffer
        .{
            .binding = 3,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
    };
    
    const create_info = vk.VkDescriptorSetLayoutCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = @intCast(bindings.len),
        .pBindings = &bindings,
    };
    
    var layout: vk.VkDescriptorSetLayout = undefined;
    const result = vk.vkCreateDescriptorSetLayout(device, &create_info, null, &layout);
    if (result != vk.VK_SUCCESS) {
        return error.FailedToCreateDescriptorSetLayout;
    }
    
    return layout;
}

fn createPipelineLayout(device: vk.VkDevice, descriptor_set_layout: vk.VkDescriptorSetLayout, push_constant_range: *const vk.VkPushConstantRange) !vk.VkPipelineLayout {
    const create_info = vk.VkPipelineLayoutCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = push_constant_range,
    };
    
    var layout: vk.VkPipelineLayout = undefined;
    const result = vk.vkCreatePipelineLayout(device, &create_info, null, &layout);
    if (result != vk.VK_SUCCESS) {
        return error.FailedToCreatePipelineLayout;
    }
    
    return layout;
}

fn createComputePipeline(device: vk.VkDevice, pipeline_layout: vk.VkPipelineLayout, _: Allocator) !vk.VkPipeline {
    // Load shader module
    const shader_code = advanced_pattern_matching_comp_spv();
    const shader_module = try createShaderModule(device, shader_code);
    defer vk.vkDestroyShaderModule(device, shader_module, null);
    
    const stage_info = vk.VkPipelineShaderStageCreateInfo{
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
        .stage = stage_info,
        .layout = pipeline_layout,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };
    
    var pipeline: vk.VkPipeline = undefined;
    const result = vk.vkCreateComputePipelines(
        device,
        null, // pipeline cache
        1,
        &create_info,
        null,
        &pipeline
    );
    
    if (result != vk.VK_SUCCESS) {
        return error.FailedToCreateComputePipeline;
    }
    
    return pipeline;
}

fn createShaderModule(device: vk.VkDevice, code: [*]const u32) !vk.VkShaderModule {
    const create_info = vk.VkShaderModuleCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = @sizeOf(u32) * 1024, // This should be the actual size of the SPIR-V
        .pCode = code,
    };
    
    var shader_module: vk.VkShaderModule = undefined;
    const result = vk.vkCreateShaderModule(device, &create_info, null, &shader_module);
    if (result != vk.VK_SUCCESS) {
        return error.FailedToCreateShaderModule;
    }
    
    return shader_module;
}

fn createDescriptorPool(device: vk.VkDevice, max_sets: u32) !vk.VkDescriptorPool {
    const pool_sizes = [_]vk.VkDescriptorPoolSize{
        .{ .type = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, .descriptorCount = 3 * max_sets }, // input, pattern, output
        .{ .type = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .descriptorCount = max_sets },    // intermediate buffer
    };
    
    const create_info = vk.VkDescriptorPoolCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .maxSets = max_sets,
        .poolSizeCount = @intCast(pool_sizes.len),
        .pPoolSizes = &pool_sizes,
    };
    
    var descriptor_pool: vk.VkDescriptorPool = undefined;
    const result = vk.vkCreateDescriptorPool(device, &create_info, null, &descriptor_pool);
    if (result != vk.VK_SUCCESS) {
        return error.FailedToCreateDescriptorPool;
    }
    
    return descriptor_pool;
}

fn allocateDescriptorSets(device: vk.VkDevice, descriptor_pool: vk.VkDescriptorPool, descriptor_set_layout: vk.VkDescriptorSetLayout, count: u32, allocator: Allocator) ![]vk.VkDescriptorSet {
    const layouts = try allocator.alloc(vk.VkDescriptorSetLayout, count);
    defer allocator.free(layouts);
    
    for (0..count) |i| {
        layouts[i] = descriptor_set_layout;
    }
    
    const allocate_info = vk.VkDescriptorSetAllocateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .pNext = null,
        .descriptorPool = descriptor_pool,
        .descriptorSetCount = count,
        .pSetLayouts = layouts.ptr,
    };
    
    const descriptor_sets = try allocator.alloc(vk.VkDescriptorSet, count);
    const result = vk.vkAllocateDescriptorSets(device, &allocate_info, descriptor_sets.ptr);
    if (result != vk.VK_SUCCESS) {
        allocator.free(descriptor_sets);
        return error.FailedToAllocateDescriptorSets;
    }
    
    return descriptor_sets;
}
