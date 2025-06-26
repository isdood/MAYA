// src/vulkan/compute/tensor_operations.zig
const std = @import("std");
const vk = @import("../vk.zig");

const Context = @import("../context.zig").VulkanContext;
const Pipeline = @import("pipeline.zig").VulkanComputePipeline;
const Buffer = @import("../memory/buffer.zig").Buffer;
const DataType = @import("./datatypes.zig").DataType;

/// A generic 4D tensor that can hold any supported data type
pub fn Tensor4D(comptime T: type) type {
    return struct {
        buffer: Buffer,
        dims: [4]u32,  // Dimensions [x, y, z, w]
        data_type: DataType = typeToDataType(T),
        
        const Self = @This();
        
        pub fn init(
            context: *Context,
            dims: [4]u32,
            initial_value: T,
        ) !Self {
            const element_count = dims[0] * dims[1] * dims[2] * dims[3];
            const size = element_count * @sizeOf(T);
            
            // Create GPU buffer
            var buffer = try Buffer.init(
                context,
                size,
                vk.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.VK_BUFFER_USAGE_TRANSFER_SRC_BIT | vk.VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                vk.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT | vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            );
            
            // Initialize with the provided value
            if (!std.mem.eql(T, &[1]T{0}, &[1]T{initial_value})) {
                const data = try std.heap.page_allocator.alloc(T, element_count);
                defer std.heap.page_allocator.free(data);
                
                @memset(data, initial_value);
                try buffer.copyToDevice(std.mem.sliceAsBytes(data));
            }
            
            return Self{
                .buffer = buffer,
                .dims = dims,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.buffer.deinit();
        }
        
        pub fn elementCount(self: Self) u32 {
            return self.dims[0] * self.dims[1] * self.dims[2] * self.dims[3];
        }
        
        pub fn readData(self: *const Self, allocator: std.mem.Allocator) ![]T {
            const count = self.elementCount();
            const data = try allocator.alloc(T, count);
            try self.buffer.copyFromDevice(std.mem.sliceAsBytes(data));
            return data;
        }
        
        pub fn writeData(self: *Self, data: []const T) !void {
            if (data.len != self.elementCount()) {
                return error.InvalidDataSize;
            }
            try self.buffer.copyToDevice(std.mem.sliceAsBytes(data));
        }
        
        fn typeToDataType(comptime Type: type) DataType {
            return switch (@typeInfo(Type)) {
                .Float => |f| switch (f.bits) {
                    32 => .F32,
                    16 => .F16,
                    else => @compileError("Unsupported float size"),
                },
                .Int => |i| switch (i.bits) {
                    32 => if (i.signedness == .signed) .I32 else .U32,
                    16 => if (i.signedness == .signed) .I16 else .U16,
                    else => @compileError("Unsupported int size"),
                },
                else => @compileError("Unsupported tensor element type"),
            };
        }
    };
}

/// Supported tensor operations
pub const TensorOperation = enum(u32) {
    Add = 0,
    Multiply = 1,
    LinearCombination = 2,
};

/// Parameters for tensor operations
pub fn TensorOperationParams(comptime T: type) type {
    return struct {
        alpha: T = 1,
        beta: T = 1,
        operation: TensorOperation = .Add,
    };
}

/// A pipeline for performing tensor operations on a specific data type
pub fn TensorPipeline(comptime T: type) type {
    return struct {
        pipeline: Pipeline,
        context: *Context,
        
        const Self = @This();
        
        pub fn init(allocator: std.mem.Allocator, context: *Context) !Self {
            // Load the appropriate shader based on the data type
            const shader_path = switch (@typeInfo(T)) {
                .Float => "../../../shaders/4d_tensor_operations_float.comp.spv",
                .Int => |i| if (i.signedness == .signed) 
                    "../../../shaders/4d_tensor_operations_int.comp.spv"
                else 
                    "../../../shaders/4d_tensor_operations_uint.comp.spv",
                else => @compileError("Unsupported tensor element type"),
            };
            
            const shader_code = @embedFile(shader_path);
            
            // Define descriptor set bindings
            const bindings = [_]vk.VkDescriptorSetLayoutBinding{
                // Input A
                .{
                    .binding = 0,
                    .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                    .descriptorCount = 1,
                    .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
                    .pImmutableSamplers = null,
                },
                // Input B
                .{
                    .binding = 1,
                    .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                    .descriptorCount = 1,
                    .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
                    .pImmutableSamplers = null,
                },
                // Output
                .{
                    .binding = 2,
                    .descriptorType = vk.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                    .descriptorCount = 1,
                    .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
                    .pImmutableSamplers = null,
                },
                // Parameters
                .{
                    .binding = 3,
                    .descriptorType = vk.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                    .descriptorCount = 1,
                    .stageFlags = vk.VK_SHADER_STAGE_COMPUTE_BIT,
                    .pImmutableSamplers = null,
                },
            };
            
            // Create the compute pipeline
            const pipeline = try Pipeline.init(
                allocator,
                context,
                shader_code,
                &bindings,
                null, // No push constants for now
            );
            
            return Self{
                .pipeline = pipeline,
                .context = context,
            };
        }
        
        pub fn deinit(self: *Self) void {
            self.pipeline.deinit();
        }
        
        pub fn execute(
            self: *Self,
            command_buffer: vk.VkCommandBuffer,
            input_a: *const Tensor4D(T),
            input_b: *const Tensor4D(T),
            output: *Tensor4D(T),
            params: TensorOperationParams(T),
        ) !void {
            // Validate dimensions
            if (!std.mem.eql(u32, &input_a.dims, &input_b.dims) || 
                !std.mem.eql(u32, &input_a.dims, &output.dims)) {
                return error.InvalidTensorDimensions;
            }
            
            // Update descriptor sets with buffer handles
            try self.pipeline.updateDescriptorSets(
                &input_a.buffer.handle,
                @sizeOf(vk.VkBuffer),
                &input_b.buffer.handle,
                @sizeOf(vk.VkBuffer),
                &output.buffer.handle,
                @sizeOf(vk.VkBuffer),
                ¶ms,
                @sizeOf(@TypeOf(params))
            );
            
            // Dispatch the compute shader
            const group_counts = [4]u32{
                (input_a.dims[0] + 3) / 4,  // x
                (input_a.dims[1] + 3) / 4,  // y
                (input_a.dims[2] + 3) / 4,  // z
                input_a.dims[3],            // w (handled in shader)
            };
            
            self.pipeline.dispatch(
                command_buffer,
                group_counts[0],
                group_counts[1],
                group_counts[2]
            );
        }
    };
}

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
