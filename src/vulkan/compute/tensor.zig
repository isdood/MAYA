// src/vulkan/compute/tensor.zig
const std = @import("std");
const vk = @import("vk");
const Context = @import("../context").VulkanContext;
const Buffer = @import("../memory/buffer").Buffer;
const DataType = @import("./datatypes.zig").DataType;

/// A generic 4D tensor that can hold any supported data type
pub fn Tensor4D(comptime T: type) type {
    return struct {
        buffer: Buffer,
        dims: [4]u32,  // Dimensions [x, y, z, w]
        data_type: DataType = typeToDataType(T),
        
        const Self = @This();
        
        /// Get the total number of elements in the tensor
        pub fn elementCount(self: Self) usize {
            return self.dims[0] * self.dims[1] * self.dims[2] * self.dims[3];
        }
        
        /// Get the size in bytes of the tensor data
        pub fn sizeInBytes(self: Self) usize {
            return @sizeOf(T) * self.elementCount();
        }
        
        /// Initialize an uninitialized tensor
        pub fn initUninitialized(
            context: *Context,
            dims: [4]u32,
            _: ?std.mem.Allocator, // Keep for API compatibility
        ) !Self {
            const element_count = dims[0] * dims[1] * dims[2] * dims[3];
            const size = element_count * @sizeOf(T);
            
            const buffer = try Buffer.init(
                context.device,
                context.physical_device,
                size,
                vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | 
                vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | 
                vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            );
            
            return Self{
                .buffer = buffer,
                .dims = dims,
            };
        }
        
        /// Initialize a tensor with data
        pub fn initWithData(
            context: *Context,
            dims: [4]u32,
            data: []const T,
            _: ?std.mem.Allocator, // Keep for API compatibility
        ) !Self {
            std.debug.assert(data.len == dims[0] * dims[1] * dims[2] * dims[3]);
            
            var tensor = try Self.initUninitialized(context, dims, null);
            try tensor.writeData(data, null);
            return tensor;
        }
        
        /// Write data to the tensor
        pub fn writeData(self: Self, data: []const T, _: ?std.mem.Allocator) !void {
            // Create a staging buffer
            const staging = try Buffer.init(
                self.buffer.device,
                self.buffer.physical_device,
                data.len * @sizeOf(T),
                vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            );
            defer staging.deinit();
            
            // Copy data to staging buffer
            {
                const mapped = try staging.map(T);
                defer mapped.unmap();
                
                @memcpy(mapped.ptr[0..data.len], data);
            }
            
            // Copy from staging buffer to device buffer
            try self.buffer.copyFrom(staging, data.len * @sizeOf(T));
        }
        
        /// Read data from the tensor
        pub fn readData(self: Self, allocator: ?std.mem.Allocator) ![]T {
            const alloc = allocator orelse default_allocator;
            const element_count = self.elementCount();
            const data = try alloc.alloc(T, element_count);
            
            // Create a staging buffer
            const staging = try Buffer.init(
                self.buffer.device,
                self.buffer.physical_device,
                element_count * @sizeOf(T),
                vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            );
            defer staging.deinit();
            
            // Copy from device buffer to staging buffer
            try staging.copyFrom(self.buffer, element_count * @sizeOf(T));
            
            // Copy data from staging buffer
            {
                const mapped = try staging.map(T);
                defer mapped.unmap();
                
                @memcpy(data.ptr, mapped.ptr[0..element_count]);
            }
            
            return data;
        }
        
        /// Deinitialize the tensor
        pub fn deinit(self: *Self) void {
            self.buffer.deinit();
        }
        
        // Helper function to get DataType from Zig type
        fn typeToDataType(comptime T_: type) DataType {
            return switch (@typeInfo(T_)) {
                .Float => |float| switch (float.bits) {
                    16 => .f16,
                    32 => .f32,
                    64 => .f64,
                    else => @compileError("Unsupported float bit width"),
                },
                .Int => |int| switch (int.bits) {
                    8 => if (int.signedness == .signed) .i8 else .u8,
                    16 => if (int.signedness == .signed) .i16 else .u16,
                    32 => if (int.signedness == .signed) .i32 else .u32,
                    64 => if (int.signedness == .signed) .i64 else .u64,
                    else => @compileError("Unsupported integer bit width"),
                },
                else => @compileError("Unsupported tensor element type"),
            };
        }
    };
}

// Thread-local storage for memory management
threadlocal var default_allocator: std.mem.Allocator = undefined;

// Convenience aliases for common tensor types
pub const Tensor4DF32 = Tensor4D(f32);
pub const Tensor4DF16 = Tensor4D(f16);
pub const Tensor4DI32 = Tensor4D(i32);
pub const Tensor4DU32 = Tensor4D(u32);

// Test the tensor implementation
test "Tensor4D basic operations" {
    const allocator = std.testing.allocator;
    
    // Initialize context
    var context = try Context.init(allocator, .{});
    defer context.deinit();
    
    // Test initialization
    const dims = [4]u32{2, 3, 4, 5};
    var tensor = try Tensor4D(f32).initUninitialized(&context, dims, allocator);
    defer tensor.deinit();
    
    // Test element count
    try std.testing.expectEqual(@as(usize, 2*3*4*5), tensor.elementCount());
    
    // Test data writing and reading
    const test_data = try allocator.alloc(f32, tensor.elementCount());
    defer allocator.free(test_data);
    
    for (test_data, 0..) |*elem, i| {
        elem.* = @floatFromInt(i);
    }
    
    try tensor.writeData(test_data, allocator);
    
    const read_back = try tensor.readData(allocator);
    defer allocator.free(read_back);
    
    try std.testing.expectEqualSlices(f32, test_data, read_back);
}
