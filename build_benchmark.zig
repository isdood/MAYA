const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create benchmark executable
    const benchmark_exe = b.addExecutable(.{
        .name = "pattern_transform_benchmark",
        .root_source_file = .{ .path = "src/quantum_cache/pattern_transform_benchmark.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Link with required libraries
    benchmark_exe.addIncludePath(.{ .path = "/usr/local/cuda/include" });
    benchmark_exe.linkSystemLibrary("cuda");
    benchmark_exe.linkSystemLibrary("cudart");
    
    // Add build step
    const benchmark_step = b.step("benchmark", "Run pattern transform benchmarks");
    const run_benchmark = b.addRunArtifact(benchmark_exe);
    benchmark_step.dependOn(&run_benchmark.step);
    
    // Add release build option
    const release_build = b.option(bool, "release", "Build in release mode") orelse false;
    if (release_build) {
        benchmark_exe.setBuildMode(.ReleaseFast);
    }
    
    // Install the benchmark executable
    b.installArtifact(benchmark_exe);
    
    // Add CUDA kernel compilation if needed
    const cuda_kernel = b.addObject("spiral_convolution_kernel", "src/quantum_cache/cuda/spiral_convolution.cu");
    cuda_kernel.setTarget(target, .{});
    cuda_kernel.addIncludePath(.{ .path = "/usr/local/cuda/include" });
    cuda_kernel.addLibraryPath(.{ .path = "/usr/local/cuda/lib64" });
    cuda_kernel.linkLibC();
    cuda_kernel.linkSystemLibrary("cuda");
    cuda_kernel.linkSystemLibrary("cudart");
    
    // Add CUDA kernel to the benchmark executable
    benchmark_exe.addObject(cuda_kernel);
}
