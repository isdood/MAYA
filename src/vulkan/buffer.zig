const std = @import("std");
const Allocator = std.mem.Allocator;
const vk = @import("vk");

const VulkanContext = @import("vulkan_context").VulkanContext;
const VulkanMemory = @import("memory").VulkanMemory;

pub const VulkanBuffer = struct {
    buffer: vk.VkBuffer,
    memory: ?vk.VkDeviceMemory,
    size: vk.VkDeviceSize,
    mapped: ?*anyopaque,
    is_mapped: bool,
    memory_properties: vk.VkMemoryPropertyFlags,
    usage: vk.VkBufferUsageFlags,
    
    const Self = @This();
    
    /// Create a new Vulkan buffer
    pub fn create(
        context: *VulkanContext,
        allocator: Allocator,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    ) !Self {
        const buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = size,
            .usage = usage,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = undefined,
        };
        
        var buffer: vk.VkBuffer = undefined;
        try vk.checkSuccess(vk.vkCreateBuffer(
            context.device.?, 
            &buffer_info, 
            null, 
            &buffer
        ), error.FailedToCreateBuffer);
        
        // Allocate memory for the buffer
        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(context.device.?, buffer, &mem_requirements);
        
        const memory = try VulkanMemory.allocate(
            context,
            allocator,
            mem_requirements,
            memory_properties,
        );
        
        try vk.checkSuccess(vk.vkBindBufferMemory(
            context.device.?, 
            buffer, 
            memory, 
            0
        ), error.FailedToBindBufferMemory);
        
        return Self{
            .buffer = buffer,
            .memory = memory,
            .size = size,
            .mapped = null,
            .is_mapped = false,
            .memory_properties = memory_properties,
            .usage = usage,
        };
    }
    
    /// Create a staging buffer (host visible and coherent)
    pub fn createStaging(
        context: *VulkanContext,
        allocator: Allocator,
        size: usize,
    ) !Self {
        return create(
            context,
            allocator,
            @intCast(size),
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
    }
    
    /// Create a device local buffer
    pub fn createDeviceLocal(
        context: *VulkanContext,
        allocator: Allocator,
        size: usize,
        usage: vk.VkBufferUsageFlags,
    ) !Self {
        return create(
            context,
            allocator,
            @intCast(size),
            usage | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );
    }
    
    /// Map the buffer memory
    pub fn map(self: *Self, context: *VulkanContext) !void {
        if (self.is_mapped) return;
        
        var data: *anyopaque = undefined;
        try vk.checkSuccess(vk.vkMapMemory(
            context.device.?, 
            self.memory.?, 
            0, 
            self.size, 
            0, 
            @ptrCast(&data)
        ), error.FailedToMapMemory);
        
        self.mapped = data;
        self.is_mapped = true;
    }
    
    /// Unmap the buffer memory
    pub fn unmap(self: *Self, context: *VulkanContext) void {
        if (!self.is_mapped) return;
        
        vk.vkUnmapMemory(context.device.?, self.memory.?);
        self.mapped = null;
        self.is_mapped = false;
    }
    
    /// Upload data to the buffer
    pub fn upload(self: *Self, context: *VulkanContext, data: []const u8) !void {
        if (self.memory_properties & vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT == 0) {
            return error.MemoryNotHostVisible;
        }
        
        try self.map(context);
        defer self.unmap(context);
        
        const mapped_ptr = @as([*]u8, @ptrCast(@alignCast(self.mapped.?)));
        @memcpy(mapped_ptr[0..data.len], data);
    }
    
    /// Download data from the buffer
    pub fn download(self: *Self, context: *VulkanContext, data: []u8) !void {
        if (self.memory_properties & vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT == 0) {
            return error.MemoryNotHostVisible;
        }
        
        try self.map(context);
        defer self.unmap(context);
        
        const mapped_ptr = @as([*]u8, @ptrCast(@alignCast(self.mapped.?)));
        @memcpy(data, mapped_ptr[0..data.len]);
    }
    
    /// Begin a single-time command buffer
    pub fn beginSingleTimeCommands(device: vk.VkDevice, command_pool: vk.VkCommandPool) !vk.VkCommandBuffer {
        const alloc_info = vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };
        
        var command_buffer: vk.VkCommandBuffer = undefined;
        try vk.checkSuccess(vk.vkAllocateCommandBuffers(device, &alloc_info, &command_buffer), error.FailedToAllocateCommandBuffer);
        
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        };
        
        try vk.checkSuccess(vk.vkBeginCommandBuffer(command_buffer, &begin_info), error.FailedToBeginCommandBuffer);
        
        return command_buffer;
    }
    
    /// End and submit a single-time command buffer
    pub fn endSingleTimeCommands(
        device: vk.VkDevice,
        queue: vk.VkQueue,
        command_pool: vk.VkCommandPool,
        command_buffer: vk.VkCommandBuffer,
    ) !void {
        try vk.checkSuccess(vk.vkEndCommandBuffer(command_buffer), error.FailedToEndCommandBuffer);
        
        const submit_info = vk.VkSubmitInfo{
            .sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .pNext = null,
            .waitSemaphoreCount = 0,
            .pWaitSemaphores = undefined,
            .pWaitDstStageMask = undefined,
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer,
            .signalSemaphoreCount = 0,
            .pSignalSemaphores = undefined,
        };
        
        try vk.checkSuccess(vk.vkQueueSubmit(queue, 1, &submit_info, null), error.FailedToSubmitQueue);
        try vk.checkSuccess(vk.vkQueueWaitIdle(queue), error.FailedToWaitForQueueIdle);
        
        vk.vkFreeCommandBuffers(device, command_pool, 1, &command_buffer);
    }
    
    /// Destroy the buffer and free its memory
    pub fn deinit(self: *Self, context: *VulkanContext, allocator: Allocator) void {
        if (self.memory) |memory| {
            VulkanMemory.free(context, allocator, memory);
        }
        vk.vkDestroyBuffer(context.device.?, self.buffer, null);
    }
};

// Helper function to create a buffer and upload data to it
pub fn createAndUploadBuffer(
    context: *VulkanContext,
    allocator: Allocator,
    data: []const u8,
    usage: vk.VkBufferUsageFlags,
) !VulkanBuffer {
    // Create a staging buffer
    var staging_buffer = try VulkanBuffer.createStaging(context, allocator, data.len);
    errdefer staging_buffer.deinit(context, allocator);
    
    // Upload the data
    try staging_buffer.upload(context, data);
    
    // Create a device local buffer
    const buffer = try VulkanBuffer.createDeviceLocal(context, allocator, data.len, usage);
    
    // Copy from staging to device local
    const command_buffer = try beginSingleTimeCommands(context.device.?, context.command_pool.?);
    
    const copy_region = vk.VkBufferCopy{
        .srcOffset = 0,
        .dstOffset = 0,
        .size = data.len,
    };
    
    vk.vkCmdCopyBuffer(
        command_buffer,
        staging_buffer.buffer,
        buffer.buffer,
        1,
        &copy_region,
    );
    
    try endSingleTimeCommands(
        context.device.?,
        context.compute_queue.?,
        context.command_pool.?,
        command_buffer,
    );
    
    // Cleanup staging buffer
    staging_buffer.deinit(context, allocator);
    
    return buffer;
}

// Re-export the begin/end command buffer functions for convenience
pub const beginSingleTimeCommands = VulkanBuffer.beginSingleTimeCommands;
pub const endSingleTimeCommands = VulkanBuffer.endSingleTimeCommands;
