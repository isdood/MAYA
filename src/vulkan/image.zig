const std = @import("std");
const vk = @import("vk");

const Context = @import("vulkan_context").VulkanContext;

/// Represents a Vulkan image and its associated memory and view
pub const VulkanImage = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    vk_device: vk.VkDevice,
    
    image: vk.VkImage,
    memory: vk.VkDeviceMemory,
    view: vk.VkImageView,
    format: vk.VkFormat,
    width: u32,
    height: u32,
    
    /// Create a new Vulkan image
    pub fn create(
        context: *Context,
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
        format: vk.VkFormat,
        usage: vk.VkImageUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    ) !Self {
        const vk_device = @as(vk.VkDevice, @ptrCast(context.device.?));
        
        // Create image
        const image_create_info = vk.VkImageCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .imageType = vk.VK_IMAGE_TYPE_2D,
            .format = format,
            .extent = .{ .width = width, .height = height, .depth = 1 },
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = vk.VK_SAMPLE_COUNT_1_BIT,
            .tiling = vk.VK_IMAGE_TILING_OPTIMAL,
            .usage = usage,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED,
        };
        
        var image: vk.VkImage = undefined;
        var result = vk.vkCreateImage(vk_device, &image_create_info, null, &image);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToCreateImage;
        }
        
        // Allocate memory for the image
        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetImageMemoryRequirements(vk_device, image, &mem_requirements);
        
        const memory_type_index = try findMemoryType(
            @as(vk.VkPhysicalDevice, @ptrCast(context.physical_device.?)),
            mem_requirements.memoryTypeBits, 
            memory_properties
        );
        
        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };
        
        var memory: vk.VkDeviceMemory = undefined;
        result = vk.vkAllocateMemory(vk_device, &alloc_info, null, &memory);
        if (result != vk.VK_SUCCESS) {
            vk.vkDestroyImage(vk_device, image, null);
            return error.FailedToAllocateImageMemory;
        }
        
        // Bind memory to image
        result = vk.vkBindImageMemory(vk_device, image, memory, 0);
        if (result != vk.VK_SUCCESS) {
            vk.vkFreeMemory(vk_device, memory, null);
            vk.vkDestroyImage(vk_device, image, null);
            return error.FailedToBindImageMemory;
        }
        
        // Create image view
        const view_create_info = vk.VkImageViewCreateInfo{
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
            .subresourceRange = .{
                .aspectMask = if (format == vk.VK_FORMAT_D32_SFLOAT) 
                    vk.VK_IMAGE_ASPECT_DEPTH_BIT else vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };
        
        var view: vk.VkImageView = undefined;
        result = vk.vkCreateImageView(vk_device, &view_create_info, null, &view);
        if (result != vk.VK_SUCCESS) {
            vk.vkFreeMemory(vk_device, memory, null);
            vk.vkDestroyImage(vk_device, image, null);
            return error.FailedToCreateImageView;
        }
        
        return Self{
            .allocator = allocator,
            .vk_device = vk_device,
            .image = image,
            .memory = memory,
            .view = view,
            .format = format,
            .width = width,
            .height = height,
        };
    }
    
    /// Create an image suitable for use as a storage image in compute shaders
    pub fn createStorageImage(
        context: *Context,
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
        format: vk.VkFormat,
    ) !Self {
        return Self.create(
            context,
            allocator,
            width,
            height,
            format,
            vk.VK_IMAGE_USAGE_STORAGE_BIT | vk.VK_IMAGE_USAGE_TRANSFER_SRC_BIT | vk.VK_IMAGE_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );
    }
    
    /// Transition the image layout
    pub fn transitionLayout(
        self: *Self,
        command_buffer: vk.VkCommandBuffer,
        old_layout: vk.VkImageLayout,
        new_layout: vk.VkImageLayout,
    ) void {
        var barrier = vk.VkImageMemoryBarrier{
            .sType = vk.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
            .pNext = null,
            .srcAccessMask = 0,
            .dstAccessMask = 0,
            .oldLayout = old_layout,
            .newLayout = new_layout,
            .srcQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
            .dstQueueFamilyIndex = vk.VK_QUEUE_FAMILY_IGNORED,
            .image = self.image,
            .subresourceRange = .{
                .aspectMask = if (self.format == vk.VK_FORMAT_D32_SFLOAT) 
                    vk.VK_IMAGE_ASPECT_DEPTH_BIT else vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        };
        
        var source_stage: vk.VkPipelineStageFlags = undefined;
        var destination_stage: vk.VkPipelineStageFlags = undefined;
        
        if (old_layout == vk.VK_IMAGE_LAYOUT_UNDEFINED and 
            new_layout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL) {
            barrier.srcAccessMask = 0;
            barrier.dstAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
            source_stage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
            destination_stage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
        } else if (old_layout == vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and 
                  new_layout == vk.VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL) {
            barrier.srcAccessMask = vk.VK_ACCESS_TRANSFER_WRITE_BIT;
            barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT;
            source_stage = vk.VK_PIPELINE_STAGE_TRANSFER_BIT;
            destination_stage = vk.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
        } else if (old_layout == vk.VK_IMAGE_LAYOUT_UNDEFINED and 
                  new_layout == vk.VK_IMAGE_LAYOUT_GENERAL) {
            barrier.srcAccessMask = 0;
            barrier.dstAccessMask = vk.VK_ACCESS_SHADER_READ_BIT | vk.VK_ACCESS_SHADER_WRITE_BIT;
            source_stage = vk.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
            destination_stage = vk.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;
        } else {
            @panic("Unsupported layout transition!");
        }
        
        vk.vkCmdPipelineBarrier(
            command_buffer,
            source_stage,
            destination_stage,
            0,
            0, null,
            0, null,
            1, &barrier
        );
    }
    
    /// Copy data from a buffer to this image
    pub fn copyFromBuffer(
        self: *Self,
        command_buffer: vk.VkCommandBuffer,
        buffer: vk.VkBuffer,
        width: u32,
        height: u32,
    ) void {
        const region = vk.VkBufferImageCopy{
            .bufferOffset = 0,
            .bufferRowLength = 0,
            .bufferImageHeight = 0,
            .imageSubresource = .{
                .aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT,
                .mipLevel = 0,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
            .imageExtent = .{ .width = width, .height = height, .depth = 1 },
        };
        
        vk.vkCmdCopyBufferToImage(
            command_buffer,
            buffer,
            self.image,
            vk.VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            1,
            &region
        );
    }
    
    /// Clean up resources
    pub fn deinit(self: *Self) void {
        vk.vkDestroyImageView(self.vk_device, self.view, null);
        vk.vkDestroyImage(self.vk_device, self.image, null);
        vk.vkFreeMemory(self.vk_device, self.memory, null);
    }
    
    /// Find a memory type with the required properties
    fn findMemoryType(
        physical_device: ?*vk.VkPhysicalDevice_T,
        type_filter: u32,
        properties: vk.VkMemoryPropertyFlags,
    ) !u32 {
        var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);
        
        for (0..mem_properties.memoryTypeCount) |i| {
            const type_filter_bit = @as(u32, 1) << @intCast(i);
            const has_type = (type_filter & type_filter_bit) != 0;
            const has_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;
            
            if (has_type and has_properties) {
                return @intCast(i);
            }
        }
        
        return error.NoSuitableMemoryType;
    }
};

pub const VulkanBuffer = struct {
    const Self = @This();
    
    vk_device: vk.VkDevice,
    allocator: std.mem.Allocator,
    
    buffer: vk.VkBuffer,
    memory: vk.VkDeviceMemory,
    size: vk.VkDeviceSize,
    
    /// Create a new Vulkan buffer
    pub fn create(
        context: *Context,
        allocator: std.mem.Allocator,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    ) !Self {
        const vk_device = @as(vk.VkDevice, @ptrCast(context.device.?));
        
        // Create buffer
        const buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = size,
            .usage = usage,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };
        
        var buffer: vk.VkBuffer = undefined;
        var result = vk.vkCreateBuffer(vk_device, &buffer_info, null, &buffer);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToCreateBuffer;
        }
        
        // Allocate memory
        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(vk_device, buffer, &mem_requirements);
        
        const memory_type_index = try VulkanImage.findMemoryType(
            @as(vk.VkPhysicalDevice, @ptrCast(context.physical_device.?)),
            mem_requirements.memoryTypeBits, 
            memory_properties
        );
        
        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };
        
        var memory: vk.VkDeviceMemory = undefined;
        result = vk.vkAllocateMemory(vk_device, &alloc_info, null, &memory);
        if (result != vk.VK_SUCCESS) {
            vk.vkDestroyBuffer(vk_device, buffer, null);
            return error.FailedToAllocateBufferMemory;
        }
        
        // Bind memory to buffer
        result = vk.vkBindBufferMemory(vk_device, buffer, memory, 0);
        if (result != vk.VK_SUCCESS) {
            vk.vkFreeMemory(vk_device, memory, null);
            vk.vkDestroyBuffer(vk_device, buffer, null);
            return error.FailedToBindBufferMemory;
        }
        
        return Self{
            .vk_device = vk_device,
            .allocator = allocator,
            .buffer = buffer,
            .memory = memory,
            .size = size,
        };
    }
    
    /// Create a staging buffer for CPU-GPU data transfer
    pub fn createStaging(
        context: *Context,
        allocator: std.mem.Allocator,
        size: vk.VkDeviceSize,
    ) !Self {
        return Self.create(
            context,
            allocator,
            size,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
    }
    
    /// Create a device-local buffer for GPU-only access
    pub fn createDeviceLocal(
        context: *Context,
        allocator: std.mem.Allocator,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
    ) !Self {
        return Self.create(
            context,
            allocator,
            size,
            usage | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );
    }
    
    /// Map the buffer memory for CPU access
    pub fn map(self: *const Self) ![]u8 {
        var data: ?*anyopaque = null;
        const result = vk.vkMapMemory(
            self.vk_device,
            self.memory,
            0, // offset
            self.size,
            0, // flags
            &data,
        );
        if (result != vk.VK_SUCCESS) {
            return error.FailedToMapMemory;
        }
        return @as([*]u8, @ptrCast(data.?))[0..@as(usize, @intCast(self.size))];
    }
    
    /// Unmap the buffer memory
    pub fn unmap(self: *const Self) void {
        vk.vkUnmapMemory(self.vk_device, self.memory);
    }
    
    /// Copy data to the buffer
    pub fn upload(self: *const Self, data: []const u8) !void {
        const mapped = try self.map();
        defer self.unmap();
        
        @memcpy(mapped[0..data.len], data);
    }
    
    /// Clean up resources
    pub fn destroy(self: *Self) void {
        vk.vkDestroyBuffer(self.vk_device, self.buffer, null);
        vk.vkFreeMemory(self.vk_device, self.memory, null);
    }
};

/// Helper function to copy data between buffers
pub fn copyBuffer(
    command_buffer: vk.VkCommandBuffer,
    src_buffer: vk.VkBuffer,
    dst_buffer: vk.VkBuffer,
    size: vk.VkDeviceSize,
) void {
    const copy_region = vk.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };
    
    vk.vkCmdCopyBuffer(
        command_buffer,
        src_buffer,
        dst_buffer,
        1,
        &copy_region
    );
}

/// Helper function to begin a one-time submit command buffer
pub fn beginSingleTimeCommands(device: vk.VkDevice, command_pool: vk.VkCommandPool) !vk.VkCommandBuffer {
    const alloc_info = vk.VkCommandBufferAllocateInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .pNext = null,
        .commandPool = command_pool,
        .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };
    
    var command_buffer: vk.VkCommandBuffer = undefined;
    var result = vk.vkAllocateCommandBuffers(device, &alloc_info, &command_buffer);
    if (result != vk.VK_SUCCESS) {
        return error.FailedToAllocateCommandBuffer;
    }
    
    const begin_info = vk.VkCommandBufferBeginInfo{
        .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
    };
    
    result = vk.vkBeginCommandBuffer(command_buffer, &begin_info);
    if (result != vk.VK_SUCCESS) {
        vk.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
        return error.FailedToBeginCommandBuffer;
    }
    
    return command_buffer;
}

/// Helper function to end and submit a one-time command buffer
pub fn endSingleTimeCommands(
    device: vk.VkDevice,
    command_pool: vk.VkCommandPool,
    queue: vk.VkQueue,
    command_buffer: vk.VkCommandBuffer,
) !void {
    var result = vk.vkEndCommandBuffer(command_buffer);
    if (result != vk.VK_SUCCESS) {
        vk.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
        return error.FailedToEndCommandBuffer;
    }
    
    const submit_info = vk.VkSubmitInfo{
        .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,
    };
    
    result = vk.vkQueueSubmit(queue, 1, &submit_info, null);
    if (result != vk.VK_SUCCESS) {
        vk.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
        return error.FailedToSubmitCommandBuffer;
    }
    
    result = vk.vkQueueWaitIdle(queue);
    if (result != vk.VK_SUCCESS) {
        vk.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
        return error.FailedToWaitForQueueIdle;
    }
    
    vk.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
}
