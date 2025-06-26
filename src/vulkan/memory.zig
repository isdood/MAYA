// src/vulkan/memory.zig
const std = @import("std");
const vk = @import("vk");

pub const Buffer = struct {
    buffer: vk.VkBuffer,
    memory: vk.VkDeviceMemory,
    size: usize,
    mapped: ?*anyopaque,

    pub fn init(
        device: vk.VkDevice,
        physical_device: vk.VkPhysicalDevice,
        size: usize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    ) !Buffer {
        const buffer_info = vk.VkBufferCreateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = @as(u64, @intCast(size)),
            .usage = usage,
            .sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        var buffer: vk.VkBuffer = undefined;
        var result = vk.vkCreateBuffer(device, &buffer_info, null, &buffer);
        if (result != vk.VK_SUCCESS) {
            return error.BufferCreationFailed;
        }

        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(device, buffer, &mem_requirements);

        const memory_type_index = try findMemoryType(
            physical_device,
            mem_requirements.memoryTypeBits,
            memory_properties,
        );

        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: vk.VkDeviceMemory = undefined;
        result = vk.vkAllocateMemory(device, &alloc_info, null, &memory);
        if (result != vk.VK_SUCCESS) {
            vk.vkDestroyBuffer(device, buffer, null);
            return error.MemoryAllocationFailed;
        }

        result = vk.vkBindBufferMemory(device, buffer, memory, 0);
        if (result != vk.VK_SUCCESS) {
            vk.vkFreeMemory(device, memory, null);
            vk.vkDestroyBuffer(device, buffer, null);
            return error.BufferMemoryBindFailed;
        }

        return Buffer{
            .buffer = buffer,
            .memory = memory,
            .size = @as(usize, @intCast(size)),
            .mapped = null,
        };
    }

    pub fn deinit(self: *Buffer, device: vk.VkDevice) void {
        if (self.mapped) |_| {
            self.unmap(device);
        }
        vk.vkDestroyBuffer(device, self.buffer, null);
        vk.vkFreeMemory(device, self.memory, null);
    }

    pub fn map(self: *Buffer, device: vk.VkDevice, offset: usize, size: usize) !*anyopaque {
        var data: *anyopaque = undefined;
        const result = vk.vkMapMemory(
            device,
            self.memory,
            @as(u64, @intCast(offset)),
            @as(u64, @intCast(if (size == 0) self.size else size)),
            0,
            @as([*c]?*anyopaque, @ptrCast(&data)),
        );
        if (result != vk.VK_SUCCESS) {
            return error.MemoryMappingFailed;
        }
        self.mapped = data;
        return data;
    }

    pub fn unmap(self: *Buffer, device: vk.VkDevice) void {
        if (self.mapped) |_| {
            vk.vkUnmapMemory(device, self.memory);
            self.mapped = null;
        }
    }

    pub fn flush(self: *Buffer, device: vk.VkDevice, offset: usize, size: usize) !void {
        const range = vk.VkMappedMemoryRange{
            .sType = vk.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .pNext = null,
            .memory = self.memory,
            .offset = @as(u64, @intCast(offset)),
            .size = if (size == 0) vk.VK_WHOLE_SIZE else @as(u64, @intCast(size)),
        };
        const result = vk.vkFlushMappedMemoryRanges(device, 1, &range);
        if (result != vk.VK_SUCCESS) {
            return error.FlushFailed;
        }
    }

    pub fn invalidate(self: *Buffer, device: vk.VkDevice, offset: usize, size: usize) !void {
        const range = vk.VkMappedMemoryRange{
            .sType = vk.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .pNext = null,
            .memory = self.memory,
            .offset = @as(u64, @intCast(offset)),
            .size = if (size == 0) vk.VK_WHOLE_SIZE else @as(u64, @intCast(size)),
        };
        const result = vk.vkInvalidateMappedMemoryRanges(device, 1, &range);
        if (result != vk.VK_SUCCESS) {
            return error.InvalidateFailed;
        }
    }

    fn findMemoryType(
        physical_device: vk.VkPhysicalDevice,
        type_filter: u32,
        properties: vk.VkMemoryPropertyFlags,
    ) !u32 {
        var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

        for (0..mem_properties.memoryTypeCount) |i| {
            const type_filter_bit = @as(u32, 1) << @as(u5, @intCast(i));
            const has_type = (type_filter & type_filter_bit) != 0;
            const has_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;

            if (has_type and has_properties) {
                return @as(u32, @intCast(i));
            }
        }

        return error.NoSuitableMemoryType;
    }
};