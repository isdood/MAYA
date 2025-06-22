//! ⚡ GPU-Accelerated Quantum Computing
//! ✨ Version: 1.0.0
//! 📅 Created: 2025-06-22
//! 👤 Author: isdood

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

// OpenCL bindings
const cl = @import("opencl");

/// GPU-accelerated quantum processor
pub const GpuQuantumProcessor = struct {
    allocator: Allocator,
    device: cl.Device,
    context: cl.Context,
    queue: cl.CommandQueue,
    program: cl.Program,
    
    // Kernels
    quantum_gate_kernel: cl.Kernel,
    measure_qubits_kernel: cl.Kernel,
    
    // Constants
    const max_qubits = 16; // Adjust based on GPU capabilities
    const complex = struct { real: f32, imag: f32 };
    
    pub fn init(allocator: Allocator) !*@This() {
        // Initialize OpenCL
        const platform_id = try cl.getPlatformIDs(1);
        const device_id = try cl.getDeviceIDs(platform_id[0], .GPU, 1);
        
        if (device_id.len == 0) {
            return error.NoGpuDeviceFound;
        }
        
        const device = device_id[0];
        const context = try cl.createContext(null, 1, &device, null, null);
        const queue = try cl.createCommandQueue(context, device, .{});
        
        // Create and build the OpenCL program
        const source = @embedFile("kernels/quantum_kernels.cl");
        var err: cl.CL_int = undefined;
        const program = cl.clCreateProgramWithSource(context, 1, &source.ptr, &source.len, &err);
        try cl.checkError(err);
        
        // Build the program
        err = cl.clBuildProgram(program, 1, &device, "-cl-fast-relaxed-math -cl-std=CL2.0", null, null);
        
        // Get build log if there's an error
        if (err != cl.CL_SUCCESS) {
            var log_size: usize = 0;
            _ = cl.clGetProgramBuildInfo(program, device, cl.CL_PROGRAM_BUILD_LOG, 0, null, &log_size);
            var log = try allocator.alloc(u8, log_size);
            defer allocator.free(log);
            _ = cl.clGetProgramBuildInfo(program, device, cl.CL_PROGRAM_BUILD_LOG, log_size, log.ptr, null);
            std.debug.print("Build log: {s}\n", .{log});
            return error.BuildFailed;
        }
        
        // Create kernels
        const quantum_gate_kernel = try cl.createKernel(program, "apply_quantum_gate");
        const measure_qubits_kernel = try cl.createKernel(program, "measure_qubits");
        
        const self = try allocator.create(@This());
        self.* = .{
            .allocator = allocator,
            .device = device,
            .context = context,
            .queue = queue,
            .program = program,
            .quantum_gate_kernel = quantum_gate_kernel,
            .measure_qubits_kernel = measure_qubits_kernel,
        };
        
        return self;
    }
    
    pub fn deinit(self: *@This()) void {
        cl.releaseKernel(self.quantum_gate_kernel);
        cl.releaseKernel(self.measure_qubits_kernel);
        cl.releaseProgram(self.program);
        cl.releaseCommandQueue(self.queue);
        cl.releaseContext(self.context);
        self.allocator.destroy(self);
    }
    
    /// Apply a quantum gate to the quantum state
    pub fn applyGate(self: *@This(), state: []complex, gate: []const f32, qubits: []const u32) !void {
        const num_qubits = @intCast(u32, @bitSizeOf(usize) * 8 - @clz(@as(usize, state.len)));
        const num_gate_qubits = @intCast(u32, @floatToInt(u32, @log2(@intToFloat(f32, gate.len))));
        
        // Create buffers
        const state_buf = try cl.createBuffer(self.context, .{ .READ_WRITE = {} }, state, null);
        const gate_buf = try cl.createBuffer(self.context, .{ .READ_ONLY = true }, gate, null);
        
        // Set kernel arguments
        try cl.setKernelArg(self.quantum_gate_kernel, 0, state_buf);
        try cl.setKernelArg(self.quantum_gate_kernel, 1, gate_buf);
        try cl.setKernelArg(self.quantum_gate_kernel, 2, &num_qubits);
        
        // Execute the kernel
        const global_work_size = @intCast(usize, 1) << @intCast(u6, num_qubits - num_gate_qubits);
        try cl.enqueueNDRangeKernel(
            self.queue,
            self.quantum_gate_kernel,
            1,
            null,
            &[_]usize{global_work_size},
            null,
            0,
            null,
            null
        );
        
        // Read back the results
        try cl.enqueueReadBuffer(
            self.queue,
            state_buf,
            .BLOCKING,
            0,
            state,
            0,
            null,
            null
        );
        
        // Clean up
        cl.releaseMemObject(state_buf);
        cl.releaseMemObject(gate_buf);
    }
    
    /// Measure the quantum state
    pub fn measure(self: *@This(), state: []const complex, num_measurements: usize) ![]u8 {
        const num_qubits = @intCast(u32, @bitSizeOf(usize) * 8 - @clz(@as(usize, state.len)));
        var measurements = try self.allocator.alloc(u8, num_measurements);
        
        // Create buffers
        const state_buf = try cl.createBuffer(self.context, .{ .READ_ONLY = true }, state, null);
        const measurements_buf = try cl.createBuffer(self.context, .{ .WRITE_ONLY = true }, measurements, null);
        
        // Set kernel arguments
        try cl.setKernelArg(self.measure_qubits_kernel, 0, state_buf);
        try cl.setKernelArg(self.measure_qubits_kernel, 1, measurements_buf);
        try cl.setKernelArg(self.measure_qubits_kernel, 2, &num_qubits);
        
        // Execute the kernel
        try cl.enqueueNDRangeKernel(
            self.queue,
            self.measure_qubits_kernel,
            1,
            null,
            &[_]usize{num_measurements},
            null,
            0,
            null,
            null
        );
        
        // Read back the measurements
        try cl.enqueueReadBuffer(
            self.queue,
            measurements_buf,
            .BLOCKING,
            0,
            measurements,
            0,
            null,
            null
        );
        
        // Clean up
        cl.releaseMemObject(state_buf);
        cl.releaseMemObject(measurements_buf);
        
        return measurements;
    }
};

// Tests
const testing = std.testing;

test "GPU quantum gate application" {
    if (builtin.os.tag == .windows) {
        // Skip on Windows CI which might not have OpenCL
        return error.SkipZigTest;
    }
    
    const allocator = testing.allocator;
    
    // Initialize GPU quantum processor
    var gpu_processor = try GpuQuantumProcessor.init(allocator);
    defer gpu_processor.deinit();
    
    // Test with a simple Hadamard gate on 1 qubit
    const num_qubits = 1;
    const state_size = @as(usize, 1) << num_qubits;
    
    // Initialize state |0⟩
    var state = try allocator.alloc(GpuQuantumProcessor.complex, state_size);
    defer allocator.free(state);
    
    @memset(@ptrCast([*]u8, state.ptr), 0, state.len * @sizeOf(GpuQuantumProcessor.complex));
    state[0] = .{ .real = 1.0, .imag = 0.0 };
    
    // Define Hadamard gate
    const hadamard = [_]f32{
        1.0 / std.math.sqrt(2.0), 0.0,  1.0 / std.math.sqrt(2.0), 0.0,
        1.0 / std.math.sqrt(2.0), 0.0, -1.0 / std.math.sqrt(2.0), 0.0,
    };
    
    // Apply Hadamard gate
    try gpu_processor.applyGate(state, &hadamard, &[_]u32{0});
    
    // Verify the result (should be (|0⟩ + |1⟩)/√2)
    const expected = 1.0 / std.math.sqrt(2.0);
    try testing.expectApproxEqAbs(state[0].real, expected, 1e-6);
    try testing.expectApproxEqAbs(state[0].imag, 0.0, 1e-6);
    try testing.expectApproxEqAbs(state[1].real, expected, 1e-6);
    try testing.expectApproxEqAbs(state[1].imag, 0.0, 1e-6);
}

// OpenCL kernel source code
pub const quantum_kernels_source = 
    \#define M_SQRT1_2 0.70710678118654752440f
    \
    \typedef struct {
    \    float real;
    \    float imag;
    \} complex_t;
    \
    \// Apply a quantum gate to the state
    \__kernel void apply_quantum_gate(
    \    __global complex_t* state,
    \    __global const float* gate,
    \    uint num_qubits
    \) {
    \    const size_t global_id = get_global_id(0);
    \    
    \    // Calculate the indices of the basis states affected by this thread
    \    const uint num_gate_qubits = (uint)log2((float)get_global_size(0)) + 1;
    \    const uint mask = (1u << num_gate_qubits) - 1;
    \    
    \    // Apply the gate to the affected basis states
    \    complex_t new_state = (complex_t)(0.0f, 0.0f);
    \    
    \    for (uint i = 0; i < (1u << num_gate_qubits); ++i) {
    \        const uint idx = (global_id & ~mask) | ((global_id << 1) & mask) | (i & 1);
    \        const float gate_real = gate[2 * i];
    \        const float gate_imag = gate[2 * i + 1];
    \        
    \        new_state.real += state[idx].real * gate_real - state[idx].imag * gate_imag;
    \        new_state.imag += state[idx].real * gate_imag + state[idx].imag * gate_real;
    \    }
    \    
    \    // Write back the result
    \    state[global_id] = new_state;
    \}
    \
    \// Measure qubits in the computational basis
    \__kernel void measure_qubits(
    \    __global const complex_t* state,
    \    __global uchar* measurements,
    \    uint num_qubits
    \) {
    \    const size_t global_id = get_global_id(0);
    \    
    \    // Simple measurement: collapse to |0⟩ or |1⟩ based on probability
    \    const float prob = state[global_id].real * state[global_id].real + 
    \                     state[global_id].imag * state[global_id].imag;
    \    
    // Use a simple random number generator for demonstration
    // In a real implementation, you'd want a better RNG
    float rnd = (float)global_id / (float)get_global_size(0);
    measurements[global_id] = (rnd < prob) ? 1 : 0;
}
;

// Create the kernel file at build time
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const exe = b.addExecutable(.{
        .name = "gpu_quantum",
        .root_source_file = .{ .path = "src/neural/gpu_quantum.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add OpenCL library
    exe.linkSystemLibrary("OpenCL");
    
    // Create the kernels directory and write the kernel source
    const kernel_dir = b.fmt("{s}/kernels", .{b.install_prefix});
    const kernel_file = b.addWriteFile("kernels/quantum_kernels.cl", quantum_kernels_source);
    kernel_file.step.dependOn(&b.addInstallDirectory(.{
        .source_dir = .{ .path = "kernels" },
        .install_dir = .prefix,
        .install_subdir = "kernels",
    }).step);
    
    exe.step.dependOn(&kernel_file.step);
    
    b.installArtifact(exe);
}
