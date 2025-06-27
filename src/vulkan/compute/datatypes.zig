// src/vulkan/compute/datatypes.zig
const std = @import("std");
const vk = @import("vk");

/// Supported data types for tensor operations
pub const DataType = enum(u32) {
    F32,
    F16,
    I32,
    I16,
    U32,
    U16,
    
    /// Returns the size in bytes of the data type
    pub fn size(self: DataType) u32 {
        return switch (self) {
            .F32, .I32, .U32 => 4,
            .F16, .I16, .U16 => 2,
        };
    }
    
    /// Returns the Vulkan format for the data type
    pub fn vkFormat(self: DataType) vk.VkFormat {
        return switch (self) {
            .F32 => vk.VK_FORMAT_R32_SFLOAT,
            .F16 => vk.VK_FORMAT_R16_SFLOAT,
            .I32 => vk.VK_FORMAT_R32_SINT,
            .I16 => vk.VK_FORMAT_R16_SINT,
            .U32 => vk.VK_FORMAT_R32_UINT,
            .U16 => vk.VK_FORMAT_R16_UINT,
        };
    }
    
    /// Returns the GLSL type name as a string
    pub fn glslTypeName(self: DataType) []const u8 {
        return switch (self) {
            .F32 => "float",
            .F16 => "float16_t",
            .I32 => "int",
            .I16 => "int16_t",
            .U32 => "uint",
            .U16 => "uint16_t",
        };
    }
    
    /// Returns the GLSL type suffix for built-in functions
    pub fn glslSuffix(self: DataType) []const u8 {
        return switch (self) {
            .F32, .F16 => "f",
            .I32, .I16 => "i",
            .U32, .U16 => "u",
        };
    }
};

/// Converts a Zig type to a DataType
pub fn typeToDataType(comptime T: type) DataType {
    return switch (@typeInfo(T)) {
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
        else => @compileError("Unsupported type"),
    };
}

/// Returns the default value for a data type
pub fn defaultValue(comptime T: type) T {
    return switch (@typeInfo(T)) {
        .Float => 0.0,
        .Int => |i| if (i.signedness == .signed) @as(T, 0) else @as(T, 0),
        else => @compileError("Unsupported type"),
    };
}

/// Converts a value to a byte array based on its type
pub fn toBytes(comptime T: type, value: T) [@sizeOf(T)]u8 {
    var bytes: [@sizeOf(T)]u8 = undefined;
    @memcpy(&bytes, std.mem.asBytes(&value));
    return bytes;
}

/// Converts a byte array back to a value
pub fn fromBytes(comptime T: type, bytes: []const u8) T {
    var value: T = undefined;
    @memcpy(std.mem.asBytes(&value), bytes);
    return value;
}
