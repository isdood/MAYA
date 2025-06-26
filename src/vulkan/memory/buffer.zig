// src/vulkan/memory/buffer.zig
const std = @import("std");
const vk = @import("../vk.zig");
const Context = @import("../context.zig").VulkanContext;

pub const Buffer = struct {
    handle: vk.VkBuffer,
    memory: vk.VkDeviceMemory,
    size: vk.VkDeviceSize,
    mapped_ptr: ?*anyopaque,
    context: *Context,

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
        try vk.vkCreateBuffer(context.device, &buffer_info, null, &buffer);
        errdefer vk.vkDestroyBuffer(context.device, buffer, null);

        // Get memory requirements
        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(context.device, buffer, &mem_requirements);

        // Allocate memory
        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = try findMemoryType(
                context.physical_device,
                mem_requirements.memoryTypeBits,
                properties
            ),
        };

        var memory: vk.VkDeviceMemory = undefined;
        try vk.vkAllocateMemory(context.device, &alloc_info, null, &memory);
        errdefer vk.vkFreeMemory(context.device, memory, null);

        // Bind memory
        try vk.vkBindBufferMemory(context.device, buffer, memory, 0);

        return @This(){
            .handle = buffer,
            .memory = memory,
            .size = size,
            .mapped_ptr = null,
            .context = context,
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.mapped_ptr) |_| {
            self.unmap();
        }
        vk.vkDestroyBuffer(self.context.device, self.handle, null);
        vk.vkFreeMemory(self.context.device, self.memory, null);
    }

    pub fn map(self: *@This()) !*anyopaque {
        if (self.mapped_ptr) |ptr| return ptr;
        
        var ptr: *anyopaque = undefined;
        try vk.vkMapMemory(
            self.context.device,
            self.memory,
            0, // offset
            self.size,
            0, // flags
            @ptrCast(&ptr)
        );
        self.mapped_ptr = ptr;
        return ptr;
    }

    pub fn unmap(self: *@This()) void {
        if (self.mapped_ptr) |_| {
            vk.vkUnmapMemory(self.context.device, self.memory);
            self.mapped_ptr = null;
        }
    }

    pub fn copyToDevice(self: *@This(), data: []const u8) !void {
        if (data.len > self.size) {
            return error.BufferTooSmall;
        }
        const ptr = try self.map();
        defer self.unmap();
        @memcpy(@ptrCast([*]u8, ptr)[0..data.len], data);
    }

    pub fn copyFromDevice(self: *@This(), data: []u8) !void {
        if (data.len > self.size) {
            return error.BufferTooSmall;
        }
        const ptr = try self.map();
        defer self.unmap();
        @memcpy(data, @ptrCast([*]const u8, ptr)[0..data.len]);
    }

    fn findMemoryType(
        physical_device: vk.VkPhysicalDevice,
        type_filter: u32,
        properties: vk.VkMemoryPropertyFlags,
    ) !u32 {
        var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);

        for (0..mem_properties.memoryTypeCount) |i| {
            const memory_type = mem_properties.memoryTypes[i];
            if ((type_filter & (@as(u32, 1) << @intCast(u5, i))) != 0 and
                (memory_type.propertyFlags & properties) == properties)
            {
                return @intCast(u32, i);
            }
        }

        return error.NoSuitableMemoryType;
    }
};
