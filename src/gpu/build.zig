const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gpu_module = b.addModule("gpu", .{
        .source_file = .{ .path = "gpu.zig" },
    });

    // Add ROCm include paths
    gpu_module.addIncludePath("/opt/rocm/include");
    
    // Link against ROCm libraries
    gpu_module.linkSystemLibrary("hsa-runtime64");
    gpu_module.linkSystemLibrary("amdhip64");
    
    // Add compile flags for ROCm
    gpu_module.addCSourceFlags(&.{
        "-D__HIP_PLATFORM_AMD__",
        "-D__HIP_ROCclr__",
        "-fPIC",
    });
    
    // Add test step
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "gpu.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    const test_step = b.step("test", "Run GPU tests");
    test_step.dependOn(&tests.step);
}
