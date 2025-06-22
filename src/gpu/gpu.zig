//! 🚀 MAYA GPU Acceleration Module
//! ✨ Version: 1.0.0
//! 📅 Created: 2025-06-22
//! 👤 Author: isdood

const std = @import("std");
const builtin = @import("builtin");

// Export HIP/ROCm types and functions
extern "C" {
    // HIP runtime API
    pub const hipError_t = c_uint;
    pub const hipDeviceProp_t = extern struct {
        name: [256]u8,
        totalGlobalMem: usize,
        sharedMemPerBlock: usize,
        regsPerBlock: c_int,
        warpSize: c_int,
        maxThreadsPerBlock: c_int,
        maxThreadsDim: [3]c_int,
        maxGridSize: [3]c_int,
        clockRate: c_int,
        memoryClockRate: c_int,
        memoryBusWidth: c_int,
        totalConstMem: usize,
        major: c_int,
        minor: c_int,
        multiProcessorCount: c_int,
        l2CacheSize: c_int,
        maxThreadsPerMultiProcessor: c_int,
        computeMode: c_int,
        clockInstructionRate: c_int,
        concurrentKernels: c_int,
        pciDomainID: c_int,
        pciBusID: c_int,
        pciDeviceID: c_int,
        maxSharedMemoryPerMultiProcessor: usize,
        isMultiGpuBoard: c_int,
        canMapHostMemory: c_int,
        gcnArch: c_int,
        gcnArchName: [256]u8,
        // ... other fields as needed
    };

    pub extern fn hipInit(flags: c_uint) hipError_t;
    pub extern fn hipGetDeviceCount(count: *c_int) hipError_t;
    pub extern fn hipGetDeviceProperties(prop: *hipDeviceProp_t, device: c_int) hipError_t;
    pub extern fn hipMalloc(ptr: **anyopaque, size: usize) hipError_t;
    pub extern fn hipFree(ptr: *anyopaque) hipError_t;
    pub extern fn hipMemcpy(dst: *anyopaque, src: *const anyopaque, size: usize, kind: c_uint) hipError_t;
    pub extern fn hipGetLastError() hipError_t;
    pub extern fn hipGetErrorString(error: hipError_t) [*:0]const u8;
}

// HIP API error codes
pub const hipSuccess: c_uint = 0;
pub const hipErrorInvalidValue: c_uint = 1;
pub const hipErrorOutOfMemory: c_uint = 2;
// ... other error codes as needed

// Memory copy kinds
pub const hipMemcpyHostToHost: c_uint = 0;
pub const hipMemcpyHostToDevice: c_uint = 1;
pub const hipMemcpyDeviceToHost: c_uint = 2;
pub const hipMemcpyDeviceToDevice: c_uint = 3;

/// GPU device information
pub const DeviceInfo = struct {
    name: []const u8,
    total_memory: usize,
    compute_units: u32,
    max_workgroup_size: u32,
    max_work_item_dimensions: u32,
    max_work_item_sizes: [3]usize,
};

/// GPU context for managing device resources
pub const Context = struct {
    device_id: c_int,
    device_props: hipDeviceProp_t,
    
    /// Initialize a new GPU context
    pub fn init(device_id: c_int) !Context {
        var count: c_int = 0;
        const err = hipGetDeviceCount(&count);
        if (err != hipSuccess) {
            return error.FailedToGetDeviceCount;
        }
        
        if (device_id < 0 or device_id >= count) {
            return error.InvalidDeviceId;
        }
        
        var props: hipDeviceProp_t = undefined;
        const prop_err = hipGetDeviceProperties(&props, device_id);
        if (prop_err != hipSuccess) {
            return error.FailedToGetDeviceProperties;
        }
        
        return Context{
            .device_id = device_id,
            .device_props = props,
        };
    }
    
    /// Get device information
    pub fn getDeviceInfo(self: *const Context) DeviceInfo {
        return .{
            .name = std.mem.sliceTo(&self.device_props.name, 0),
            .total_memory = self.device_props.totalGlobalMem,
            .compute_units = @intCast(self.device_props.multiProcessorCount),
            .max_workgroup_size = @intCast(self.device_props.maxThreadsPerBlock),
            .max_work_item_dimensions = 3,
            .max_work_item_sizes = .{
                @intCast(self.device_props.maxThreadsDim[0]),
                @intCast(self.device_props.maxThreadsDim[1]),
                @intCast(self.device_props.maxThreadsDim[2]),
            },
        };
    }
};

/// GPU buffer for device memory management
pub const Buffer = struct {
    ptr: *anyopaque,
    size: usize,
    
    /// Allocate device memory
    pub fn init(size: usize) !Buffer {
        var ptr: *anyopaque = undefined;
        const err = hipMalloc(&ptr, size);
        if (err != hipSuccess) {
            return error.FailedToAllocateDeviceMemory;
        }
        return Buffer{
            .ptr = ptr,
            .size = size,
        };
    }
    
    /// Free device memory
    pub fn deinit(self: *Buffer) void {
        _ = hipFree(self.ptr);
        self.* = undefined;
    }
    
    /// Copy data from host to device
    pub fn write(self: *const Buffer, data: []const u8) !void {
        if (data.len > self.size) {
            return error.BufferTooSmall;
        }
        const err = hipMemcpy(self.ptr, data.ptr, data.len, hipMemcpyHostToDevice);
        if (err != hipSuccess) {
            return error.FailedToCopyToDevice;
        }
    }
    
    /// Copy data from device to host
    pub fn read(self: *const Buffer, data: []u8) !void {
        if (data.len < self.size) {
            return error.BufferTooSmall;
        }
        const err = hipMemcpy(data.ptr, self.ptr, self.size, hipMemcpyDeviceToHost);
        if (err != hipSuccess) {
            return error.FailedToCopyFromDevice;
        }
    }
};

/// Initialize the GPU system
pub fn init() !void {
    const err = hipInit(0);
    if (err != hipSuccess) {
        return error.FailedToInitializeHIP;
    }
}

// Test cases
const testing = std.testing;

test "GPU initialization" {
    try init();
    
    var count: c_int = 0;
    try testing.expectEqual(hipSuccess, hipGetDeviceCount(&count));
    try testing.expect(count > 0);
    
    std.debug.print("\nFound {} GPU devices:\n", .{count});
    
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        var props: hipDeviceProp_t = undefined;
        try testing.expectEqual(hipSuccess, hipGetDeviceProperties(&props, i));
        
        const name = std.mem.sliceTo(&props.name, 0);
        const memory_gb = @as(f64, @floatFromInt(props.totalGlobalMem)) / (1024 * 1024 * 1024);
        
        std.debug.print("  {d}: {s} (Compute {d}.{d}, {d:.1}GB VRAM, {d} CUs)\n", .{
            i,
            name,
            props.major,
            props.minor,
            memory_gb,
            props.multiProcessorCount,
        });
    }
}

// Compile-time check for ROCm support
comptime {
    if (!builtin.target.isLinux()) {
        @compileError("ROCm is currently only supported on Linux");
    }
    
    // Check if we have the required ROCm libraries
    const has_rocm = @hasDecl("C", "hipMalloc");
    if (!has_rocm) {
        @compileError("ROCm HIP runtime not found. Please install the ROCm platform.");
    }
}
