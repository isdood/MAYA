// src/vulkan/compute/memory.zig
const std = @import("std");
const vk = @import("vk");
const Context = @import("vulkan/context").VulkanContext;
const Buffer = @import("vulkan/memory/buffer").Buffer;
const BufferPool = @import("vulkan/memory/pool").BufferPool;
const StagingManager = @import("vulkan/memory/transfer").StagingManager;

/// Global memory manager for tensor operations
pub const TensorMemoryManager = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    context: *Context,
    buffer_pool: *BufferPool,
    staging_manager: *StagingManager,
    
    /// Initialize a new memory manager
    pub fn init(allocator: std.mem.Allocator, context: *Context) !Self {
        // Create buffer pool with reasonable defaults
        const buffer_pool = try allocator.create(BufferPool);
        errdefer allocator.destroy(buffer_pool);
        
        buffer_pool.* = try BufferPool.init(
            allocator,
            context,
            64 * 1024 * 1024, // 64MB chunks
            vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | 
            vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | 
            vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        );
        
        // Create staging manager
        const transfer_queue_family = 0; // TODO: Get from context
        const staging_manager = try allocator.create(StagingManager);
        errdefer {
            buffer_pool.deinit();
            allocator.destroy(staging_manager);
        }
        
        staging_manager.* = try StagingManager.init(
            allocator,
            context,
            transfer_queue_family,
        );
        
        return Self{
            .allocator = allocator,
            .context = context,
            .buffer_pool = buffer_pool,
            .staging_manager = staging_manager,
        };
    }
    
    /// Deinitialize the memory manager and release all resources
    pub fn deinit(self: *Self) void {
        self.staging_manager.deinit();
        self.allocator.destroy(self.staging_manager);
        
        self.buffer_pool.deinit();
        self.allocator.destroy(self.buffer_pool);
    }
    
    /// Create a new tensor with the specified dimensions
    pub fn createTensor(
        self: *Self, 
        comptime T: type, 
        dims: [4]u32, 
        initial_value: T
    ) !std.meta.Child(@TypeOf(Tensor4D(T))) {
        return try Tensor4D(T).init(
            self.context,
            dims,
            initial_value,
            self.allocator,
        );
    }
    
    /// Create an uninitialized tensor
    pub fn createUninitializedTensor(
        self: *Self,
        comptime T: type,
        dims: [4]u32,
    ) !std.meta.Child(@TypeOf(Tensor4D(T))) {
        return try Tensor4D(T).initUninitialized(
            self.context,
            dims,
            self.allocator,
        );
    }
    
    /// Create a tensor from existing data
    pub fn createTensorFromData(
        self: *Self,
        comptime T: type,
        dims: [4]u32,
        data: []const T,
    ) !std.meta.Child(@TypeOf(Tensor4D(T))) {
        return try Tensor4D(T).fromData(
            self.context,
            dims,
            data,
            self.allocator,
        );
    }
};

// Re-export tensor types for convenience
pub const Tensor4D = @import("tensor_operations.zig").Tensor4D;
pub const TensorOperation = @import("tensor_operations.zig").TensorOperation;
pub const TensorOperationParams = @import("tensor_operations.zig").TensorOperationParams;
pub const TensorPipeline = @import("tensor_operations.zig").TensorPipeline;

// Convenience aliases for common tensor types
pub const Tensor4DF32 = Tensor4D(f32);
pub const Tensor4DF16 = Tensor4D(f16);
pub const Tensor4DI32 = Tensor4D(i32);
pub const Tensor4DI16 = Tensor4D(i16);
pub const Tensor4DU32 = Tensor4D(u32);
pub const Tensor4DU16 = Tensor4D(u16);

// Convenience aliases for common pipeline types
pub const TensorPipelineF32 = TensorPipeline(f32);
pub const TensorPipelineF16 = TensorPipeline(f16);
pub const TensorPipelineI32 = TensorPipeline(i32);
pub const TensorPipelineI16 = TensorPipeline(i16);
pub const TensorPipelineU32 = TensorPipeline(u32);
pub const TensorPipelineU16 = TensorPipeline(u16);

// Test the memory manager
test "TensorMemoryManager" {
    const allocator = std.testing.allocator;
    
    // Initialize context and memory manager
    var context = try Context.init(allocator, .{});
    defer context.deinit();
    
    var memory_manager = try TensorMemoryManager.init(allocator, &context);
    defer memory_manager.deinit();
    
    // Test creating a tensor
    const dims = [4]u32{2, 3, 4, 5};
    var tensor = try memory_manager.createTensor(f32, dims, 1.0);
    defer tensor.deinit();
    
    // Verify tensor properties
    try std.testing.expectEqual(dims, tensor.dims);
    
    // Test reading data back
    const data = try tensor.readData(allocator);
    defer allocator.free(data);
    
    // Verify initial value
    for (data) |value| {
        try std.testing.expectEqual(@as(f32, 1.0), value);
    }
    
    // Test writing data
    var new_data = try allocator.alloc(f32, tensor.elementCount());
    defer allocator.free(new_data);
    
    for (new_data, 0..) |*value, i| {
        value.* = @floatFromInt(i);
    }
    
    try tensor.writeData(new_data, allocator);
    
    // Verify written data
    const read_back = try tensor.readData(allocator);
    defer allocator.free(read_back);
    
    for (new_data, read_back) |expected, actual| {
        try std.testing.expectEqual(expected, actual);
    }
}
