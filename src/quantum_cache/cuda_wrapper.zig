const std = @import("std");
const c = @cImport({
    @cInclude("cuda_runtime.h");
    @cInclude("cuda.h");
});

// 4D vector structure matching our CUDA code
pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

// CUDA error handling
pub const CudaError = error{
    CudaError,
    OutOfMemory,
    InvalidValue,
    Unknown,
};

fn checkCudaError(err: c.cudaError_t) CudaError!void {
    return switch (err) {
        c.cudaSuccess => {},
        c.cudaErrorMemoryAllocation => error.OutOfMemory,
        c.cudaErrorInvalidValue => error.InvalidValue,
        else => {
            std.log.err("CUDA error: {s}", .{c.cudaGetErrorString(err)});
            return error.CudaError;
        },
    };
}

// Wrapper for the CUDA spiral convolution function
extern fn launch_spiral_convolution_4d(
    input: [*]const f32,
    output: [*]f32,
    width: c_int,
    height: c_int,
    depth: c_int,
    time_steps: c_int,
    channels: c_int,
    scale: Vec4,
    rotation: Vec4,
    translation: Vec4,
    use_gravity_well: bool,
    well_center: Vec4,
    well_mass: f32,
    well_radius: f32,
    use_spiral: bool,
    spiral_turns: c_int,
    spiral_phase: f32,
) callconv(.C) void;

/// Wrapper for the CUDA spiral convolution function
pub fn spiralConvolution4D(
    input: []const f32,
    output: []f32,
    width: u32,
    height: u32,
    depth: u32,
    time_steps: u32,
    channels: u32,
    scale: Vec4,
    rotation: Vec4,
    translation: Vec4,
    use_gravity_well: bool,
    well_center: Vec4,
    well_mass: f32,
    well_radius: f32,
    use_spiral: bool,
    spiral_turns: u32,
    spiral_phase: f32,
) CudaError!void {
    // Verify input/output sizes
    const total_elements = width * height * depth * time_steps * channels;
    if (input.len < total_elements or output.len < total_elements) {
        return error.InvalidValue;
    }
    
    // Allocate device memory
    var d_input: ?*f32 = null;
    var d_output: ?*f32 = null;
    
    try checkCudaError(c.cudaMalloc(
        @as(*?*anyopaque, @ptrCast(&d_input)),
        total_elements * @sizeOf(f32)
    ));
    
    try checkCudaError(c.cudaMalloc(
        @as(*?*anyopaque, @ptrCast(&d_output)),
        total_elements * @sizeOf(f32)
    ));
    
    defer {
        if (d_input) |ptr| _ = c.cudaFree(ptr);
        if (d_output) |ptr| _ = c.cudaFree(ptr);
    }
    
    // Copy input data to device
    try checkCudaError(c.cudaMemcpy(
        d_input,
        input.ptr,
        total_elements * @sizeOf(f32),
        c.cudaMemcpyHostToDevice
    ));
    
    // Launch kernel
    launch_spiral_convolution_4d(
        d_input.?, d_output.?, 
        @as(c_int, @intCast(width)),
        @as(c_int, @intCast(height)),
        @as(c_int, @intCast(depth)),
        @as(c_int, @intCast(time_steps)),
        @as(c_int, @intCast(channels)),
        scale, rotation, translation,
        use_gravity_well,
        well_center, well_mass, well_radius,
        use_spiral,
        @as(c_int, @intCast(spiral_turns)),
        spiral_phase
    );
    
    // Check for kernel launch errors
    try checkCudaError(c.cudaGetLastError());
    
    // Copy result back to host
    try checkCudaError(c.cudaMemcpy(
        output.ptr,
        d_output,
        total_elements * @sizeOf(f32),
        c.cudaMemcpyDeviceToHost
    ));
    
    // Synchronize to check for any kernel errors
    try checkCudaError(c.cudaDeviceSynchronize());
}

/// Initialize CUDA
pub fn initCuda() CudaError!void {
    try checkCudaError(c.cudaSetDevice(0));
    
    // Print device info
    var device: c_int = 0;
    var device_prop: c.cudaDeviceProp = undefined;
    _ = c.cudaGetDeviceProperties(&device_prop, device);
    
    std.log.info("Using CUDA device: {s}", .{device_prop.name});
    std.log.info("  Compute capability: {d}.{d}", .{
        device_prop.major,
        device_prop.minor,
    });
    std.log.info("  Total global memory: {d} MB", .{
        device_prop.totalGlobalMem / (1024 * 1024),
    });
    std.log.info("  Shared memory per block: {d} KB", .{
        device_prop.sharedMemPerBlock / 1024,
    });
}

/// Clean up CUDA resources
pub fn cleanupCuda() void {
    _ = c.cudaDeviceReset();
}
