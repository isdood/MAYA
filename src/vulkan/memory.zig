// src/vulkan/memory.zig
const std = @import("std");

// Import the vk module that was provided by the build system
const vk = @import("vk");

// Re-export buffer implementation
pub const Buffer = @import("./memory/buffer.zig").Buffer;

// Re-export pool implementation
pub const pool = @import("./memory/pool.zig");

// Re-export transfer implementation
pub const transfer = @import("./memory/transfer.zig");

// Helper function to find memory type with required properties
fn findMemoryType(
    physical_device: vk.VkPhysicalDevice,
    type_filter: u32,
    properties: vk.VkMemoryPropertyFlags,
) !u32 {
    if (physical_device == null) {
        std.debug.print("Error: Invalid physical device in findMemoryType\n", .{});
        return error.InvalidPhysicalDevice;
    }
    
    std.debug.print("  Looking for memory type with filter: {b}, properties: {b}\n", .{
        type_filter, properties
    });
    
    var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
    vk.vkGetPhysicalDeviceMemoryProperties(physical_device, &mem_properties);
    
    // Debug print available memory types
    std.debug.print("  Available memory types (count: {}):\n", .{mem_properties.memoryTypeCount});
    
    for (0..mem_properties.memoryTypeCount) |i| {
        const type_bit: u32 = @as(u32, 1) << @intCast(i);
        const is_in_filter = (type_filter & type_bit) != 0;
        const type_props = mem_properties.memoryTypes[i].propertyFlags;
        const has_required_props = (type_props & properties) == properties;
        
        std.debug.print("    [{}] Properties: {b}, In filter: {}, Has required props: {}\n", .{
            i, type_props, is_in_filter, has_required_props
        });
        
        if (is_in_filter and has_required_props) {
            std.debug.print("  Selected memory type index: {}\n", .{i});
            return @as(u32, @intCast(i));
        }
    }
    
    std.debug.print("  No suitable memory type found for properties: {b}\n", .{properties});
    std.debug.print("  Type filter bits: {b}\n", .{type_filter});
    std.debug.print("  Available memory types ({}):\n", .{mem_properties.memoryTypeCount});
    for (0..mem_properties.memoryTypeCount) |i| {
        const type_props = mem_properties.memoryTypes[i].propertyFlags;
        std.debug.print("    [{}] Properties: {b}\n", .{i, type_props});
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

        // Find a suitable memory type
        const memory_type_index = blk: {
            const memory_type = try findMemoryType(
                physical_device,
                mem_requirements.memoryTypeBits,
                memory_properties,
            );
            std.debug.print("  Selected memory type index: {} (from bits: {b})\n", .{
                memory_type, 
                mem_requirements.memoryTypeBits
            });
            break :blk memory_type;
        };
        
        if (memory_type_index == std.math.maxInt(u32)) {
            std.debug.print("  Error: Failed to find suitable memory type for properties: {b}\n", .{memory_properties});
            std.debug.print("  Available memory type bits: {b}\n", .{mem_requirements.memoryTypeBits});
            return error.NoSuitableMemoryType;
        }

        const alloc_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };
        
        std.debug.print("  Allocating {} bytes of memory...\n", .{mem_requirements.size});

        var memory: vk.VkDeviceMemory = undefined;
        result = vk.vkAllocateMemory(device, &alloc_info, null, &memory);
        if (result != vk.VK_SUCCESS) {
            std.debug.print("  Failed to allocate memory: {}\n", .{result});
            vk.vkDestroyBuffer(device, buffer, null);
            return error.MemoryAllocationFailed;
        }
        std.debug.print("  Memory allocated successfully\n", .{});

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