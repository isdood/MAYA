// src/vulkan/memory/buffer.zig
const std = @import("std");
const vk = @import("vk");
const Context = @import("vulkan/context").VulkanContext;
const transfer = @import("vulkan/memory/transfer");

/// Represents a Vulkan buffer with associated memory
pub const Buffer = struct {
    /// The underlying Vulkan buffer handle
    handle: vk.VkBuffer,
    
    /// The memory allocated for this buffer
    memory: vk.VkDeviceMemory,
    
    /// Size of the buffer in bytes
    size: vk.VkDeviceSize,
    
    /// Pointer to mapped memory, or null if not mapped
    mapped_ptr: ?*anyopaque,
    
    /// Vulkan context this buffer belongs to
    context: *Context,
    
    /// Memory properties this buffer was created with
    memory_properties: vk.VkMemoryPropertyFlags,

    pub fn init(
        context: *Context,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        properties: vk.VkMemoryPropertyFlags,
    ) !@This() {
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
        const device = context.device orelse return error.DeviceNotInitialized;
        
        const result = vk.vkCreateBuffer(device, &buffer_info, null, &buffer);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToCreateBuffer;
        }
        errdefer vk.vkDestroyBuffer(device, buffer, null);

        // Get memory requirements
        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(device, buffer, &mem_requirements);

        // Allocate memory
        const physical_device = context.physical_device orelse return error.PhysicalDeviceNotInitialized;
        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = try findMemoryType(
                physical_device,
                mem_requirements.memoryTypeBits,
                properties
            ),
        };

        var memory: vk.VkDeviceMemory = undefined;
        const alloc_result = vk.vkAllocateMemory(device, &alloc_info, null, &memory);
        if (alloc_result != vk.VK_SUCCESS) {
            return error.FailedToAllocateMemory;
        }
        errdefer vk.vkFreeMemory(device, memory, null);

        // Bind buffer memory
        const bind_result = vk.vkBindBufferMemory(device, buffer, memory, 0);
        if (bind_result != vk.VK_SUCCESS) {
            return error.FailedToBindBufferMemory;
        }

        return @This(){
            .handle = buffer,
            .memory = memory,
            .size = size,
            .mapped_ptr = null,
            .context = context,
            .memory_properties = properties,
        };
    }

    /// Deinitialize and clean up the buffer resources
    pub fn deinit(self: *@This()) void {
        const device = self.context.device orelse return;
        if (self.mapped_ptr) |_| {
            self.unmap();
        }
        if (self.handle != null) {
            vk.vkDestroyBuffer(device, self.handle, null);
            self.handle = null;
        }
        if (self.memory != null) {
            vk.vkFreeMemory(device, self.memory, null);
            self.memory = null;
        }
    }
    
    /// Reset the buffer to its initial state (useful for pooling)
    pub fn reset(self: *@This()) void {
        self.mapped_ptr = null;
    }

    /// Map the buffer memory to host-visible memory
    pub fn map(self: *@This()) !*anyopaque {
        if (self.mapped_ptr) |ptr| return ptr;
        
        const device = self.context.device orelse return error.DeviceNotInitialized;
        var ptr: *anyopaque = undefined;
        const map_result = vk.vkMapMemory(
            device,
            self.memory,
            0, // offset
            vk.VK_WHOLE_SIZE,
            0, // flags
            @ptrCast(&ptr)
        );
        if (map_result != vk.VK_SUCCESS) {
            return error.FailedToMapMemory;
        }
        self.mapped_ptr = ptr;
        return ptr;
    }

    pub fn unmap(self: *@This()) void {
        if (self.mapped_ptr) |_| {
            const device = self.context.device orelse return;
            vk.vkUnmapMemory(device, self.memory);
            self.mapped_ptr = null;
        }
    }

    /// Copy data from host to device memory
    /// Note: For optimal performance, use StagingManager for large transfers
    pub fn copyToDevice(self: *@This(), data: []const u8) !void {
        if (data.len == 0) return;
        if (data.len > self.size) {
            return error.BufferTooSmall;
        }
        
        // Use direct mapping if host-visible
        if (self.memory_properties & vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT != 0) {
            const ptr = try self.map();
            defer self.unmap();
            const dest = @as([*]u8, @ptrCast(ptr));
            @memcpy(dest[0..data.len], data);
        } else {
            // For device-local memory, use a staging buffer
            // Note: In a real implementation, you'd want to batch these operations
            var transfer_mgr = try transfer.StagingManager.init(
                std.heap.page_allocator,
                self.context,
                0, // TODO: Get transfer queue family index from context
            );
            defer transfer_mgr.deinit();
            
            try transfer_mgr.copyToDevice(self, data);
        }
    }

    /// Copy data from device to host memory
    /// Note: For optimal performance, use StagingManager for large transfers
    pub fn copyFromDevice(self: *@This(), data: []u8) !void {
        if (data.len == 0) return;
        if (data.len > self.size) {
            return error.BufferTooSmall;
        }
        
        // Use direct mapping if host-visible
        if (self.memory_properties & vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT != 0) {
            const ptr = try self.map();
            defer self.unmap();
            const src = @as([*]const u8, @ptrCast(ptr));
            @memcpy(data, src[0..data.len]);
        } else {
            // For device-local memory, use a staging buffer
            // Note: In a real implementation, you'd want to batch these operations
            var transfer_mgr = try transfer.StagingManager.init(
                std.heap.page_allocator,
                self.context,
                0, // TODO: Get transfer queue family index from context
            );
            defer transfer_mgr.deinit();
            
            try transfer_mgr.copyFromDevice(self, data);
        }
    }

    /// Find a memory type with the required properties
    pub fn findMemoryType(
        physical_device: vk.VkPhysicalDevice,
        type_filter: u32,
        properties: vk.VkMemoryPropertyFlags,
    ) !u32 {
        var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

        var i: u5 = 0;
        while (i < @as(u5, @intCast(mem_properties.memoryTypeCount))) : (i += 1) {
            const type_mask = @as(u32, 1) << i;
            if ((type_filter & type_mask) != 0 and
                (mem_properties.memoryTypes[i].propertyFlags & properties) == properties)
            {
                return @as(u32, i);
            }
        }

        return error.NoSuitableMemoryType;
    }
};
