const std = @import("std");
const c = @cImport({
    @cInclude("cuda_runtime.h");
});

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.print("Testing CUDA integration...\n", .{});
    
    // Get number of CUDA devices
    var device_count: c_int = 0;
    const cuda_result = c.cudaGetDeviceCount(&device_count);
    
    if (cuda_result != c.cudaSuccess) {
        const error_name = c.cudaGetErrorName(cuda_result);
        const error_string = c.cudaGetErrorString(cuda_result);
        
        try stdout.print("❌ CUDA error: {s} - {s}\n", .{
            std.mem.span(error_name),
            std.mem.span(error_string),
        });
        
        if (cuda_result == c.cudaErrorNoDevice) {
            try stdout.print("No CUDA-capable devices found.\n", .{});
        } else if (cuda_result == c.cudaErrorInsufficientDriver) {
            try stdout.print("Insufficient CUDA driver. Please update your NVIDIA driver.\n", .{});
        } else if (cuda_result == c.cudaErrorInitializationError) {
            try stdout.print("CUDA driver initialization failed.\n", .{});
        }
        
        return error.CudaError;
    }
    
    try stdout.print("✅ Found {} CUDA-capable device(s)\n", .{device_count});
    
    // Print device information
    for (0..@intCast(device_count)) |i| {
        var prop: c.cudaDeviceProp = undefined;
        _ = c.cudaGetDeviceProperties(&prop, @intCast(i));
        
        try stdout.print("\nDevice {}: {s}\n", .{i, std.mem.span(&prop.name)});
        try stdout.print("  Compute Capability: {}.{}\n", .{prop.major, prop.minor});
        try stdout.print("  Total Global Memory: {d:.2} GB\n", .{
            @as(f64, @floatFromInt(prop.totalGlobalMem)) / (1024 * 1024 * 1024),
        });
        try stdout.print("  Shared Memory per Block: {d} KB\n", .{
            prop.sharedMemPerBlock / 1024,
        });
        try stdout.print("  Max Threads per Block: {}\n", .{prop.maxThreadsPerBlock});
        try stdout.print("  Max Threads Dim: {} x {} x {}\n", .{
            prop.maxThreadsDim[0],
            prop.maxThreadsDim[1],
            prop.maxThreadsDim[2],
        });
        try stdout.print("  Max Grid Size: {} x {} x {}\n", .{
            prop.maxGridSize[0],
            prop.maxGridSize[1],
            prop.maxGridSize[2],
        });
    }
    
    // Test memory allocation
    try stdout.print("\nTesting CUDA memory allocation...\n", .{});
    
    var d_data: ?*f32 = null;
    const size = 1024 * @sizeOf(f32);
    
    const alloc_result = c.cudaMalloc(
        @as(*?*anyopaque, @ptrCast(&d_data)),
        size
    );
    
    if (alloc_result != c.cudaSuccess) {
        try stdout.print("❌ Failed to allocate device memory: {s}\n", .{
            std.mem.span(c.cudaGetErrorString(alloc_result)),
        });
        return error.CudaError;
    }
    
    try stdout.print("✅ Successfully allocated {} bytes of device memory\n", .{size});
    
    // Free memory
    if (d_data) |ptr| {
        _ = c.cudaFree(ptr);
    }
    
    try stdout.print("✅ CUDA integration test completed successfully!\n", .{});
}
