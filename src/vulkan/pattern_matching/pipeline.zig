const std = @import("std");
const vk = @import("../vk");
const Context = @import("../context").VulkanContext;

const Self = @This();

const max_descriptor_sets = 32;
const max_push_constant_size = 128; // bytes

const PushConstants = extern struct {
    image_size: [2]u32,
    pattern_size: [2]u32,
    scale: f32,
};

const DescriptorSetLayouts = struct {
    layout: vk.VkDescriptorSetLayout,
    pool: vk.VkDescriptorPool,
    sets: [max_descriptor_sets]vk.VkDescriptorSet,
};

device: vk.VkDevice,
pipeline: vk.VkPipeline,
pipeline_layout: vk.VkPipelineLayout,
descriptor_set_layouts: DescriptorSetLayouts,
compute_queue: vk.VkQueue,
command_pool: vk.VkCommandPool,

pub fn init(
    context: *Context,
    shader_module: vk.VkShaderModule,
) !Self {
    const device = context.device;
    
    // Create descriptor set layout
    const bindings = [_]vk.VkDescriptorSetLayoutBinding{
        .{
            .binding = 0,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 1,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
        .{
            .binding = 2,
            .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
            .descriptorCount = 1,
            .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
            .pImmutableSamplers = null,
        },
    };

    const layout_info = vk.VkDescriptorSetLayoutCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .bindingCount = @intCast(u32, bindings.len),
        .pBindings = &bindings,
    };

    var descriptor_set_layout: vk.VkDescriptorSetLayout = undefined;
    try vk.checkSuccess(vk.vkCreateDescriptorSetLayout(
        device,
        &layout_info,
        null,
        &descriptor_set_layout,
    ), error.FailedToCreateDescriptorSetLayout);

    // Create descriptor pool
    const pool_sizes = [_]vk.VkDescriptorPoolSize{
        .{ .type = vk.VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, .descriptorCount = 3 * max_descriptor_sets },
    };

    const pool_info = vk.VkDescriptorPoolCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = null,
        .flags = vk.VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
        .maxSets = max_descriptor_sets,
        .poolSizeCount = @intCast(u32, pool_sizes.len),
        .pPoolSizes = &pool_sizes,
    };

    var descriptor_pool: vk.VkDescriptorPool = undefined;
    try vk.checkSuccess(vk.vkCreateDescriptorPool(
        device,
        &pool_info,
        null,
        &descriptor_pool,
    ), error.FailedToCreateDescriptorPool);

    // Allocate descriptor sets
    const layouts = [_]vk.VkDescriptorSetLayout{descriptor_set_layout} ** max_descriptor_sets;
    var descriptor_sets: [max_descriptor_sets]vk.VkDescriptorSet = undefined;
    
    const alloc_info = vk.VkDescriptorSetAllocateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .pNext = null,
        .descriptorPool = descriptor_pool,
        .descriptorSetCount = max_descriptor_sets,
        .pSetLayouts = &layouts,
    };

    try vk.checkSuccess(vk.vkAllocateDescriptorSets(
        device,
        &alloc_info,
        &descriptor_sets,
    ), error.FailedToAllocateDescriptorSets);

    // Create pipeline layout
    const push_constant_range = vk.VkPushConstantRange{
        .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0,
        .size = @sizeOf(PushConstants),
    };

    const pipeline_layout_info = vk.VkPipelineLayoutCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptor_set_layout,
        .pushConstantRangeCount = 1,
        .pPushConstantRanges = &push_constant_range,
    };

    var pipeline_layout: vk.VkPipelineLayout = undefined;
    try vk.checkSuccess(vk.vkCreatePipelineLayout(
        device,
        &pipeline_layout_info,
        null,
        &pipeline_layout,
    ), error.FailedToCreatePipelineLayout);

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
    try vk.checkSuccess(vk.vkCreateComputePipelines(
        device,
        .null_handle,
        1,
        &pipeline_info,
        null,
        &pipeline,
    ), error.FailedToCreateComputePipeline);

    // Create command pool
    const queue_family_index = context.compute_queue_family_index;
    const command_pool_info = vk.VkCommandPoolCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = null,
        .flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = queue_family_index,
    };

    var command_pool: vk.VkCommandPool = undefined;
    try vk.checkSuccess(vk.vkCreateCommandPool(
        device,
        &command_pool_info,
        null,
        &command_pool,
    ), error.FailedToCreateCommandPool);

    // Get compute queue
    var compute_queue: vk.VkQueue = undefined;
    vk.vkGetDeviceQueue(device, queue_family_index, 0, &compute_queue);

    return Self{
        .device = device,
        .pipeline = pipeline,
        .pipeline_layout = pipeline_layout,
        .descriptor_set_layouts = .{
            .layout = descriptor_set_layout,
            .pool = descriptor_pool,
            .sets = descriptor_sets,
        },
        .compute_queue = compute_queue,
        .command_pool = command_pool,
    };
}

pub fn deinit(self: *Self) void {
    const device = self.device;
    
    vk.vkDestroyCommandPool(device, self.command_pool, null);
    vk.vkDestroyPipeline(device, self.pipeline, null);
    vk.vkDestroyPipelineLayout(device, self.pipeline_layout, null);
    
    vk.vkDestroyDescriptorPool(device, self.descriptor_set_layouts.pool, null);
    vk.vkDestroyDescriptorSetLayout(device, self.descriptor_set_layouts.layout, null);
}

pub fn createShaderModule(device: vk.VkDevice, code: []const u8) !vk.VkShaderModule {
    const shader_module_info = vk.VkShaderModuleCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .codeSize = code.len,
        .pCode = @ptrCast([*]const u32, @alignCast(@alignOf(u32), code.ptr)),
    };

    var shader_module: vk.VkShaderModule = undefined;
    try vk.checkSuccess(vk.vkCreateShaderModule(
        device,
        &shader_module_info,
        null,
        &shader_module,
    ), error.FailedToCreateShaderModule);

    return shader_module;
}

// Helper function to create an image view
pub fn createImageView(
    device: vk.VkDevice,
    image: vk.VkImage,
    format: vk.VkFormat,
    aspect_mask: vk.VkImageAspectFlags,
) !vk.VkImageView {
    const subresource_range = vk.VkImageSubresourceRange{
        .aspectMask = aspect_mask,
        .baseMipLevel = 0,
        .levelCount = 1,
        .baseArrayLayer = 0,
        .layerCount = 1,
    };

    const view_info = vk.VkImageViewCreateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .image = image,
        .viewType = vk.VK_IMAGE_VIEW_TYPE_2D,
        .format = format,
        .components = .{
            .r = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .g = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .b = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
            .a = vk.VK_COMPONENT_SWIZZLE_IDENTITY,
        },
        .subresourceRange = subresource_range,
    };

    var image_view: vk.VkImageView = undefined;
    try vk.checkSuccess(vk.vkCreateImageView(
        device,
        &view_info,
        null,
        &image_view,
    ), error.FailedToCreateImageView);

    return image_view;
}
