// src/vulkan/memory.zig
const std = @import("std");

// Import the vk module that was provided by the build system
const vk = @import("vk");
const VulkanContext = @import("vulkan/context").VulkanContext;

// Import the C types directly from the Vulkan headers
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

/// Vulkan memory allocation and management
pub const VulkanMemory = struct {
    /// Allocate device memory with the given requirements and properties
    pub fn allocate(
        context: *const VulkanContext,
        allocator: std.mem.Allocator,
        requirements: vk.VkMemoryRequirements,
        properties: vk.VkMemoryPropertyFlags,
    ) !vk.VkDeviceMemory {
        _ = allocator; // Might be used for custom allocators in the future
        
        const device = context.device orelse return error.InvalidDevice;
        const physical_device = context.physical_device orelse return error.InvalidPhysicalDevice;
        
        // Get memory properties
        var mem_props: vk.VkPhysicalDeviceMemoryProperties = undefined;
        const physical_device_ptr = @as(vk.VkPhysicalDevice, @ptrCast(physical_device));
        vk.vkGetPhysicalDeviceMemoryProperties(physical_device_ptr, &mem_props);
        
        // Find a suitable memory type
        const memory_type_bits = @as(u32, @intCast(requirements.memoryTypeBits));
        var memory_type_index: u32 = 0;
        var found = false;
        
        for (0..mem_props.memoryTypeCount) |i| {
            const memory_type = mem_props.memoryTypes[i];
            const bit = @as(u32, 1) << @as(u5, @intCast(i));
            const has_type = (memory_type_bits & bit) != 0;
            const has_properties = (memory_type.propertyFlags & properties) == properties;
            
            if (has_type and has_properties) {
                memory_type_index = @as(u32, @intCast(i));
                found = true;
                break;
            }
        }
        
        if (!found) {
            return error.NoSuitableMemoryType;
        }
        
        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = requirements.size,
            .memoryTypeIndex = memory_type_index,
        };
        
        var memory: vk.VkDeviceMemory = undefined;
        const device_ptr = @as(vk.VkDevice, @ptrCast(device));
        try vk.checkSuccess(
            vk.vkAllocateMemory(device_ptr, &alloc_info, null, &memory),
            error.FailedToAllocateMemory
        );
        
        return memory;
    }
    
    /// Free allocated device memory
    pub fn free(
        context: *const VulkanContext,
        allocator: std.mem.Allocator,
        memory: vk.VkDeviceMemory,
    ) void {
        _ = allocator; // Might be used for custom allocators in the future
        vk.vkFreeMemory(context.device.?, memory, null);
    }
};

// Helper function to find memory type with required properties
pub fn findMemoryType(
    physical_device: vk.VkPhysicalDevice,
    type_filter: u32,
    properties: vk.VkMemoryPropertyFlags,
) !u32 {
    // Get memory properties directly from the physical device
    var mem_props: vk.VkPhysicalDeviceMemoryProperties = undefined;
    const physical_device_ptr = @as(vk.VkPhysicalDevice, @ptrCast(physical_device));
    vk.vkGetPhysicalDeviceMemoryProperties(physical_device_ptr, &mem_props);
    
    // Find a memory type that is suitable for the buffer and has the required properties
    for (0..mem_props.memoryTypeCount) |i| {
        const memory_type = mem_props.memoryTypes[i];
        const bit = @as(u32, 1) << @as(u5, @intCast(i));
        const has_type = (type_filter & bit) != 0;
        const has_properties = (memory_type.propertyFlags & properties) == properties;
        
        if (has_type and has_properties) {
            return @as(u32, @intCast(i));
        }
    }
    
    return error.NoSuitableMemoryType;
}

// For backward compatibility
pub const Buffer_legacy = struct {
    vk_buffer: vk.VkBuffer,
    memory: vk.VkDeviceMemory,
    size: usize,
    mapped: ?*anyopaque,

    pub fn init(
        device: vk.VkDevice,
        physical_device: vk.VkPhysicalDevice,
        size: usize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    ) !Buffer_legacy {
        if (device == null) {
            std.debug.print("Error: Invalid Vulkan device (null)\n", .{});
            return error.InvalidDevice;
        }
        
        if (physical_device == null) {
            std.debug.print("Error: Invalid physical device (null)\n", .{});
            return error.InvalidPhysicalDevice;
        }
        
        if (size == 0) {
            std.debug.print("Error: Cannot create buffer with size 0\n", .{});
            return error.InvalidSize;
        }
        std.debug.print("  Creating Vulkan buffer...\n", .{});
        std.debug.print("    Size: {} bytes\n", .{size});
        std.debug.print("    Usage: {b}\n", .{usage});
        std.debug.print("    Memory properties: {b}\n", .{memory_properties});
        
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
        
        std.debug.print("  Creating buffer...\n", .{});

        var buffer: vk.VkBuffer = undefined;
        var result = vk.vkCreateBuffer(device, &buffer_info, null, &buffer);
        if (result != vk.VK_SUCCESS) {
            std.debug.print("  Failed to create buffer: {}\n", .{result});
            return error.BufferCreationFailed;
        }
        std.debug.print("  Buffer created successfully\n", .{});

        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(device, buffer, &mem_requirements);
        
        std.debug.print("  Memory requirements:\n", .{});
        std.debug.print("    Size: {} bytes\n", .{mem_requirements.size});
        std.debug.print("    Alignment: {}\n", .{mem_requirements.alignment});
        std.debug.print("    Memory type bits: {b}\n", .{mem_requirements.memoryTypeBits});

        const memory = try VulkanMemory.allocate(
            VulkanContext{
                .device = device,
                .physical_device = physical_device,
            },
            std.heap.page_allocator,
            mem_requirements,
            memory_properties,
        );

        std.debug.print("  Binding memory to buffer...\n", .{});
        result = vk.vkBindBufferMemory(device, buffer, memory, 0);
        if (result != vk.VK_SUCCESS) {
            std.debug.print("  Failed to bind buffer memory: {}\n", .{result});
            vk.vkFreeMemory(device, memory, null);
            vk.vkDestroyBuffer(device, buffer, null);
            return error.BufferMemoryBindFailed;
        }
        std.debug.print("  Memory bound to buffer successfully\n", .{});

        return Buffer_legacy{
            .vk_buffer = buffer,
            .memory = memory,
            .size = @as(usize, @intCast(size)),
            .mapped = null,
        };
    }

    pub fn deinit(self: *Buffer_legacy, device: vk.VkDevice) void {
        if (self.mapped) |_| {
            self.unmap(device);
        }
        vk.vkDestroyBuffer(device, self.vk_buffer, null);
        vk.vkFreeMemory(device, self.memory, null);
    }

    pub fn map(self: *Buffer_legacy, device: vk.VkDevice, offset: usize, size: usize) !*anyopaque {
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

    pub fn unmap(self: *Buffer_legacy, device: vk.VkDevice) void {
        if (self.mapped) |_| {
            vk.vkUnmapMemory(device, self.memory);
            self.mapped = null;
        }
    }

    pub fn flush(self: *Buffer_legacy, device: vk.VkDevice, offset: usize, size: usize) !void {
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

    pub fn invalidate(self: *Buffer_legacy, device: vk.VkDevice, offset: usize, size: usize) !void {
        const range = vk.VkMappedMemoryRange{
            .sType = vk.VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
            .pNext = null,
            .memory = self.memory,
            .offset = @as(u64, @intCast(offset)),
            .size = if (size == 0) vk.VK_WHOLE_SIZE else @as(u64, @intCast(size)),
        };
        const result = vk.vkInvalidateMappedMemoryRanges(device, 1, &range);
        if (result != vk.VK_SUCCESS) {
            std.debug.print("Error: Failed to invalidate mapped memory range\n", .{});
            return error.InvalidateFailed;
        }
    }
};