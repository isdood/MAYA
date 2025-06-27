// src/vulkan/memory/pool.zig
const std = @import("std");
const vk = @import("vk");
const Buffer = @import("./buffer.zig").Buffer;
const Context = @import("vulkan/context").VulkanContext;

/// A pool of reusable buffers with similar properties
pub const BufferPool = struct {
    const Self = @This();

    /// Context for Vulkan operations
    context: *Context,
    
    /// Buffer size for this pool
    buffer_size: vk.VkDeviceSize,
    
    /// Buffer usage flags
    usage: vk.VkBufferUsageFlags,
    
    /// Memory property flags
    memory_properties: vk.VkMemoryPropertyFlags,
    
    /// List of available buffers
    available_buffers: std.ArrayList(*Buffer),
    
    /// Allocator for the pool's internal data structures
    allocator: std.mem.Allocator,

    /// Initialize a new buffer pool
    pub fn init(
        allocator: std.mem.Allocator,
        context: *Context,
        buffer_size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    ) !Self {
        return Self{
            .context = context,
            .buffer_size = buffer_size,
            .usage = usage,
            .memory_properties = memory_properties,
            .available_buffers = std.ArrayList(*Buffer).init(allocator),
            .allocator = allocator,
        };
    }

    /// Deinitialize the buffer pool and all its buffers
    pub fn deinit(self: *Self) void {
        for (self.available_buffers.items) |buffer| {
            buffer.deinit();
            self.allocator.destroy(buffer);
        }
        self.available_buffers.deinit();
    }

    /// Acquire a buffer from the pool, creating a new one if necessary
    pub fn acquire(self: *Self) !*Buffer {
        if (self.available_buffers.popOrNull()) |buffer| {
            return buffer;
        }

        // Create a new buffer
        const buffer = try self.allocator.create(Buffer);
        errdefer self.allocator.destroy(buffer);
        
        buffer.* = try Buffer.init(
            self.context,
            self.buffer_size,
            self.usage,
            self.memory_properties,
        );
        
        return buffer;
    }

    /// Release a buffer back to the pool
    pub fn release(self: *Self, buffer: *Buffer) !void {
        // Reset the buffer if needed
        // Note: In a real implementation, you might want to add a reset method to Buffer
        // that clears or resets the buffer's state
        
        try self.available_buffers.append(buffer);
    }

    /// Get the number of available buffers in the pool
    pub fn availableCount(self: *const Self) usize {
        return self.available_buffers.items.len;
    }
};

/// A manager for multiple buffer pools with different sizes and properties
pub const BufferPoolManager = struct {
    const Self = @This();
    
    /// Context for Vulkan operations
    context: *Context,
    
    /// Allocator for the manager's internal data structures
    allocator: std.mem.Allocator,
    
    /// Map of buffer sizes to pools
    pools: std.AutoHashMap(usize, BufferPool),
    
    /// Initialize a new buffer pool manager
    pub fn init(allocator: std.mem.Allocator, context: *Context) Self {
        return Self{
            .context = context,
            .allocator = allocator,
            .pools = std.AutoHashMap(usize, BufferPool).init(allocator),
        };
    }
    
    /// Deinitialize the buffer pool manager and all its pools
    pub fn deinit(self: *Self) void {
        var it = self.pools.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.pools.deinit();
    }
    
    /// Get or create a buffer pool with the specified parameters
    pub fn getPool(
        self: *Self,
        buffer_size: vk.VkDeviceSize,
        usage: vk.VkBufferUsageFlags,
        memory_properties: vk.VkMemoryPropertyFlags,
    ) !*BufferPool {
        const key = @as(usize, @intCast(buffer_size));
        
        if (self.pools.getPtr(key)) |pool| {
            return pool;
        }
        
        var pool = try BufferPool.init(
            self.allocator,
            self.context,
            buffer_size,
            usage,
            memory_properties,
        );
        
        try self.pools.put(key, pool);
        return &self.pools.getPtr(key).?;
    }
};
