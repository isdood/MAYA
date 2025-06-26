// src/vulkan/memory.zig
const std = @import("std");
const c = @import("vk");

pub const Buffer = struct {
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
    size: usize,
    mapped: ?*anyopaque,

    pub fn init(
        device: c.VkDevice,
        physical_device: c.VkPhysicalDevice,
        size: usize,
        usage: c.VkBufferUsageFlags,
        memory_properties: c.VkMemoryPropertyFlags,
    ) !Buffer {
        const buffer_info = c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = @as(u64, @intCast(size)),
            .usage = usage,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        var buffer: c.VkBuffer = undefined;
        var result = c.vkCreateBuffer(device, &buffer_info, null, &buffer);
        if (result != c.VK_SUCCESS) {
            return error.BufferCreationFailed;
        }

        var mem_requirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(device, buffer, &mem_requirements);

        const memory_type_index = try findMemoryType(
            physical_device,
            mem_requirements.memoryTypeBits,
            memory_properties,
        );

        const alloc_info = c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: c.VkDeviceMemory = undefined;
        result = c.vkAllocateMemory(device, &alloc_info, null, &memory);
        if (result != c.VK_SUCCESS) {
            c.vkDestroyBuffer(device, buffer, null);
            return error.MemoryAllocationFailed;
        }

        c.vkBindBufferMemory(device, buffer, memory, 0);

        return Buffer{
            .buffer = buffer,
            .memory = memory,
            .size = @intCast(usize, size),
            .mapped = null,
        };
    }

    pub fn deinit(self: *Buffer, device: c.VkDevice) void {
        if (self.mapped) |_| {
            self.unmap(device);
        }
        c.vkDestroyBuffer(device, self.buffer, null);
        c.vkFreeMemory(device, self.memory, null);
    }

    pub fn map(self: *Buffer, device: c.VkDevice, offset: usize, size: usize) !*anyopaque {
        var data: *anyopaque = undefined;
        const result = c.vkMapMemory(
            device,
            self.memory,
            @as(u64, @intCast(offset)),
            @as(u64, @intCast(if (size == 0) self.size else size)),
            0,
            @as([*c]?*anyopaque, @ptrCast(&data)),
        );
        if (result != c.VK_SUCCESS) {
            return error.MemoryMappingFailed;
        }
        self.mapped = data;
        return data;
    }

    pub fn unmap(self: *Buffer, device: c.VkDevice) void {
        if (self.mapped) |_| {
            c.vkUnmapMemory(device, self.memory);
            self.mapped = null;
        }
    }

    fn findMemoryType(
        physical_device: c.VkPhysicalDevice,
        type_filter: u32,
        properties: c.VkMemoryPropertyFlags,
    ) !u32 {
        var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

        for (0..mem_properties.memoryTypeCount) |i| {
            const type_filter_bit = @as(u32, 1) << @as(u5, @intCast(i));
            const has_type = (type_filter & type_filter_bit) != 0;
            const has_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;

            if (has_type and has_properties) {
                return @intCast(u32, i);
            }
        }

        return error.NoSuitableMemoryType;
    }
};