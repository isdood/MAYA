// src/vulkan/memory/buffer.zig
const std = @import("std");
const vk = @import("vk");
const Context = @import("vulkan/context").VulkanContext;

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
        };
    }

    pub fn deinit(self: *@This()) void {
        const device = self.context.device orelse return;
        if (self.mapped_ptr) |_| {
            self.unmap();
        }
        vk.vkDestroyBuffer(device, self.handle, null);
        vk.vkFreeMemory(device, self.memory, null);
    }

    pub fn map(self: *@This()) !*anyopaque {
        if (self.mapped_ptr) |ptr| return ptr;
        
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

    pub fn copyToDevice(self: *@This(), data: []const u8) !void {
        if (data.len > self.size) {
            return error.BufferTooSmall;
        }
        const ptr = try self.map();
        defer self.unmap();
        const dest = @as([*]u8, @ptrCast(ptr));
        @memcpy(dest[0..data.len], data);
    }

    pub fn copyFromDevice(self: *@This(), data: []u8) !void {
        if (data.len > self.size) {
            return error.BufferTooSmall;
        }
        const ptr = try self.map();
        defer self.unmap();
        const src = @as([*]const u8, @ptrCast(ptr));
        @memcpy(data, src[0..data.len]);
    }

    fn findMemoryType(
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
