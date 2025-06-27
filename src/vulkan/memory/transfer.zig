// src/vulkan/memory/transfer.zig
const std = @import("std");
const vk = @import("vk");
const Buffer = @import("./buffer.zig").Buffer;
const Context = @import("vulkan/context").VulkanContext;

/// Manages staging buffers for efficient data transfer
export const StagingManager = struct {
    const Self = @This();
    
    /// Context for Vulkan operations
    context: *Context,
    
    /// Allocator for internal data structures
    allocator: std.mem.Allocator,
    
    /// Command pool for transfer operations
    command_pool: vk.VkCommandPool,
    
    /// Transfer queue
    transfer_queue: vk.VkQueue,
    
    /// Initialize a new staging manager
    pub fn init(
        allocator: std.mem.Allocator,
        context: *Context,
        queue_family_index: u32,
    ) !Self {
        const device = context.device orelse return error.DeviceNotInitialized;
        
        // Create command pool for transfer operations
        const pool_info = vk.VkCommandPoolCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT,
            .queueFamilyIndex = queue_family_index,
        };
        
        var command_pool: vk.VkCommandPool = undefined;
        const pool_result = vk.vkCreateCommandPool(device, &pool_info, null, &command_pool);
        if (pool_result != vk.VK_SUCCESS) {
            return error.FailedToCreateCommandPool;
        }
        
        // Get transfer queue
        var transfer_queue: vk.VkQueue = undefined;
        vk.vkGetDeviceQueue(device, queue_family_index, 0, &transfer_queue);
        
        return Self{
            .context = context,
            .allocator = allocator,
            .command_pool = command_pool,
            .transfer_queue = transfer_queue,
        };
    }
    
    /// Deinitialize the staging manager
    pub fn deinit(self: *Self) void {
        const device = self.context.device orelse return;
        vk.vkDestroyCommandPool(device, self.command_pool, null);
    }
    
    /// Copy data from host to device using a staging buffer
    pub fn copyToDevice(
        self: *Self,
        device_buffer: *Buffer,
        data: []const u8,
    ) !void {
        if (data.len == 0) return;
        if (data.len > device_buffer.size) return error.BufferTooSmall;
        
        // Create a staging buffer
        const staging_buffer = try Buffer.init(
            self.context,
            data.len,
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer staging_buffer.deinit();
        
        // Copy data to staging buffer
        try staging_buffer.copyToDevice(data);
        
        // Copy from staging to device buffer
        try self.copyBuffer(&staging_buffer, device_buffer, data.len);
    }
    
    /// Copy data from device to host using a staging buffer
    pub fn copyFromDevice(
        self: *Self,
        device_buffer: *const Buffer,
        data: []u8,
    ) !void {
        if (data.len == 0) return;
        if (data.len > device_buffer.size) return error.BufferTooSmall;
        
        // Create a staging buffer
        const staging_buffer = try Buffer.init(
            self.context,
            data.len,
            vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
        );
        defer staging_buffer.deinit();
        
        // Copy from device to staging buffer
        try self.copyBuffer(device_buffer, &staging_buffer, data.len);
        
        // Copy data from staging buffer
        try staging_buffer.copyFromDevice(data);
    }
    
    /// Internal function to copy between buffers
    fn copyBuffer(
        self: *Self,
        src: *const Buffer,
        dst: *Buffer,
        size: usize,
    ) !void {
        const device = self.context.device orelse return error.DeviceNotInitialized;
        
        // Allocate command buffer
        const alloc_info = vk.VkCommandBufferAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = null,
            .commandPool = self.command_pool,
            .level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };
        
        var command_buffer: vk.VkCommandBuffer = undefined;
        const alloc_result = vk.vkAllocateCommandBuffers(device, &alloc_info, &command_buffer);
        if (alloc_result != vk.VK_SUCCESS) {
            return error.FailedToAllocateCommandBuffer;
        }
        
        // Begin command buffer
        const begin_info = vk.VkCommandBufferBeginInfo{
            .sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .pNext = null,
            .flags = vk.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        };
        
        const begin_result = vk.vkBeginCommandBuffer(command_buffer, &begin_info);
        if (begin_result != vk.VK_SUCCESS) {
            vk.vkFreeCommandBuffers(device, self.command_pool, 1, &command_buffer);
            return error.FailedToBeginCommandBuffer;
        }
        
        // Record copy command
        const region = vk.VkBufferCopy{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = @as(vk.VkDeviceSize, @intCast(size)),
        };
        
        vk.vkCmdCopyBuffer(
            command_buffer,
            src.handle,
            dst.handle,
            1,
            &region,
        );
        
        // End command buffer
        const end_result = vk.vkEndCommandBuffer(command_buffer);
        if (end_result != vk.VK_SUCCESS) {
            vk.vkFreeCommandBuffers(device, self.command_pool, 1, &command_buffer);
            return error.FailedToEndCommandBuffer;
        }
        
        // Submit command buffer
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
        
        const submit_result = vk.vkQueueSubmit(self.transfer_queue, 1, &submit_info, null);
        vk.vkFreeCommandBuffers(device, self.command_pool, 1, &command_buffer);
        
        if (submit_result != vk.VK_SUCCESS) {
            return error.FailedToSubmitCommandBuffer;
        }
        
        // Wait for the transfer to complete
        vk.vkQueueWaitIdle(self.transfer_queue);
    }
};
