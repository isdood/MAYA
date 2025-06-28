const std = @import("std");
const vk = @import("vk");

/// Memory manager for Vulkan memory allocation and management
pub const MemoryManager = struct {
    const Self = @This();

    device: vk.VkDevice,
    physical_device: vk.VkPhysicalDevice,
    allocator: std.mem.Allocator,
    
    /// Memory region information
    pub const MemoryRegion = struct {
        memory: vk.VkDeviceMemory,
        size: vk.VkDeviceSize,
        memory_type_index: u32,
        mapped_ptr: ?*anyopaque = null,
        is_mapped: bool = false,
    };

    /// Buffer information
    pub const Buffer = struct {
        buffer: vk.VkBuffer,
        memory: ?*MemoryRegion = null,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    };

    /// Initialize a new memory manager
    pub fn init(device: vk.VkDevice, physical_device: vk.VkPhysicalDevice, allocator: std.mem.Allocator) Self {
        return .{
            .device = device,
            .physical_device = physical_device,
            .allocator = allocator,
        };
    }

    /// Find a memory type with the required properties
    pub fn findMemoryTypeIndex(
        self: *const Self,
        type_filter: u32,
        properties: vk.VkMemoryPropertyFlags,
    ) !u32 {
        var mem_properties: vk.VkPhysicalDeviceMemoryProperties = undefined;
        vk.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &mem_properties);

        for (0..mem_properties.memoryTypeCount) |i| {
            const type_bit = @as(u32, 1) << @intCast(i);
            const is_required_type = (type_filter & type_bit) != 0;
            const has_required_properties = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;
            
            if (is_required_type and has_required_properties) {
                return @intCast(i);
            }
        }

        return error.NoSuitableMemoryType;
    }

    /// Allocate a memory region
    pub fn allocateMemory(
        self: *Self,
        size: vk.VkDeviceSize,
        memory_type_index: u32,
    ) !*MemoryRegion {
        const allocate_info = vk.VkMemoryAllocateInfo{
            .sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: vk.VkDeviceMemory = undefined;
        const result = vk.vkAllocateMemory(self.device, &allocate_info, null, &memory);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToAllocateMemory;
        }

        const region = try self.allocator.create(MemoryRegion);
        region.* = .{
            .memory = memory,
            .size = size,
            .memory_type_index = memory_type_index,
        };

        return region;
    }

    /// Free a memory region
    pub fn freeMemory(self: *Self, region: *MemoryRegion) void {
        if (region.is_mapped) {
            self.unmapMemory(region);
        }
        vk.vkFreeMemory(self.device, region.memory, null);
        self.allocator.destroy(region);
    }

    /// Map memory to host address space
    pub fn mapMemory(self: *Self, region: *MemoryRegion, offset: vk.VkDeviceSize, size: vk.VkDeviceSize) !*anyopaque {
        if (region.is_mapped) {
            return region.mapped_ptr orelse error.MemoryNotMapped;
        }

        var ptr: ?*anyopaque = null;
        const result = vk.vkMapMemory(
            self.device,
            region.memory,
            offset,
            size,
            0, // flags
            @ptrCast(&ptr),
        );

        if (result != vk.VK_SUCCESS or ptr == null) {
            return error.FailedToMapMemory;
        }

        region.mapped_ptr = ptr;
        region.is_mapped = true;
        return ptr.?;
    }

    /// Unmap memory
    pub fn unmapMemory(self: *Self, region: *MemoryRegion) void {
        if (!region.is_mapped) return;
        vk.vkUnmapMemory(self.device, region.memory);
        region.mapped_ptr = null;
        region.is_mapped = false;
    }

    /// Create a buffer with the specified usage and memory properties
    pub fn createBuffer(
        self: *Self,
        size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        properties: vk.VkMemoryPropertyFlags,
    ) !Buffer {
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
        var result = vk.vkCreateBuffer(self.device, &buffer_info, null, &buffer);
        if (result != vk.VK_SUCCESS) {
            return error.FailedToCreateBuffer;
        }

        // Get memory requirements
        var mem_requirements: vk.VkMemoryRequirements = undefined;
        vk.vkGetBufferMemoryRequirements(self.device, buffer, &mem_requirements);

        // Find suitable memory type
        const memory_type_index = try self.findMemoryTypeIndex(
            mem_requirements.memoryTypeBits,
            properties,
        );

        // Allocate memory
        const memory_region = try self.allocateMemory(mem_requirements.size, memory_type_index);
        
        // Bind memory to buffer
        result = vk.vkBindBufferMemory(self.device, buffer, memory_region.memory, 0);
        if (result != vk.VK_SUCCESS) {
            self.freeMemory(memory_region);
            vk.vkDestroyBuffer(self.device, buffer, null);
            return error.FailedToBindBufferMemory;
        }

        return Buffer{
            .buffer = buffer,
            .memory = memory_region,
            .size = size,
            .usage = usage,
            .memory_properties = properties,
        };
    }

    /// Destroy a buffer and free its memory
    pub fn destroyBuffer(self: *Self, buffer: *Buffer) void {
        if (buffer.memory) |memory_region| {
            self.freeMemory(memory_region);
        }
        vk.vkDestroyBuffer(self.device, buffer.buffer, null);
    }

    /// Copy data to a buffer
    pub fn copyToBuffer(
        self: *Self,
        buffer: *Buffer,
        data: []const u8,
        offset: vk.VkDeviceSize,
    ) !void {
        if (buffer.memory == null) {
            return error.BufferHasNoMemory;
        }

        const memory_region = buffer.memory.?;
        
        // Map the buffer memory
        const mapped_ptr = try self.mapMemory(
            memory_region,
            offset,
            @intCast(data.len),
        );
        defer self.unmapMemory(memory_region);

        // Copy the data
        const dest_slice = @as([*]u8, @ptrCast(mapped_ptr))[0..data.len];
        @memcpy(dest_slice, data);
    }

    /// Copy data from a buffer
    pub fn copyFromBuffer(
        self: *Self,
        buffer: *const Buffer,
        data: []u8,
        offset: vk.VkDeviceSize,
    ) !void {
        if (buffer.memory == null) {
            return error.BufferHasNoMemory;
        }

        const memory_region = buffer.memory.?;
        
        // Map the buffer memory
        const mapped_ptr = try self.mapMemory(
            memory_region,
            offset,
            @intCast(data.len),
        );
        defer self.unmapMemory(memory_region);

        // Copy the data
        const src_slice = @as([*]const u8, @ptrCast(mapped_ptr))[0..data.len];
        @memcpy(data, src_slice);
    }
};
