const std = @import("std");

// Build configuration options
const Options = struct {
    enable_gpu: bool = true,
    rocm_path: ?[]const u8 = "/opt/rocm",
};

// Parse command line options
fn parseOptions(b: *std.Build) Options {
    const options = b.option(bool, "enable-gpu", "Enable GPU acceleration (default: true)") orelse true;
    const rocm_path = b.option([]const u8, "rocm-path", "Path to ROCm installation (default: /opt/rocm");
    
    return .{
        .enable_gpu = options,
        .rocm_path = rocm_path,
    };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = parseOptions(b);

    // Create neural module
    const neural_mod = b.addModule("neural", .{
        .root_source_file = .{ .cwd_relative = "src/neural/mod.zig" },
    });

    // GPU module (disabled for now to fix build issues)
    // if (options.enable_gpu) {
    //     // Create a module for the GPU code
    //     const gpu_mod = b.addModule("gpu", .{
    //         .root_source_file = .{ .cwd_relative = "src/gpu/gpu.zig" },
    //     });
        
    //     // Make GPU module available to neural module
    //     neural_mod.addImport("gpu", gpu_mod);
        
    //     // Create an executable that will use the GPU code
    //     const gpu_exe = b.addExecutable(.{
    //         .name = "gpu_runner",
    //         .root_source_file = .{ .cwd_relative = "src/gpu/runner.zig" },
    //         .target = target,
    //         .optimize = optimize,
    //     });
        
    //     // Add module to the executable
    //     gpu_exe.root_module.addImport("gpu", gpu_mod);
        
    //     // Set ROCm paths
    //     const rocm_path = options.rocm_path orelse "/opt/rocm";
        
    //     // Add ROCm include path
    //     const include_path = std.fs.path.join(b.allocator, &[_][]const u8{rocm_path, "include"}) catch @panic("OOM");
    //     gpu_exe.addSystemIncludePath(.{ .cwd_relative = include_path });
        
    //     // Add ROCm library path
    //     const lib_path = std.fs.path.join(b.allocator, &[_][]const u8{rocm_path, "lib"}) catch @panic("OOM");
    //     gpu_exe.addLibraryPath(.{ .cwd_relative = lib_path });
        
    //     // Link system libraries
    //     const libs_to_link = [_][]const u8{
    //         "hsa-runtime64",
    //         "amdhip64",
    //         "rocblas",
    //         "hipblas",
    //         "MIOpen",
    //         "stdc++",  // C++ standard library
    //     };
        
    //     for (libs_to_link) |lib| {
    //         gpu_exe.linkSystemLibrary(lib);
    //     }
        
    //     // Add rpath for ROCm libraries
    //     gpu_exe.addRPath(.{ .cwd_relative = lib_path });
        
    //     // Add include paths
    //     gpu_exe.addSystemIncludePath(.{ .cwd_relative = "src" });
    //     gpu_exe.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });
        
    //     // Install the executable
    //     b.installArtifact(gpu_exe);
        
    //     // Add a run step for the GPU executable
    //     const run_gpu = b.addRunArtifact(gpu_exe);
    //     const run_gpu_step = b.step("run-gpu", "Run the GPU example");
    //     run_gpu_step.dependOn(&run_gpu.step);
    // }

    // Test patterns executable
    const test_patterns = b.addExecutable(.{
        .name = "test-patterns",
        .root_source_file = .{ .cwd_relative = "src/quantum_cache/test_patterns.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add module dependencies
    test_patterns.root_module.addImport("neural", neural_mod);
    
    // Install the executable
    b.installArtifact(test_patterns);
    
    // Create run step for test patterns
    const run_test_patterns = b.addRunArtifact(test_patterns);
    const run_test_patterns_step = b.step("test-patterns", "Run test patterns for QuantumCache");
    run_test_patterns_step.dependOn(&run_test_patterns.step);
    
    // Add command line arguments if provided
    if (b.args) |args| {
        run_test_patterns.addArgs(args);
    }
}
