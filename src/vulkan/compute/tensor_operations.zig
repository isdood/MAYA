// src/vulkan/compute/tensor_operations.zig
const std = @import("std");

// Import from the vk module that was provided by the build system
const vk = @import("vk");
const Context = @import("vulkan/context").VulkanContext;
const Pipeline = @import("pipeline.zig").VulkanComputePipeline;
const SpiralConvolutionParams = @import("pipeline.zig").SpiralConvolutionParams;
// Import the Buffer type from the vulkan/memory/buffer module
const Buffer = @import("vulkan/memory/buffer").Buffer;
const DataType = @import("./datatypes.zig").DataType;

// Import the embedded shaders
const shaders = @import("shaders.zig");

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
        
        pub fn readData(self: *Self, allocator: std.mem.Allocator) ![]T {
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
            if (Type == f16) return .F16;
            if (Type == f32) return .F32;
            if (Type == i16) return .I16;
            if (Type == u16) return .U16;
            if (Type == i32) return .I32;
            if (Type == u32) return .U32;
            @compileError("Unsupported tensor element type");
        }
    };
}

/// Supported tensor operations
pub const TensorOperation = enum(u32) {
    add = 0,      // Element-wise addition
    sub = 1,      // Element-wise subtraction
    mul = 2,      // Element-wise multiplication
    div = 3,      // Element-wise division
    max = 4,      // Element-wise maximum
    min = 5,      // Element-wise minimum
    pow = 6,      // Element-wise power (a^b)
    relu = 7,    // Rectified Linear Unit (max(0, x))
    sigmoid = 8, // Sigmoid activation function (1 / (1 + e^-x))
    tanh = 9,    // Hyperbolic tangent activation function
    linear_combination = 10, // Linear combination of two tensors: alpha * A + beta * B
    
    /// Convert to string for debugging
    pub fn toString(self: @This()) []const u8 {
        return switch (self) {
            .add => "add",
            .sub => "sub",
            .mul => "mul",
            .div => "div",
            .max => "max",
            .min => "min",
            .pow => "pow",
            .relu => "relu",
            .sigmoid => "sigmoid",
            .tanh => "tanh",
            .linear_combination => "linear_combination",
        };
    }
};

/// Parameters for tensor operations
pub fn TensorOperationParams(comptime T: type) type {
    return struct {
        alpha: T = 1,
        beta: T = 1,
        operation: TensorOperation = .add,
    };
}

/// A pipeline for performing tensor operations on a specific data type
pub fn TensorPipeline(comptime T: type) type {
    return struct {
        pipeline: Pipeline,
        context: *Context,
        
        const Self = @This();
        
        pub fn init(allocator: std.mem.Allocator, context: *Context) !Self {
            // Use the appropriate embedded shader based on data type
            const shader_bytes = switch (T) {
                f32, f64 => &shaders.float,
                i32, i64, i16 => &shaders.int,
                u32, u64, u16 => &shaders.uint,
                else => return error.UnsupportedDataType,
            };
            // Convert shader bytes to u32 words for Vulkan with proper alignment
            const shader_words = @as([]align(4) const u32, @alignCast(std.mem.bytesAsSlice(u32, std.mem.sliceAsBytes(shader_bytes))));
            
            // Note: Descriptor set bindings are now handled in the pipeline initialization
            
            // Create the compute pipeline with the loaded shader
            const pipeline = try Pipeline.init(
                context,
                allocator,
                shader_words,
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
            // Validate dimensions by comparing each element
            for (input_a.dims, 0..) |dim, i| {
                if ((dim != input_b.dims[i]) or (dim != output.dims[i])) {
                    return error.InvalidTensorDimensions;
                }
            }
            
            // Calculate work group sizes based on tensor dimensions
            // Using a work group size of 8x8x1 as a reasonable default
            const work_group_size = [3]u32{
                @max(@as(u32, 1), input_a.dims[0]),  // x
                @max(@as(u32, 1), input_a.dims[1]),  // y
                @max(@as(u32, 1), input_a.dims[2]),  // z
            };
            
            // Create SpiralConvolutionParams with proper type conversion
            // This will be passed to the shader but marked as unused in the function signature
            const spiral_params = SpiralConvolutionParams{
                .input_dims = [4]i32{
                    @intCast(input_a.dims[0]),
                    @intCast(input_a.dims[1]),
                    @intCast(input_a.dims[2]),
                    @intCast(input_a.dims[3]),
                },
                .output_dims = [4]i32{
                    @intCast(output.dims[0]),
                    @intCast(output.dims[1]),
                    @intCast(output.dims[2]),
                    @intCast(output.dims[3]),
                },
                .kernel_size = 1,    // Not used in this operation
                .golden_ratio = 1.0, // Not used in this operation
                .time_scale = 1.0,   // Not used in this operation
            };
            
            // Use the operation type from params
            _ = params.operation;  // This would be used to select the operation in the shader
            
            // Dispatch the compute shader with input and output buffers
            self.pipeline.dispatch(
                command_buffer,           // Command buffer
                input_a.buffer.handle,   // Input buffer A
                output.buffer.handle,    // Output buffer
                spiral_params,           // SpiralConvolutionParams (unused in the function)
                work_group_size          // Work group size
            );
            
            // If needed, we can add a second dispatch for input_b here
            // with appropriate synchronization if the operation requires it
            
            // Original group counts calculation preserved for reference
            const group_counts = [4]u32{
                (input_a.dims[0] + 3) / 4,  // x
                (input_a.dims[1] + 3) / 4,  // y
                (input_a.dims[2] + 3) / 4,  // z
                input_a.dims[3],            // w (handled in shader)
            };
            
            // Second dispatch with group counts
            self.pipeline.dispatch(
                command_buffer,           // Command buffer
                input_a.buffer.handle,   // Input buffer A
                output.buffer.handle,    // Output buffer
                spiral_params,           // SpiralConvolutionParams (unused in the function)
                [3]u32{                  // Work group size from group counts
                    group_counts[0],
                    group_counts[1],
                    group_counts[2]
                }
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
